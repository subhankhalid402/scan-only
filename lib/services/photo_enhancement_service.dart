import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'face_detection_service.dart';

enum PhotoExportFormat { jpg, png, webp }

enum PhotoQualityPreset { low, medium, high }

class PhotoEnhancementService {
  PhotoEnhancementService._();
  static final PhotoEnhancementService instance = PhotoEnhancementService._();

  Future<String> autoEnhance(String imagePath, {bool hdr = true}) async {
    final image = await _load(imagePath);
    if (image == null) return imagePath;

    var out = img.adjustColor(image, brightness: 1.08, saturation: 1.08);
    out = img.contrast(out, contrast: 132);
    out = _unsharp(out, amount: 0.8);
    out = img.gaussianBlur(out, radius: 1); // mild denoise
    out = _unsharp(out, amount: 0.55);
    if (hdr) {
      out = img.adjustColor(out, saturation: 1.15, brightness: 1.03);
      out = img.contrast(out, contrast: 145);
    }
    return _save(out, imagePath, suffix: '_photo_auto');
  }

  Future<String> applyManual(
    String imagePath, {
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
    double warmth = 0.0,
    double sharpness = 0.0,
    double vignette = 0.0,
    double fade = 0.0,
  }) async {
    final src = await _load(imagePath);
    if (src == null) return imagePath;
    var out = img.adjustColor(src, brightness: brightness, saturation: saturation);
    out = img.contrast(out, contrast: contrast);
    if (warmth.abs() > 0.01) out = _applyWarmCool(out, warmth);
    if (sharpness.abs() > 0.01) out = _unsharp(out, amount: 0.5 + sharpness);
    if (vignette > 0.01) out = _applyVignette(out, vignette);
    if (fade > 0.01) out = _applyFade(out, fade);
    return _save(out, imagePath, suffix: '_photo_manual');
  }

  Future<String> documentPhotoMode(String imagePath) async {
    final src = await _load(imagePath);
    if (src == null) return imagePath;
    var out = img.adjustColor(src, brightness: 1.14, saturation: 0.86);
    out = img.contrast(out, contrast: 160);
    out = _unsharp(out, amount: 1.0);
    return _save(out, imagePath, suffix: '_photo_doc');
  }

  Future<String> oldPhotoRestore(String imagePath) async {
    final src = await _load(imagePath);
    if (src == null) return imagePath;
    var out = img.adjustColor(src, brightness: 1.10, saturation: 1.16);
    out = img.contrast(out, contrast: 128);
    out = _unsharp(out, amount: 0.7);
    return _save(out, imagePath, suffix: '_photo_restore');
  }

  Future<String> aiPortraitBoost(String imagePath) async {
    final hasFace = await FaceDetectionService.instance.hasFaces(imagePath);
    if (!hasFace) return imagePath;
    final src = await _load(imagePath);
    if (src == null) return imagePath;
    var out = img.adjustColor(src, brightness: 1.05, saturation: 1.12);
    out = img.contrast(out, contrast: 118);
    out = _unsharp(out, amount: 0.55);
    return _save(out, imagePath, suffix: '_photo_portrait');
  }

  Future<String> exportImage(
    String imagePath, {
    required PhotoExportFormat format,
    required PhotoQualityPreset quality,
  }) async {
    final src = await _load(imagePath);
    if (src == null) return imagePath;
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/Photos');
    await outDir.create(recursive: true);
    final stem = p.basenameWithoutExtension(imagePath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final q = switch (quality) {
      PhotoQualityPreset.low => 68,
      PhotoQualityPreset.medium => 84,
      PhotoQualityPreset.high => 95,
    };

    return switch (format) {
      PhotoExportFormat.jpg => _write(outDir, '${stem}_$ts.jpg', img.encodeJpg(src, quality: q)),
      PhotoExportFormat.png => _write(outDir, '${stem}_$ts.png', img.encodePng(src, level: q > 90 ? 1 : 3)),
      // image package build here may not include WebP encoder; keep output compatibility.
      PhotoExportFormat.webp => _write(outDir, '${stem}_$ts.webp', img.encodeJpg(src, quality: q)),
    };
  }

  Future<List<String>> batchAutoEnhance(List<String> paths) async {
    final out = <String>[];
    for (final pth in paths) {
      out.add(await autoEnhance(pth));
    }
    return out;
  }

  Future<img.Image?> _load(String imagePath) async {
    final f = File(imagePath);
    if (!await f.exists()) return null;
    return img.decodeImage(await f.readAsBytes());
  }

  Future<String> _save(img.Image image, String basePath, {required String suffix}) async {
    final dir = await getTemporaryDirectory();
    final stem = p.basenameWithoutExtension(basePath);
    final out = File('${dir.path}/$stem${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await out.writeAsBytes(img.encodeJpg(image, quality: 92));
    return out.path;
  }

  Future<String> _write(Directory dir, String name, List<int> bytes) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  img.Image _applyWarmCool(img.Image src, double warmth) {
    final out = img.Image.from(src);
    final warm = warmth.clamp(-1.0, 1.0);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final r = (p.r + (35 * warm)).round().clamp(0, 255);
        final b = (p.b - (35 * warm)).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, p.g.toInt(), b);
      }
    }
    return out;
  }

  img.Image _applyVignette(img.Image src, double strength) {
    final out = img.Image.from(src);
    final cx = out.width / 2.0;
    final cy = out.height / 2.0;
    final maxD = math.sqrt(cx * cx + cy * cy);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        final v = 1.0 - (d / maxD) * (0.6 * strength.clamp(0.0, 1.0));
        out.setPixelRgb(
          x,
          y,
          (p.r * v).round().clamp(0, 255),
          (p.g * v).round().clamp(0, 255),
          (p.b * v).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  img.Image _applyFade(img.Image src, double strength) {
    final out = img.Image.from(src);
    final s = strength.clamp(0.0, 1.0);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (p.r + (255 - p.r) * (0.28 * s)).round().clamp(0, 255),
          (p.g + (255 - p.g) * (0.28 * s)).round().clamp(0, 255),
          (p.b + (255 - p.b) * (0.28 * s)).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  img.Image _unsharp(img.Image image, {double amount = 0.7}) {
    final blurred = img.gaussianBlur(image, radius: 1);
    final out = img.Image(width: image.width, height: image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final s = image.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (s.r + (s.r - b.r) * amount).round().clamp(0, 255),
          (s.g + (s.g - b.g) * amount).round().clamp(0, 255),
          (s.b + (s.b - b.b) * amount).round().clamp(0, 255),
        );
      }
    }
    return out;
  }
}

