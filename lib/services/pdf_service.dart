import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pathLib;
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

  static String _pdfNameStem(String displayName) {
    var stem = pathLib.basenameWithoutExtension(displayName);
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
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to thumbnail
      image = img.copyResize(image, width: 300);

      final outputDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${outputDir.path}/ScanOnly/Thumbnails');
      await thumbDir.create(recursive: true);

      final fileName = pathLib.basenameWithoutExtension(imagePath);
      final thumbPath = '${thumbDir.path}/${fileName}_thumb.jpg';

      await File(thumbPath).writeAsBytes(img.encodeJpg(image, quality: 70));
      return thumbPath;
    } catch (e) {
      print('Thumbnail error: $e');
      return null;
    }
  }

  /// Apply filter to image and return new path
  Future<String> applyFilter(String imagePath, String filterType) async {
    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return imagePath;

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
        break;
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final editedDir = Directory('${outputDir.path}/ScanOnly/Edited');
    await editedDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final outputPath = '${editedDir.path}/edited_$timestamp.jpg';

    await File(outputPath).writeAsBytes(img.encodeJpg(image, quality: 90));
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
      var decoded = img.decodeImage(raw);
      if (decoded == null) continue;
      if (decoded.width > maxWidth) {
        decoded = img.copyResize(decoded, width: maxWidth);
      }
      final jpg = img.encodeJpg(decoded, quality: jpegQuality);
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
  Future<String> mergePdfFiles(List<String> pdfPaths, String documentName) async {
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
