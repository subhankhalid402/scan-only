import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class WatermarkService {
  static final WatermarkService instance = WatermarkService._init();
  WatermarkService._init();

  /// Add text watermark diagonally across image
  Future<String> addTextWatermark(
    String imagePath, {
    required String text,
    int red = 180,
    int green = 180,
    int blue = 180,
    int opacity = 100,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode image');

      final color = img.ColorRgba8(
        red.clamp(0, 255),
        green.clamp(0, 255),
        blue.clamp(0, 255),
        opacity.clamp(0, 255),
      );

      // Draw watermark text multiple times diagonally
      final positions = [
        [image.width ~/ 4, image.height ~/ 4],
        [image.width ~/ 2, image.height ~/ 2],
        [image.width * 3 ~/ 4, image.height * 3 ~/ 4],
      ];

      for (final pos in positions) {
        img.drawString(
          image,
          text,
          font: img.arial24,
          x: pos[0] - 60,
          y: pos[1],
          color: color,
        );
      }

      return await _saveImage(image, imagePath, '_watermarked');
    } catch (e) {
      print('Watermark Error: $e');
      return imagePath;
    }
  }

  /// Add timestamp watermark at bottom of image
  Future<String> addTimestampWatermark(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode image');

      final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      final color = img.ColorRgba8(255, 255, 255, 200);
      final bgColor = img.ColorRgba8(0, 0, 0, 150);

      // Draw background bar at bottom
      img.fillRect(
        image,
        x1: 0,
        y1: image.height - 36,
        x2: image.width,
        y2: image.height,
        color: bgColor,
      );

      // Draw timestamp text
      img.drawString(
        image,
        timestamp,
        font: img.arial24,
        x: 10,
        y: image.height - 30,
        color: color,
      );

      return await _saveImage(image, imagePath, '_timestamped');
    } catch (e) {
      print('Timestamp Error: $e');
      return imagePath;
    }
  }

  /// Add image watermark (logo) at bottom-right
  Future<String> addImageWatermark(
    String imagePath, {
    required String watermarkImagePath,
    double opacity = 0.5,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);

      final watermarkFile = File(watermarkImagePath);
      final watermarkBytes = await watermarkFile.readAsBytes();
      var watermark = img.decodeImage(watermarkBytes);

      if (image == null || watermark == null) throw Exception('Decode failed');

      // Resize watermark to 20% of image width
      watermark = img.copyResize(
        watermark,
        width: (image.width * 0.2).toInt(),
      );

      // Place at bottom-right corner
      image = img.compositeImage(
        image,
        watermark,
        dstX: image.width - watermark.width - 10,
        dstY: image.height - watermark.height - 10,
      );

      return await _saveImage(image, imagePath, '_logo_watermarked');
    } catch (e) {
      print('Image Watermark Error: $e');
      return imagePath;
    }
  }

  /// Add copyright watermark
  Future<String> addCopyrightWatermark(
    String imagePath, {
    required String copyrightText,
  }) async {
    return addTextWatermark(
      imagePath,
      text: '© $copyrightText',
      red: 40,
      green: 48,
      blue: 88,
      opacity: 120,
    );
  }

  Future<String> _saveImage(
    img.Image image,
    String originalPath,
    String suffix,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final watermarkDir = Directory('${dir.path}/ScanOnly/Watermarked');
    await watermarkDir.create(recursive: true);

    final fileName = path.basenameWithoutExtension(originalPath);
    final outputPath = '${watermarkDir.path}/$fileName$suffix.jpg';

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(image, quality: 90));
    return outputPath;
  }
}
