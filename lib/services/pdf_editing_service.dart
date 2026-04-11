import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfEditingService {
  static final PdfEditingService _instance = PdfEditingService._internal();

  factory PdfEditingService() {
    return _instance;
  }

  PdfEditingService._internal();

  static PdfEditingService get instance => _instance;

  Future<String> addWatermarkToPdf(String pdfPath, String watermarkText) async {
    try {
      final file = File(pdfPath);
      final bytes = await file.readAsBytes();
      
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Text(watermarkText, style: const pw.TextStyle(fontSize: 60)),
              ],
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      throw Exception('PDF watermark failed: $e');
    }
  }

  Future<String> mergePdfs(List<String> pdfPaths) async {
    try {
      final pdf = pw.Document();

      for (var pdfPath in pdfPaths) {
        final file = File(pdfPath);
        final bytes = await file.readAsBytes();
        // Add pages from each PDF
      }

      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      throw Exception('PDF merge failed: $e');
    }
  }

  Future<String> rotatePdfPages(String pdfPath, int rotationDegrees) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.pdf';
      // Rotation logic here
      return outputPath;
    } catch (e) {
      throw Exception('PDF rotation failed: $e');
    }
  }
}
