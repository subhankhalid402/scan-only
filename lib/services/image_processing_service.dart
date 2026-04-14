import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'document_perspective_service.dart';
import 'image_enhancement_service.dart';

enum CamScanEnhanceMode { auto, magic, blackWhite, grayscale, original }

class ImageProcessingResult {
  final String imagePath;
  final List<Offset>? corners;
  final bool perspectiveApplied;

  const ImageProcessingResult({
    required this.imagePath,
    required this.corners,
    required this.perspectiveApplied,
  });
}

class ImageProcessingService {
  ImageProcessingService._();
  static final ImageProcessingService instance = ImageProcessingService._();

  Future<ImageProcessingResult> processCapture({
    required String imagePath,
    required String modeId,
    required CamScanEnhanceMode enhanceMode,
    double? targetAspectRatio,
    int maxOutputSide = 2048,
  }) async {
    var outPath = imagePath;
    List<Offset>? corners;
    var perspectiveApplied = false;

    // Step 1-4: detect edges + perspective transform.
    if (_shouldDeskew(modeId)) {
      corners = await DocumentPerspectiveService.instance
          .detectDocumentCorners(imagePath);
      if (corners != null && corners.length == 4) {
        outPath = await DocumentPerspectiveService.instance.warpToRectangle(
          imagePath,
          corners,
          maxOutputSide: maxOutputSide,
          targetAspectRatio: targetAspectRatio,
        );
        perspectiveApplied = true;
      }
    }

    // Step 5: auto light enhancement.
    outPath = await applyEnhancement(
      imagePath: outPath,
      modeId: modeId,
      enhanceMode: enhanceMode,
    );

    return ImageProcessingResult(
      imagePath: outPath,
      corners: corners,
      perspectiveApplied: perspectiveApplied,
    );
  }

  Future<String> applyEnhancement({
    required String imagePath,
    required String modeId,
    required CamScanEnhanceMode enhanceMode,
  }) async {
    switch (enhanceMode) {
      case CamScanEnhanceMode.auto:
        return _autoEnhance(imagePath, modeId);
      case CamScanEnhanceMode.magic:
        return ImageEnhancementService.instance.magicColorDocument(imagePath);
      case CamScanEnhanceMode.blackWhite:
        return ImageEnhancementService.instance
            .documentBlackAndWhite(imagePath);
      case CamScanEnhanceMode.grayscale:
        return ImageEnhancementService.instance.applyDocumentScanFilter(
          imagePath,
          DocumentScanFilterKind.grayscale,
        );
      case CamScanEnhanceMode.original:
        return imagePath;
    }
  }

  Future<String> applyBrightnessContrast({
    required String imagePath,
    required double brightness,
    required double contrast,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final outBytes =
        await compute(_brightnessContrastIsolate, <String, dynamic>{
      'bytes': bytes,
      'brightness': brightness,
      'contrast': contrast,
    });
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'quick_tone_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(outPath).writeAsBytes(outBytes);
    return outPath;
  }

  bool _shouldDeskew(String modeId) {
    const modes = {
      'document',
      'receipt',
      'id_card',
      'driving_license',
      'passport',
      'book',
      'whiteboard',
      'table',
      'academic_certificate',
    };
    return modes.contains(modeId);
  }

  Future<String> _autoEnhance(String imagePath, String modeId) async {
    final bytes = await File(imagePath).readAsBytes();
    final outBytes = await compute(_autoEnhanceIsolate, <String, dynamic>{
      'bytes': bytes,
      'mode': modeId,
    });
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'auto_enhance_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(outPath).writeAsBytes(outBytes);
    return outPath;
  }
}

Uint8List _brightnessContrastIsolate(Map<String, dynamic> payload) {
  final bytes = payload['bytes'] as List<int>;
  final brightness = payload['brightness'] as double;
  final contrast = payload['contrast'] as double;
  final src = img.decodeImage(Uint8List.fromList(bytes));
  if (src == null) return Uint8List.fromList(bytes);
  var out = img.adjustColor(src, brightness: brightness);
  out = img.contrast(out, contrast: contrast);
  return Uint8List.fromList(img.encodeJpg(out, quality: 92));
}

Uint8List _autoEnhanceIsolate(Map<String, dynamic> payload) {
  final bytes = payload['bytes'] as List<int>;
  final mode = payload['mode'] as String;
  final src = img.decodeImage(Uint8List.fromList(bytes));
  if (src == null) return Uint8List.fromList(bytes);

  var out = _whiteBalance(src);
  out = _modeBrightness(out, mode);
  out = _modeContrast(out, mode);
  out = _shadowNormalize(out);
  out = _unsharp(out, amount: 0.85);
  out = img.gaussianBlur(out, radius: 1);
  return Uint8List.fromList(img.encodeJpg(out, quality: 92));
}

img.Image _whiteBalance(img.Image src) {
  // Gray-world correction to reduce yellow/blue cast for paper scans.
  var sumR = 0.0, sumG = 0.0, sumB = 0.0;
  final total = src.width * src.height;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      sumR += p.r;
      sumG += p.g;
      sumB += p.b;
    }
  }
  final avgR = sumR / total;
  final avgG = sumG / total;
  final avgB = sumB / total;
  final gray = (avgR + avgG + avgB) / 3.0;
  final rGain = gray / (avgR == 0 ? 1 : avgR);
  final gGain = gray / (avgG == 0 ? 1 : avgG);
  final bGain = gray / (avgB == 0 ? 1 : avgB);
  final out = img.Image(width: src.width, height: src.height);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      out.setPixelRgb(
        x,
        y,
        (p.r * rGain).round().clamp(0, 255),
        (p.g * gGain).round().clamp(0, 255),
        (p.b * bGain).round().clamp(0, 255),
      );
    }
  }
  return out;
}

img.Image _modeBrightness(img.Image image, String mode) {
  switch (mode) {
    case 'receipt':
      return img.adjustColor(image, brightness: 1.16);
    case 'whiteboard':
      return img.adjustColor(image, brightness: 1.20, saturation: 1.05);
    case 'photo':
      return img.adjustColor(image, brightness: 1.04);
    default:
      return img.adjustColor(image, brightness: 1.10);
  }
}

img.Image _modeContrast(img.Image image, String mode) {
  switch (mode) {
    case 'document':
      return img.contrast(image, contrast: 160);
    case 'receipt':
      return img.contrast(image, contrast: 180);
    case 'id_card':
    case 'driving_license':
    case 'passport':
      return img.contrast(image, contrast: 130);
    case 'whiteboard':
      return img.contrast(image, contrast: 190);
    default:
      return img.contrast(image, contrast: 145);
  }
}

img.Image _shadowNormalize(img.Image image) {
  final out = img.Image(width: image.width, height: image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      final lift = luma < 90 ? 1.18 : 1.0;
      out.setPixelRgb(
        x,
        y,
        (p.r * lift).round().clamp(0, 255),
        (p.g * lift).round().clamp(0, 255),
        (p.b * lift).round().clamp(0, 255),
      );
    }
  }
  return out;
}

img.Image _unsharp(img.Image image, {double amount = 0.8}) {
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
