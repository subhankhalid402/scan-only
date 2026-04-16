import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_lib;
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../models/document_model.dart';
import 'database_service.dart';

class PdfService {
  static final PdfService instance = PdfService._init();
  PdfService._init();

  /// Create PDF from list of image paths
  Future<String> createPdfFromImages(
    List<String> imagePaths,
    String documentName,
  ) async {
    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) continue;

      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${outputDir.path}/ScanOnly/PDFs');
    await pdfDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${documentName}_$timestamp.pdf';
    final filePath = '${pdfDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  /// ID card export: front and back side on one A4 page.
  Future<String> createIdCardTwoSidePdf({
    required String frontPath,
    String? backPath,
    required String documentName,
  }) async {
    final pdf = pw.Document();
    final frontFile = File(frontPath);
    if (!await frontFile.exists()) {
      throw StateError('Front side image not found');
    }

    final frontBytes = await frontFile.readAsBytes();
    final frontImage = pw.MemoryImage(frontBytes);
    pw.MemoryImage? backImage;
    if (backPath != null) {
      final b = File(backPath);
      if (await b.exists()) {
        backImage = pw.MemoryImage(await b.readAsBytes());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          final cardAspect = 85.6 / 54.0;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                documentName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'ID Card (Front/Back)',
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.AspectRatio(
                      aspectRatio: cardAspect,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey500),
                        ),
                        child: pw.Image(frontImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.AspectRatio(
                      aspectRatio: cardAspect,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey500),
                        ),
                        child: backImage != null
                            ? pw.Image(backImage, fit: pw.BoxFit.cover)
                            : pw.Center(
                                child: pw.Text(
                                  'Back side not provided',
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${outputDir.path}/ScanOnly/PDFs');
    await pdfDir.create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${pdfDir.path}/${documentName}_id_card_$timestamp.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  static String _pdfNameStem(String displayName) {
    var stem = path_lib.basenameWithoutExtension(displayName);
    stem = stem.replaceAll(RegExp(r'[^\w\-\s\(\)]'), '_').trim();
    if (stem.isEmpty) stem = 'Scan';
    return stem;
  }

  /// Creates a PDF from image paths, registers it in the local library.
  Future<DocumentModel?> createLibraryPdfFromImages(
    List<String> imagePaths,
    String sourceDisplayName, {
    String scanType = 'document',
  }) async {
    final existing = <String>[];
    for (final p in imagePaths) {
      if (await File(p).exists()) existing.add(p);
    }
    if (existing.isEmpty) return null;

    final stem = _pdfNameStem(sourceDisplayName);
    final pdfPath = await createPdfFromImages(existing, stem);
    final thumbPath = await generateThumbnail(existing.first);
    final fileSizeMB = await getFileSizeMB(pdfPath);

    final doc = DocumentModel(
      name: '$stem.pdf',
      filePath: pdfPath,
      fileType: 'pdf',
      scanType: scanType,
      pageCount: existing.length,
      fileSizeMB: fileSizeMB,
      createdAt: DateTime.now(),
      thumbnailPath: thumbPath,
    );
    final id = await DatabaseService.instance.insertDocument(doc);
    return doc.copyWith(id: id);
  }

  /// Create PDF with embedded OCR text layer (searchable PDF)
  Future<String> createSearchablePdf(
    List<String> imagePaths,
    List<String> ocrTexts,
    String documentName,
  ) async {
    final pdf = pw.Document();

    for (int i = 0; i < imagePaths.length; i++) {
      final imageFile = File(imagePaths[i]);
      if (!await imageFile.exists()) continue;

      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);
      final ocrText = i < ocrTexts.length ? ocrTexts[i] : '';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                ),
                if (ocrText.isNotEmpty)
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Opacity(
                      opacity: 0.0, // invisible but searchable
                      child: pw.Text(
                        ocrText,
                        style: const pw.TextStyle(fontSize: 1),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${outputDir.path}/ScanOnly/PDFs');
    await pdfDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${pdfDir.path}/${documentName}_$timestamp.pdf';

    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  /// Generate thumbnail from first image
  Future<String?> generateThumbnail(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;

      final bytes = await imageFile.readAsBytes();
      final thumbBytes = await compute(_buildThumbnailBytes, bytes);
      if (thumbBytes == null) return null;

      final outputDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${outputDir.path}/ScanOnly/Thumbnails');
      await thumbDir.create(recursive: true);

      final fileName = path_lib.basenameWithoutExtension(imagePath);
      final thumbPath = '${thumbDir.path}/${fileName}_thumb.jpg';

      await File(thumbPath).writeAsBytes(thumbBytes);
      return thumbPath;
    } catch (e) {
      debugPrint('Thumbnail error: $e');
      return null;
    }
  }

  /// Apply filter to image and return new path
  Future<String> applyFilter(String imagePath, String filterType) async {
    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    final filteredBytes = await compute(
      _applyFilterIsolate,
      <String, dynamic>{'bytes': bytes, 'filterType': filterType},
    );
    if (filteredBytes == null) return imagePath;

    final outputDir = await getApplicationDocumentsDirectory();
    final editedDir = Directory('${outputDir.path}/ScanOnly/Edited');
    await editedDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final outputPath = '${editedDir.path}/edited_$timestamp.jpg';

    await File(outputPath).writeAsBytes(filteredBytes);
    return outputPath;
  }

  /// Save scanned image bytes to disk
  Future<String> saveScannedImage(Uint8List imageBytes, String name) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${outputDir.path}/ScanOnly/Scans');
    await scansDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${scansDir.path}/${name}_$timestamp.jpg';

    await File(filePath).writeAsBytes(imageBytes);
    return filePath;
  }

  /// Get file size in MB
  Future<double> getFileSizeMB(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.lengthSync() / (1024 * 1024);
  }

  /// Delete file
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Get all saved PDFs
  Future<List<FileSystemEntity>> getAllPdfs() async {
    final outputDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${outputDir.path}/ScanOnly/PDFs');
    if (!await pdfDir.exists()) return [];
    return pdfDir.listSync();
  }

  /// Smaller PDF by re-encoding images (JPEG quality + max width).
  Future<String> createCompressedPdfFromImages(
    List<String> imagePaths,
    String documentName, {
    int jpegQuality = 58,
    int maxWidth = 1400,
  }) async {
    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) continue;

      final raw = await imageFile.readAsBytes();
      final jpg = await compute(
        _prepareCompressedJpgIsolate,
        <String, dynamic>{
          'bytes': raw,
          'maxWidth': maxWidth,
          'jpegQuality': jpegQuality,
        },
      );
      if (jpg == null) continue;
      final pdfImage = pw.MemoryImage(jpg);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${outputDir.path}/ScanOnly/PDFs');
    await pdfDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${pdfDir.path}/${documentName}_compressed_$timestamp.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  /// Merge multiple PDFs into one (rasterize pages via pdfx, then build a new PDF).
  Future<String> mergePdfFiles(
      List<String> pdfPaths, String documentName) async {
    if (pdfPaths.isEmpty) {
      throw ArgumentError('No PDF files to merge');
    }

    final tempDir = await getTemporaryDirectory();
    final imagePaths = <String>[];
    var seq = 0;

    for (final pdfPath in pdfPaths) {
      final file = File(pdfPath);
      if (!await file.exists()) continue;

      final doc = await pdfx.PdfDocument.openFile(pdfPath);
      try {
        for (var p = 1; p <= doc.pagesCount; p++) {
          final page = await doc.getPage(p);
          try {
            final rw = (page.width * 2).clamp(480.0, 2200.0);
            final rh = (page.height * (rw / page.width)).clamp(400.0, 3200.0);
            final rendered = await page.render(
              width: rw,
              height: rh,
              format: pdfx.PdfPageImageFormat.jpeg,
              quality: 85,
            );
            if (rendered != null && rendered.bytes.isNotEmpty) {
              final out = File(
                '${tempDir.path}/merge_${DateTime.now().microsecondsSinceEpoch}_${seq++}.jpg',
              );
              await out.writeAsBytes(rendered.bytes);
              imagePaths.add(out.path);
            }
          } finally {
            await page.close();
          }
        }
      } finally {
        await doc.close();
      }
    }

    if (imagePaths.isEmpty) {
      throw StateError('Could not read any pages from the selected PDFs');
    }

    return createPdfFromImages(imagePaths, '${documentName}_merged');
  }
}

Uint8List? _buildThumbnailBytes(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  final thumb = img.copyResize(image, width: 300);
  return Uint8List.fromList(img.encodeJpg(thumb, quality: 70));
}

Uint8List? _applyFilterIsolate(Map<String, dynamic> payload) {
  final bytes = payload['bytes'] as Uint8List;
  final filterType = payload['filterType'] as String;
  img.Image? image = img.decodeImage(bytes);
  if (image == null) return null;
  switch (filterType) {
    case 'grayscale':
      image = img.grayscale(image);
      break;
    case 'blackwhite':
      image = img.grayscale(image);
      image = img.contrast(image, contrast: 200);
      break;
    case 'enhance':
      image = img.adjustColor(image, brightness: 1.1, contrast: 1.2);
      break;
    case 'original':
    default:
      break;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

Uint8List? _prepareCompressedJpgIsolate(Map<String, dynamic> payload) {
  final bytes = payload['bytes'] as Uint8List;
  final maxWidth = payload['maxWidth'] as int;
  final jpegQuality = payload['jpegQuality'] as int;
  var decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  if (decoded.width > maxWidth) {
    decoded = img.copyResize(decoded, width: maxWidth);
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: jpegQuality));
}
