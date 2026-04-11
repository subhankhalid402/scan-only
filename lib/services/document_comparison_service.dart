import 'package:image/image.dart' as img;
import 'dart:io';

class DocumentComparisonService {
  static final DocumentComparisonService _instance = DocumentComparisonService._internal();

  factory DocumentComparisonService() {
    return _instance;
  }

  DocumentComparisonService._internal();

  static DocumentComparisonService get instance => _instance;

  Future<double> compareDocuments(String path1, String path2) async {
    try {
      final image1 = img.decodeImage(File(path1).readAsBytesSync());
      final image2 = img.decodeImage(File(path2).readAsBytesSync());

      if (image1 == null || image2 == null) return 0.0;

      // Simple similarity calculation based on dimensions
      final widthSimilarity = 1 - ((image1.width - image2.width).abs() / image1.width);
      final heightSimilarity = 1 - ((image1.height - image2.height).abs() / image1.height);

      return ((widthSimilarity + heightSimilarity) / 2 * 100).clamp(0, 100);
    } catch (e) {
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> getDocumentDifferences(String path1, String path2) async {
    try {
      final file1 = File(path1);
      final file2 = File(path2);

      final size1 = await file1.length();
      final size2 = await file2.length();

      return {
        'file1_size': size1,
        'file2_size': size2,
        'size_difference': (size1 - size2).abs(),
        'similarity': await compareDocuments(path1, path2),
      };
    } catch (e) {
      return {};
    }
  }
}
