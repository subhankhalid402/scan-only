import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'image_enhancement_service.dart';

class BatchProcessingService {
  static final BatchProcessingService instance = BatchProcessingService._init();
  BatchProcessingService._init();

  /// Apply enhancement to multiple images
  Future<List<String>> batchEnhance(
    List<String> imagePaths, {
    double brightness = 0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) async {
    final results = <String>[];
    
    for (final path in imagePaths) {
      try {
        final enhanced = await ImageEnhancementService.instance.enhanceWithValues(
          path,
          brightness: brightness,
          contrast: contrast,
          saturation: saturation,
        );
        results.add(enhanced);
      } catch (e) {
        debugPrint('Batch enhance error for $path: $e');
        results.add(path); // Add original if enhancement fails
      }
    }
    
    return results;
  }

  /// Convert multiple images to grayscale
  Future<List<String>> batchGrayscale(List<String> imagePaths) async {
    final results = <String>[];
    
    for (final path in imagePaths) {
      try {
        final grayscale = await ImageEnhancementService.instance.toGrayscale(path);
        results.add(grayscale);
      } catch (e) {
        debugPrint('Batch grayscale error for $path: $e');
        results.add(path);
      }
    }
    
    return results;
  }

  /// Rotate multiple images
  Future<List<String>> batchRotate(List<String> imagePaths, int degrees) async {
    final results = <String>[];
    
    for (final path in imagePaths) {
      try {
        final rotated = await ImageEnhancementService.instance.rotate(path, degrees);
        results.add(rotated);
      } catch (e) {
        debugPrint('Batch rotate error for $path: $e');
        results.add(path);
      }
    }
    
    return results;
  }

  /// Resize multiple images
  Future<List<String>> batchResize(
    List<String> imagePaths, {
    required int width,
    required int height,
  }) async {
    final results = <String>[];
    
    for (final path in imagePaths) {
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        var image = img.decodeImage(bytes);
        
        if (image != null) {
          image = img.copyResize(image, width: width, height: height);
          final resizedPath = path.replaceAll('.jpg', '_resized.jpg');
          final resizedFile = File(resizedPath);
          await resizedFile.writeAsBytes(img.encodeJpg(image));
          results.add(resizedPath);
        } else {
          results.add(path);
        }
      } catch (e) {
        debugPrint('Batch resize error for $path: $e');
        results.add(path);
      }
    }
    
    return results;
  }

  /// Apply watermark to multiple images
  Future<List<String>> batchWatermark(
    List<String> imagePaths, {
    required String watermarkText,
  }) async {
    final results = <String>[];
    
    for (final path in imagePaths) {
      try {
        final watermarked = await _addWatermark(path, watermarkText);
        results.add(watermarked);
      } catch (e) {
        debugPrint('Batch watermark error for $path: $e');
        results.add(path);
      }
    }
    
    return results;
  }

  Future<String> _addWatermark(String imagePath, String text) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not decode image');

    // Draw semi-transparent diagonal watermark across the image
    final color = img.ColorRgba8(180, 180, 180, 100); // light gray, semi-transparent

    // Draw watermark text multiple times diagonally
    final stepX = (image.width / 3).round();
    final stepY = (image.height / 3).round();

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final x = col * stepX + 20;
        final y = row * stepY + 20;
        img.drawString(
          image,
          text,
          font: img.arial14,
          x: x,
          y: y,
          color: color,
        );
      }
    }

    final ext = imagePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final watermarkedPath = imagePath.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '_watermarked.$ext');
    final watermarkedFile = File(watermarkedPath);
    await watermarkedFile.writeAsBytes(
      ext == 'png' ? img.encodePng(image) : img.encodeJpg(image),
    );

    return watermarkedPath;
  }
}
