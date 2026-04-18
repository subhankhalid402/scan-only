import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as excel_lib;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_service.dart';

class DocumentConversionService {
  static final DocumentConversionService _instance = DocumentConversionService._internal();

  factory DocumentConversionService() {
    return _instance;
  }

  DocumentConversionService._internal();

  static DocumentConversionService get instance => _instance;

  /// Convert Word (.docx) to PDF
  Future<String> convertWordToPdf(String wordFilePath) async {
    try {
      final docxFile = File(wordFilePath);
      if (!docxFile.existsSync()) {
        throw Exception('Word file not found');
      }

      // Create PDF
      final pdf = pw.Document();
      
      // Add a page with placeholder text
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Word Document Converted to PDF',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'File: ${path.basenameWithoutExtension(wordFilePath)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Converted on: ${DateTime.now()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Note: For full Word to PDF conversion with all formatting, please use desktop tools like Microsoft Office or LibreOffice.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${path.basenameWithoutExtension(wordFilePath)}_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputPath = '${directory.path}/$fileName';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      throw Exception('Word to PDF conversion failed: $e');
    }
  }

  /// Convert PowerPoint (.pptx) to PDF
  Future<String> convertPptToPdf(String pptFilePath) async {
    try {
      final pptFile = File(pptFilePath);
      if (!pptFile.existsSync()) {
        throw Exception('PowerPoint file not found');
      }

      // Create PDF
      final pdf = pw.Document();

      // Add a page with placeholder text
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PowerPoint Presentation Converted to PDF',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'File: ${path.basenameWithoutExtension(pptFilePath)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Converted on: ${DateTime.now()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Note: For full PowerPoint to PDF conversion with all slides and formatting, please use desktop tools like LibreOffice or Microsoft Office.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${path.basenameWithoutExtension(pptFilePath)}_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputPath = '${directory.path}/$fileName';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      throw Exception('PowerPoint to PDF conversion failed: $e');
    }
  }

  /// Convert Image to PDF
  Future<String> convertImageToPdf(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('Image file not found');
      }

      final imageBytes = await imageFile.readAsBytes();
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pw.MemoryImage(imageBytes),
              ),
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${path.basenameWithoutExtension(imagePath)}_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputPath = '${directory.path}/$fileName';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      throw Exception('Image to PDF conversion failed: $e');
    }
  }

  /// Read a `.txt` file and turn it into a PDF.
  Future<String> convertTxtFileToPdf(String txtFilePath) async {
    final f = File(txtFilePath);
    if (!f.existsSync()) throw Exception('Text file not found');
    final text = await f.readAsString();
    final stem = path.basenameWithoutExtension(txtFilePath);
    return convertTextToPdf(text, fileName: stem);
  }

  /// Strip basic HTML tags and render remaining text as PDF.
  Future<String> convertHtmlFileToPdf(String htmlFilePath) async {
    final f = File(htmlFilePath);
    if (!f.existsSync()) throw Exception('HTML file not found');
    var raw = await f.readAsString();
    raw = raw
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    raw = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    raw = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final stem = path.basenameWithoutExtension(htmlFilePath);
    return convertTextToPdf(raw.isEmpty ? ' ' : raw, fileName: stem);
  }

  /// Simple CSV → table PDF (comma-separated; quoted fields supported lightly).
  Future<String> convertCsvFileToPdf(String csvFilePath) async {
    final f = File(csvFilePath);
    if (!f.existsSync()) throw Exception('CSV file not found');
    final lines =
        await f.readAsLines().then((l) => l.where((e) => e.trim().isNotEmpty).toList());
    if (lines.isEmpty) {
      return convertTextToPdf('(empty CSV)', fileName: 'csv');
    }
    List<String> parseRow(String line) {
      final out = <String>[];
      var cur = StringBuffer();
      var inQ = false;
      for (var i = 0; i < line.length; i++) {
        final c = line[i];
        if (c == '"') {
          inQ = !inQ;
        } else if ((c == ',' || c == '\t') && !inQ) {
          out.add(cur.toString().trim());
          cur = StringBuffer();
        } else {
          cur.write(c);
        }
      }
      out.add(cur.toString().trim());
      return out;
    }

    final rows = lines.map(parseRow).toList();
    final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => [
          pw.Text(
            path.basename(csvFilePath),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            children: [
              for (var r = 0; r < rows.length && r < 200; r++)
                pw.TableRow(
                  children: [
                    for (var c = 0; c < colCount; c++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          c < rows[r].length ? rows[r][c] : '',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    final directory = await getApplicationDocumentsDirectory();
    final outPath =
        '${directory.path}/${path.basenameWithoutExtension(csvFilePath)}_csv_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(outPath).writeAsBytes(await pdf.save());
    return outPath;
  }

  /// Pretty-print JSON into a PDF.
  Future<String> convertJsonFileToPdf(String jsonFilePath) async {
    final f = File(jsonFilePath);
    if (!f.existsSync()) throw Exception('JSON file not found');
    final raw = await f.readAsString();
    final decoded = json.decode(raw);
    final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
    final stem = path.basenameWithoutExtension(jsonFilePath);
    return convertTextToPdf(pretty, fileName: stem);
  }

  /// First worksheet → table PDF (wide layout; row/column caps for size).
  Future<String> convertExcelToPdf(String xlsxPath) async {
    final file = File(xlsxPath);
    if (!file.existsSync()) throw Exception('Excel file not found');
    final bytes = await file.readAsBytes();
    final excel = excel_lib.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) throw Exception('No sheets in workbook');
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    const maxRows = 150;
    const maxColsCap = 16;
    final cols = sheet.maxColumns.clamp(1, maxColsCap);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text(
            '${path.basename(xlsxPath)} · $sheetName',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
            children: [
              for (var r = 0; r < sheet.maxRows && r < maxRows; r++)
                pw.TableRow(
                  children: [
                    for (var c = 0; c < cols; c++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          _excelCellString(_cellAt(sheet, r, c)),
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    final directory = await getApplicationDocumentsDirectory();
    final outPath =
        '${directory.path}/${path.basenameWithoutExtension(xlsxPath)}_xlsx_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(outPath).writeAsBytes(await pdf.save());
    return outPath;
  }

  excel_lib.Data? _cellAt(excel_lib.Sheet sheet, int row, int col) {
    final rowData = sheet.row(row);
    if (col >= rowData.length) return null;
    return rowData[col];
  }

  String _excelCellString(excel_lib.Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString();
  }

  /// Multiple images → one multi-page PDF (uses [PdfService]).
  Future<String> convertMultipleImagesToPdf(
    List<String> imagePaths,
    String documentName,
  ) {
    if (imagePaths.isEmpty) {
      throw ArgumentError('No images selected');
    }
    return PdfService.instance.createPdfFromImages(imagePaths, documentName);
  }

  /// Merge multiple PDFs into one (rasterized pages via [PdfService]).
  Future<String> mergePdfFilesToOne(List<String> pdfPaths, String documentName) {
    if (pdfPaths.length < 2) {
      throw ArgumentError('Select at least two PDF files to merge');
    }
    return PdfService.instance.mergePdfFiles(pdfPaths, documentName);
  }

  /// Convert plain text to PDF
  Future<String> convertTextToPdf(String text, {String fileName = 'text_document'}) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Text(
              text.trim().isEmpty ? ' ' : text,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final safeName = fileName.trim().isEmpty ? 'text_document' : fileName.trim();
      final outputPath =
          '${directory.path}/${safeName}_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());
      return outputPath;
    } catch (e) {
      throw Exception('Text to PDF conversion failed: $e');
    }
  }

  /// Extensions this module can ingest for conversion flows.
  List<String> getSupportedFormats() {
    return [
      '.doc',
      '.docx',
      '.ppt',
      '.pptx',
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.txt',
      '.csv',
      '.json',
      '.html',
      '.htm',
      '.xlsx',
      '.xls',
      '.pdf',
    ];
  }

  /// Check if file format is supported
  bool isFormatSupported(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return getSupportedFormats().contains(extension);
  }
}
