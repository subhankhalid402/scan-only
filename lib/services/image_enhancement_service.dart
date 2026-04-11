import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageEnhancementService {
  static final ImageEnhancementService instance = ImageEnhancementService._init();
  ImageEnhancementService._init();

  Future<String> autoEnhance(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.contrast(image, contrast: 1.3);
      image = img.adjustColor(image, brightness: 0.1, saturation: 1.1);
      return await _save(image, imagePath, suffix: '_enhance');
    } catch (e) {
      print('autoEnhance error: $e');
      return imagePath;
    }
  }

  Future<String> enhanceWithValues(
    String imagePath, {
    double brightness = 0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      if (brightness != 0) image = img.adjustColor(image, brightness: brightness);
      if (contrast != 1.0) image = img.contrast(image, contrast: contrast);
      if (saturation != 1.0) image = img.adjustColor(image, saturation: saturation);
      return await _save(image, imagePath, suffix: '_custom');
    } catch (e) {
      print('enhanceWithValues error: $e');
      return imagePath;
    }
  }

  Future<String> toGrayscale(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.grayscale(image);
      return await _save(image, imagePath, suffix: '_grayscale');
    } catch (e) {
      print('grayscale error: $e');
      return imagePath;
    }
  }

  Future<String> rotate(String imagePath, int degrees) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.copyRotate(image, angle: degrees.toDouble());
      return await _save(image, imagePath, suffix: '_rotated');
    } catch (e) {
      print('rotate error: $e');
      return imagePath;
    }
  }

  Future<String> flip(String imagePath, {bool horizontal = true}) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = horizontal ? img.flipHorizontal(image) : img.flipVertical(image);
      return await _save(image, imagePath, suffix: '_flipped');
    } catch (e) {
      print('flip error: $e');
      return imagePath;
    }
  }

  Future<String> vivid(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.contrast(image, contrast: 1.5);
      image = img.adjustColor(image, saturation: 1.4);
      return await _save(image, imagePath, suffix: '_vivid');
    } catch (e) {
      print('vivid error: $e');
      return imagePath;
    }
  }

  Future<String> cool(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      // FIX: Pixel-level manipulation with proper int clamping
      final w = image.width;
      final h = image.height;
      final out = img.Image(width: w, height: h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = image.getPixel(x, y);
          out.setPixelRgb(
            x, y,
            (p.r * 0.85).round().clamp(0, 255),
            (p.g * 0.92).round().clamp(0, 255),
            (p.b * 1.15).round().clamp(0, 255),
          );
        }
      }
      return await _save(out, imagePath, suffix: '_cool');
    } catch (e) {
      print('cool error: $e');
      return imagePath;
    }
  }

  Future<String> warm(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      // FIX: Pixel-level manipulation with proper int clamping
      final w = image.width;
      final h = image.height;
      final out = img.Image(width: w, height: h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = image.getPixel(x, y);
          out.setPixelRgb(
            x, y,
            (p.r * 1.15).round().clamp(0, 255),
            (p.g * 1.05).round().clamp(0, 255),
            (p.b * 0.85).round().clamp(0, 255),
          );
        }
      }
      return await _save(out, imagePath, suffix: '_warm');
    } catch (e) {
      print('warm error: $e');
      return imagePath;
    }
  }

  Future<String> sepia(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.sepia(image);
      return await _save(image, imagePath, suffix: '_sepia');
    } catch (e) {
      print('sepia error: $e');
      return imagePath;
    }
  }

  Future<String> highContrast(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.contrast(image, contrast: 2.0);
      return await _save(image, imagePath, suffix: '_highcontrast');
    } catch (e) {
      print('highContrast error: $e');
      return imagePath;
    }
  }

  Future<String> soft(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.adjustColor(image, brightness: 0.15);
      image = img.contrast(image, contrast: 0.9);
      return await _save(image, imagePath, suffix: '_soft');
    } catch (e) {
      print('soft error: $e');
      return imagePath;
    }
  }

  Future<String> invert(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.invert(image);
      return await _save(image, imagePath, suffix: '_invert');
    } catch (e) {
      print('invert error: $e');
      return imagePath;
    }
  }

  Future<String> addTimestamp(
    String imagePath, {
    String format = 'dd/MM/yyyy HH:mm:ss',
    String position = 'bottom-right',
  }) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;

      final now = DateTime.now();
      final timestamp = _formatTimestamp(now, format);
      final tsH = 48;

      final newImage = img.Image(width: image.width, height: image.height + tsH);
      img.compositeImage(newImage, image, dstY: 0);

      for (int y = image.height; y < image.height + tsH; y++) {
        for (int x = 0; x < image.width; x++) {
          newImage.setPixelRgb(x, y, 255, 255, 255);
        }
      }

      img.drawString(
        newImage,
        timestamp,
        font: img.arial24,
        x: 10,
        y: image.height + 10,
        color: img.ColorRgb8(30, 30, 30),
      );

      return await _save(newImage, imagePath, suffix: '_timestamp');
    } catch (e) {
      print('addTimestamp error: $e');
      return imagePath;
    }
  }

  String _formatTimestamp(DateTime dt, String format) {
    return format
        .replaceAll('dd', dt.day.toString().padLeft(2, '0'))
        .replaceAll('MM', dt.month.toString().padLeft(2, '0'))
        .replaceAll('yyyy', dt.year.toString())
        .replaceAll('HH', dt.hour.toString().padLeft(2, '0'))
        .replaceAll('mm', dt.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', dt.second.toString().padLeft(2, '0'));
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Future<img.Image?> _load(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return img.decodeImage(bytes);
  }

  /// FIX: Always write to a UNIQUE path with timestamp so Flutter
  /// never serves cached version for a "changed" image.
  Future<String> _save(
    img.Image image,
    String originalPath, {
    String suffix = '_enhanced',
  }) async {
    final dir = await getTemporaryDirectory();
    final baseName = path.basenameWithoutExtension(originalPath);
    // Timestamp makes every saved file unique → no Flutter image cache collisions
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = path.join(dir.path, '${baseName}${suffix}_$ts.jpg');
    await File(outPath).writeAsBytes(img.encodeJpg(image, quality: 92));
    return outPath;
  }
}
