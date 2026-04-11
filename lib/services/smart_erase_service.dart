import 'dart:io';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'ocr_service.dart';

/// Result of [SmartEraseService.smartErase]: [applied] is false when the image was left unchanged.
class SmartEraseResult {
  SmartEraseResult({required this.imagePath, required this.applied});

  final String imagePath;
  final bool applied;
}

class SmartEraseService {
  static final SmartEraseService instance = SmartEraseService._init();
  SmartEraseService._init();

  /// Max area for one OCR box (fraction of image). Larger boxes are usually full-page mistakes.
  static const double _maxBoxAreaFraction = 0.28;

  /// Skip tiny noise detections.
  static const double _minBoxAreaPx = 120;

  /// Padding around each text box (smaller = less “white bleeding” into the rest of the page).
  static const double _boxPad = 3;

  /// Removes detected text (ML Kit) by painting white over those regions only.
  /// Does not modify the whole image when no safe regions are found.
  Future<SmartEraseResult> smartErase(
    String imagePath, {
    List<EraseRect>? eraseAreas,
  }) async {
    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      throw StateError('Image file not found');
    }

    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);

    if (image == null) {
      throw StateError('Could not decode image');
    }

    if (eraseAreas != null && eraseAreas.isNotEmpty) {
      for (final rect in eraseAreas) {
        _eraseArea(image, rect);
      }
      final out = await _saveErasedImage(image);
      return SmartEraseResult(imagePath: out, applied: true);
    }

    final boxes =
        await OcrService.instance.getTextBoundingBoxesForErase(imagePath);
    final filtered = _filterBoxes(boxes, image.width, image.height);

    if (filtered.isEmpty) {
      return SmartEraseResult(imagePath: imagePath, applied: false);
    }

    for (final box in filtered) {
      _eraseDartUiRect(image, box, pad: _boxPad);
    }

    final out = await _saveErasedImage(image);
    return SmartEraseResult(imagePath: out, applied: true);
  }

  /// Drops noise and oversized mistaken rects (often a single box covering most of the page).
  List<Rect> _filterBoxes(List<Rect> boxes, int iw, int ih) {
    final imgArea = iw * ih.toDouble();
    final maxBox = _maxBoxAreaFraction * imgArea;

    return boxes
        .where((b) {
          final a = b.width * b.height;
          return a >= _minBoxAreaPx && a <= maxBox;
        })
        .toList();
  }

  void _eraseDartUiRect(img.Image image, Rect box, {required double pad}) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final left = (box.left - pad).clamp(0.0, w);
    final top = (box.top - pad).clamp(0.0, h);
    final right = (box.right + pad).clamp(0.0, w);
    final bottom = (box.bottom + pad).clamp(0.0, h);
    if (right <= left || bottom <= top) return;
    _eraseArea(
      image,
      EraseRect(
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      ),
    );
  }

  void _eraseArea(img.Image image, EraseRect rect) {
    final x1 = rect.x.toInt().clamp(0, image.width - 1);
    final y1 = rect.y.toInt().clamp(0, image.height - 1);
    final x2 = (rect.x + rect.width).ceil().clamp(0, image.width);
    final y2 = (rect.y + rect.height).ceil().clamp(0, image.height);

    for (int y = y1; y < y2; y++) {
      for (int x = x1; x < x2; x++) {
        image.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }

  Future<String> _saveErasedImage(img.Image image) async {
    final dir = await getTemporaryDirectory();
    final outPath = path.join(
      dir.path,
      'smart_erase_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(outPath).writeAsBytes(img.encodeJpg(image, quality: 92));
    return outPath;
  }
}

class EraseRect {
  final double x;
  final double y;
  final double width;
  final double height;

  EraseRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
