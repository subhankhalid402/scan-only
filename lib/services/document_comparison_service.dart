import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Compares two document images using pixel-level analysis.
class DocumentComparisonService {
  static final DocumentComparisonService _instance =
      DocumentComparisonService._internal();
  factory DocumentComparisonService() => _instance;
  DocumentComparisonService._internal();
  static DocumentComparisonService get instance => _instance;

  /// Returns similarity percentage (0-100) using pixel histogram comparison.
  Future<double> compareDocuments(String path1, String path2) async {
    try {
      final image1 = img.decodeImage(await File(path1).readAsBytes());
      final image2 = img.decodeImage(await File(path2).readAsBytes());
      if (image1 == null || image2 == null) return 0.0;

      // Resize both to same size for fair comparison
      const compareSize = 64;
      final r1 = img.copyResize(image1, width: compareSize, height: compareSize);
      final r2 = img.copyResize(image2, width: compareSize, height: compareSize);

      // Build grayscale histograms
      final hist1 = _buildHistogram(r1);
      final hist2 = _buildHistogram(r2);

      // Bhattacharyya coefficient for histogram similarity
      double similarity = 0;
      for (int i = 0; i < 256; i++) {
        similarity += sqrt(hist1[i] * hist2[i]);
      }

      return (similarity * 100).clamp(0.0, 100.0);
    } catch (e) {
      return 0.0;
    }
  }

  List<double> _buildHistogram(img.Image image) {
    final counts = List<double>.filled(256, 0);
    final total = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = ((pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114)).round().clamp(0, 255);
        counts[gray]++;
      }
    }

    // Normalize
    return counts.map((c) => c / total).toList();
  }

  /// Returns detailed differences between two documents.
  Future<Map<String, dynamic>> getDocumentDifferences(
      String path1, String path2) async {
    try {
      final file1 = File(path1);
      final file2 = File(path2);
      final size1 = await file1.length();
      final size2 = await file2.length();
      final similarity = await compareDocuments(path1, path2);

      final image1 = img.decodeImage(await file1.readAsBytes());
      final image2 = img.decodeImage(await file2.readAsBytes());

      return {
        'file1_size': size1,
        'file2_size': size2,
        'size_difference': (size1 - size2).abs(),
        'similarity': similarity,
        'similarity_label': _similarityLabel(similarity),
        'file1_dimensions': image1 != null ? '${image1.width}x${image1.height}' : 'N/A',
        'file2_dimensions': image2 != null ? '${image2.width}x${image2.height}' : 'N/A',
        'same_dimensions': image1 != null && image2 != null
            ? image1.width == image2.width && image1.height == image2.height
            : false,
      };
    } catch (e) {
      return {};
    }
  }

  String _similarityLabel(double similarity) {
    if (similarity >= 90) return 'Nearly identical';
    if (similarity >= 70) return 'Very similar';
    if (similarity >= 50) return 'Somewhat similar';
    if (similarity >= 30) return 'Slightly similar';
    return 'Very different';
  }
}
