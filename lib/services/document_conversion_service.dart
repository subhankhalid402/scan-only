import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

  /// Get supported formats
  List<String> getSupportedFormats() {
    return ['.docx', '.pptx', '.jpg', '.jpeg', '.png', '.pdf'];
  }

  /// Check if file format is supported
  bool isFormatSupported(String filePath) {
    final extension = File(filePath).path.split('.').last.toLowerCase();
    return getSupportedFormats().contains('.$extension');
  }
}
