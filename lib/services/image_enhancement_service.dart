import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// CamScanner-style single-tap filters on the document scan editor.
enum DocumentScanFilterKind {
  none,
  blackWhite,
  grayscale,
  color,
  magic,
}

class ImageEnhancementService {
  static final ImageEnhancementService instance = ImageEnhancementService._init();
  ImageEnhancementService._init();

  /// After camera capture: light document-style polish, image v4–safe.
  Future<String> polishCaptureForScanMode(
    String imagePath,
    String modeId, {
    String filter = 'auto',
  }) async {
    const skip = {'qr', 'photo', 'gallery'};
    if (skip.contains(modeId)) return imagePath;
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      final resolved = filter.toLowerCase();

      switch (resolved) {
        case 'bw':
          image = _applyBw(image);
          break;
        case 'color':
          image = _applyColorBoost(image);
          break;
        case 'grayscale':
          image = img.grayscale(image);
          break;
        case 'whitening':
          image = _applyWhitening(image);
          break;
        case 'contrast':
          image = img.contrast(image, contrast: 150);
          break;
        case 'thermal':
          image = _applyThermalReceipt(image);
          break;
        case 'brighten':
          image = img.adjustColor(image, brightness: 1.16);
          break;
        case 'flatten':
          image = _applyFlattenNormalize(image);
          break;
        case 'warm':
          image = _applyWarm(image);
          break;
        case 'cool':
          image = _applyCool(image);
          break;
        case 'vivid':
          image = _applyVivid(image);
          break;
        case 'id_clear':
          image = _applyIdClear(image);
          break;
        case 'mrz':
          image = _applyMrzBoost(image);
          break;
        case 'enhanced':
          image = _applyEnhanced(image);
          break;
        case 'deblur':
          image = _applyDeblur(image);
          break;
        case 'grid':
          image = _applyGridEnhance(image);
          break;
        case 'none':
          return imagePath;
        case 'auto':
        default:
          image = _applyAutoByMode(image, modeId);
          break;
      }
      return await _save(image, imagePath, suffix: '_${resolved}_polish');
    } catch (e) {
      debugPrint('polishCaptureForScanMode: $e');
      return imagePath;
    }
  }

  img.Image _applyAutoByMode(img.Image image, String modeId) {
    switch (modeId) {
      case 'document':
      case 'whiteboard':
        return _applyWhitening(image);
      case 'receipt':
        return _applyThermalReceipt(image);
      case 'id_card':
        return _applyIdClear(image);
      case 'passport':
        return _applyMrzBoost(image);
      case 'table':
        return _applyGridEnhance(image);
      case 'book':
        return _applyFlattenNormalize(image);
      default:
        return _applyEnhanced(image);
    }
  }

  img.Image _applyBw(img.Image image) {
    final gray = img.grayscale(image);
    return img.contrast(gray, contrast: 145);
  }

  img.Image _applyColorBoost(img.Image image) {
    var out = img.adjustColor(image, saturation: 1.20, brightness: 1.03);
    out = img.contrast(out, contrast: 120);
    return out;
  }

  img.Image _applyWhitening(img.Image image) {
    var out = img.adjustColor(image, brightness: 1.15, saturation: 0.88);
    out = img.contrast(out, contrast: 138);
    out = img.contrast(out, contrast: 145);
    return out;
  }

  img.Image _applyThermalReceipt(img.Image image) {
    var out = img.grayscale(image);
    out = img.contrast(out, contrast: 165);
    out = img.adjustColor(out, brightness: 1.08);
    return out;
  }

  img.Image _applyFlattenNormalize(img.Image image) {
    // Perspective warp requires corner points; normalize exposure/contrast here.
    var out = img.adjustColor(image, brightness: 1.10, saturation: 0.95);
    out = img.contrast(out, contrast: 132);
    out = img.contrast(out, contrast: 140);
    return out;
  }

  img.Image _applyWarm(img.Image image) {
    final w = image.width;
    final h = image.height;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (p.r * 1.12).round().clamp(0, 255),
          (p.g * 1.04).round().clamp(0, 255),
          (p.b * 0.88).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  img.Image _applyCool(img.Image image) {
    final w = image.width;
    final h = image.height;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (p.r * 0.90).round().clamp(0, 255),
          (p.g * 0.96).round().clamp(0, 255),
          (p.b * 1.14).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  img.Image _applyVivid(img.Image image) {
    var out = img.adjustColor(image, saturation: 1.32, brightness: 1.04);
    out = img.contrast(out, contrast: 130);
    return out;
  }

  img.Image _applyIdClear(img.Image image) {
    var out = img.gaussianBlur(image, radius: 1);
    out = _unsharpMask(out, amount: 0.85);
    out = img.contrast(out, contrast: 145);
    return out;
  }

  img.Image _applyMrzBoost(img.Image image) {
    var out = img.grayscale(image);
    out = img.contrast(out, contrast: 176);
    out = _unsharpMask(out, amount: 1.0);
    return out;
  }

  img.Image _applyEnhanced(img.Image image) {
    var out = _unsharpMask(image, amount: 0.7);
    out = img.contrast(out, contrast: 142);
    return out;
  }

  img.Image _applyDeblur(img.Image image) {
    return _unsharpMask(image, amount: 1.2);
  }

  img.Image _applyGridEnhance(img.Image image) {
    var out = img.grayscale(image);
    out = _unsharpMask(out, amount: 0.8);
    out = img.contrast(out, contrast: 175);
    return out;
  }

  img.Image _unsharpMask(img.Image image, {double amount = 0.8}) {
    final blurred = img.gaussianBlur(image, radius: 1);
    final out = img.Image(width: image.width, height: image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final s = image.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        final r = (s.r + (s.r - b.r) * amount).round().clamp(0, 255);
        final g = (s.g + (s.g - b.g) * amount).round().clamp(0, 255);
        final bl = (s.b + (s.b - b.b) * amount).round().clamp(0, 255);
        out.setPixelRgba(x, y, r, g, bl, s.a);
      }
    }
    return out;
  }

  /// CamScanner-style “clear document”: whiter paper, sharper text, mild desaturation.
  Future<String> polishDocumentCamScannerStyle(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.adjustColor(image, brightness: 1.08, saturation: 0.82);
      image = img.contrast(image, contrast: 124);
      return await _save(image, imagePath, suffix: '_docscan');
    } catch (e) {
      debugPrint('polishDocumentCamScannerStyle: $e');
      return imagePath;
    }
  }

  /// “Magic color” — punchy color retention + contrast (document pages).
  Future<String> magicColorDocument(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.adjustColor(image, brightness: 1.05, saturation: 1.12);
      image = img.contrast(image, contrast: 128);
      return await _save(image, imagePath, suffix: '_magic');
    } catch (e) {
      debugPrint('magicColorDocument: $e');
      return imagePath;
    }
  }

  Future<String> applyDocumentScanFilter(
    String imagePath,
    DocumentScanFilterKind kind,
  ) async {
    switch (kind) {
      case DocumentScanFilterKind.none:
        return imagePath;
      case DocumentScanFilterKind.blackWhite:
        return documentBlackAndWhite(imagePath);
      case DocumentScanFilterKind.grayscale:
        return toGrayscale(imagePath);
      case DocumentScanFilterKind.color:
        try {
          var image = await _load(imagePath);
          if (image == null) return imagePath;
          image = _applyColorBoost(image);
          return await _save(image, imagePath, suffix: '_scan_color');
        } catch (e) {
          debugPrint('applyDocumentScanFilter color: $e');
          return imagePath;
        }
      case DocumentScanFilterKind.magic:
        return magicColorDocument(imagePath);
    }
  }

  /// High-contrast black & white scan.
  Future<String> documentBlackAndWhite(String imagePath) async {
    try {
      var image = await _load(imagePath);
      if (image == null) return imagePath;
      image = img.grayscale(image);
      image = img.adjustColor(image, brightness: 1.04);
      image = img.contrast(image, contrast: 135);
      return await _save(image, imagePath, suffix: '_docbw');
    } catch (e) {
      debugPrint('documentBlackAndWhite: $e');
      return imagePath;
    }
  }

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
      image = _applyVivid(image);
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
      image = _applyDeblur(image);
      image = img.contrast(image, contrast: 175);
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
      image = img.adjustColor(image, brightness: 1.10, saturation: 0.88);
      image = img.contrast(image, contrast: 116);
      image = img.gaussianBlur(image, radius: 1);
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
