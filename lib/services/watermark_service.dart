import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WatermarkType { text, image, pattern }

enum WatermarkPattern { diagonalRepeat, grid, centered, cornerStamp }

enum WatermarkPosition {
  center,
  diagonal,
  repeat,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  custom,
}

enum RemovalMethod { aiFill, backgroundFill, frequencyFilter }

class WatermarkTemplate {
  final String name;
  final WatermarkType type;
  final String text;
  final String? imagePath;
  final double fontSize;
  final int colorValue;
  final double opacity;
  final double angle;
  final WatermarkPosition position;
  final bool tiled;
  final bool bold;
  final bool italic;

  const WatermarkTemplate({
    required this.name,
    required this.type,
    required this.text,
    required this.imagePath,
    required this.fontSize,
    required this.colorValue,
    required this.opacity,
    required this.angle,
    required this.position,
    required this.tiled,
    required this.bold,
    required this.italic,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'text': text,
        'imagePath': imagePath,
        'fontSize': fontSize,
        'colorValue': colorValue,
        'opacity': opacity,
        'angle': angle,
        'position': position.name,
        'tiled': tiled,
        'bold': bold,
        'italic': italic,
      };

  factory WatermarkTemplate.fromJson(Map<String, dynamic> json) =>
      WatermarkTemplate(
        name: (json['name'] ?? 'Template').toString(),
        type: WatermarkType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => WatermarkType.text,
        ),
        text: (json['text'] ?? '').toString(),
        imagePath: json['imagePath']?.toString(),
        fontSize: ((json['fontSize'] ?? 64) as num).toDouble(),
        colorValue:
            ((json['colorValue'] ?? const Color(0x66FF0000).toARGB32()) as num)
                .toInt(),
        opacity: ((json['opacity'] ?? 0.3) as num).toDouble(),
        angle: ((json['angle'] ?? -45) as num).toDouble(),
        position: WatermarkPosition.values.firstWhere(
          (e) => e.name == json['position'],
          orElse: () => WatermarkPosition.diagonal,
        ),
        tiled: (json['tiled'] ?? false) as bool,
        bold: (json['bold'] ?? true) as bool,
        italic: (json['italic'] ?? false) as bool,
      );
}

class WatermarkService {
  static const _templateKey = 'wm_templates_v2';
  static const _mapKey = 'wm_origin_map_v2';

  static final WatermarkService instance = WatermarkService._init();
  WatermarkService._init();

  /// Backward-compatible helper.
  Future<String> addTextWatermark(
    String imagePath, {
    required String text,
    int red = 180,
    int green = 180,
    int blue = 180,
    int opacity = 100,
  }) async {
    try {
      final out = await addTextWatermarkFile(
        inputImage: File(imagePath),
        text: text,
        fontSize: 64,
        color: Color.fromARGB(opacity.clamp(0, 255), red, green, blue),
        opacity: opacity / 255.0,
        angle: -45,
        position: WatermarkPosition.diagonal,
        tiled: true,
      );
      return out.path;
    } catch (e) {
      // ignore: avoid_print
      print('Watermark Error: $e');
      return imagePath;
    }
  }

  Future<File> addTextWatermarkFile({
    required File inputImage,
    required String text,
    required double fontSize,
    required Color color,
    required double opacity,
    required double angle,
    required WatermarkPosition position,
    required bool tiled,
    bool bold = true,
    bool italic = false,
  }) async {
    final bytes = await inputImage.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw StateError('Could not decode image');

    final stamp = _renderTextStamp(
      text: text,
      fontSize: fontSize,
      color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      bold: bold,
      italic: italic,
    );
    final rotated = img.copyRotate(stamp, angle: angle);
    _placeStamp(image, rotated, position,
        tiled || position == WatermarkPosition.repeat);

    final outPath = await _saveImage(image, inputImage.path, '_watermarked');
    await _registerDerived(outPath, inputImage.path);
    return File(outPath);
  }

  Future<File> addImageWatermarkFile({
    required File inputImage,
    required File watermarkImage,
    required double opacity,
    required double size,
    required WatermarkPosition position,
  }) async {
    final src = img.decodeImage(await inputImage.readAsBytes());
    final wm = img.decodeImage(await watermarkImage.readAsBytes());
    if (src == null || wm == null) throw StateError('Could not decode image');

    final targetW = (src.width * size.clamp(0.1, 1.0)).round();
    final resized = img.copyResize(wm, width: targetW);
    final alphaApplied = _applyOpacity(resized, opacity.clamp(0.0, 1.0));
    _placeStamp(src, alphaApplied, position, false);

    final outPath = await _saveImage(src, inputImage.path, '_logo_watermarked');
    await _registerDerived(outPath, inputImage.path);
    return File(outPath);
  }

  Future<File> addPatternWatermark({
    required File inputImage,
    required String text,
    required WatermarkPattern pattern,
    required Color color,
    required double opacity,
    required double angle,
  }) async {
    final src = img.decodeImage(await inputImage.readAsBytes());
    if (src == null) throw StateError('Could not decode image');
    final stamp = _renderTextStamp(
      text: text,
      fontSize: 48,
      color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      bold: true,
      italic: false,
    );
    final rotated = img.copyRotate(stamp, angle: angle);
    if (pattern == WatermarkPattern.centered) {
      _placeStamp(src, rotated, WatermarkPosition.center, false);
    } else if (pattern == WatermarkPattern.cornerStamp) {
      _placeStamp(src, rotated, WatermarkPosition.bottomRight, false);
    } else if (pattern == WatermarkPattern.grid) {
      _gridStamp(src, rotated);
    } else {
      _placeStamp(src, rotated, WatermarkPosition.repeat, true);
    }
    final outPath =
        await _saveImage(src, inputImage.path, '_pattern_watermarked');
    await _registerDerived(outPath, inputImage.path);
    return File(outPath);
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
      // ignore: avoid_print
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
      final out = await addImageWatermarkFile(
        inputImage: File(imagePath),
        watermarkImage: File(watermarkImagePath),
        opacity: opacity,
        size: 0.2,
        position: WatermarkPosition.bottomRight,
      );
      return out.path;
    } catch (e) {
      // ignore: avoid_print
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

  Future<Rect> autoDetectWatermark({required File inputImage}) async {
    final src = img.decodeImage(await inputImage.readAsBytes());
    if (src == null) return Rect.zero;
    // Heuristic: low-contrast center region is usually watermark.
    final rw = (src.width * 0.62).round();
    final rh = (src.height * 0.36).round();
    final x = ((src.width - rw) / 2).round();
    final y = ((src.height - rh) / 2).round();
    return Rect.fromLTWH(
        x.toDouble(), y.toDouble(), rw.toDouble(), rh.toDouble());
  }

  Future<File> removeWatermark({
    required File inputImage,
    required Rect selectedArea,
    required RemovalMethod method,
  }) async {
    final src = img.decodeImage(await inputImage.readAsBytes());
    if (src == null) throw StateError('Could not decode image');
    final rect = _sanitizeRect(selectedArea, src.width, src.height);
    if (rect == Rect.zero) return inputImage;

    if (method == RemovalMethod.backgroundFill) {
      _bgFill(src, rect);
    } else if (method == RemovalMethod.frequencyFilter) {
      _frequencyFill(src, rect);
    } else {
      _aiInpaintLike(src, rect);
    }

    final outPath = await _saveImage(src, inputImage.path, '_wm_removed');
    return File(outPath);
  }

  Future<File?> removeAppAddedWatermark(File currentFile) async {
    final map = await _loadOriginMap();
    final origin = map[currentFile.path];
    if (origin == null) return null;
    final f = File(origin);
    if (!f.existsSync()) return null;
    return f;
  }

  Future<void> saveTemplate(WatermarkTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTemplates();
    final next = [...list.where((t) => t.name != template.name), template];
    await prefs.setString(
        _templateKey, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  Future<List<WatermarkTemplate>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templateKey);
    final builtins = _defaultTemplates();
    if (raw == null || raw.isEmpty) return builtins;
    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((e) =>
            WatermarkTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return [...builtins, ...decoded];
  }

  Future<List<File>> addTextWatermarkBulk({
    required List<File> inputImages,
    required String text,
    required Color color,
    required double opacity,
  }) async {
    final out = <File>[];
    for (final file in inputImages) {
      out.add(
        await addTextWatermarkFile(
          inputImage: file,
          text: text,
          fontSize: 64,
          color: color,
          opacity: opacity,
          angle: -45,
          position: WatermarkPosition.diagonal,
          tiled: true,
        ),
      );
    }
    return out;
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

  img.Image _renderTextStamp({
    required String text,
    required double fontSize,
    required Color color,
    required bool bold,
    required bool italic,
  }) {
    final up = text.isEmpty ? 'WATERMARK' : text.toUpperCase();
    final scale = (fontSize / 24.0).clamp(0.8, 6.0);
    final cw = (18 * scale).round();
    final ch = (32 * scale).round();
    final canvas = img.Image(
        width: math.max(cw * up.length, 40), height: math.max(ch, 24));
    final argb = color.toARGB32();
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final c = img.ColorRgba8(r, g, b, a);
    img.drawString(
      canvas,
      up,
      font: img.arial24,
      x: 0,
      y: 0,
      color: c,
    );
    if (bold) {
      img.drawString(canvas, up, font: img.arial24, x: 1, y: 0, color: c);
    }
    if (italic) {
      final slanted =
          img.Image(width: canvas.width + 16, height: canvas.height);
      for (var y = 0; y < canvas.height; y++) {
        final shift = ((canvas.height - y) * 0.12).round();
        for (var x = 0; x < canvas.width; x++) {
          final p = canvas.getPixel(x, y);
          if (p.a > 0) {
            slanted.setPixel(x + shift, y, p);
          }
        }
      }
      return slanted;
    }
    return canvas;
  }

  img.Image _applyOpacity(img.Image src, double opacity) {
    final out = img.Image(width: src.width, height: src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        out.setPixelRgba(
            x, y, p.r, p.g, p.b, (p.a * opacity).round().clamp(0, 255));
      }
    }
    return out;
  }

  void _placeStamp(
      img.Image base, img.Image stamp, WatermarkPosition position, bool tiled) {
    if (tiled) {
      final sx = (stamp.width * 1.4).round();
      final sy = (stamp.height * 1.8).round();
      for (var y = -stamp.height; y < base.height + stamp.height; y += sy) {
        for (var x = -stamp.width; x < base.width + stamp.width; x += sx) {
          img.compositeImage(base, stamp, dstX: x, dstY: y);
        }
      }
      return;
    }

    var x = (base.width - stamp.width) ~/ 2;
    var y = (base.height - stamp.height) ~/ 2;
    switch (position) {
      case WatermarkPosition.topLeft:
        x = 20;
        y = 20;
        break;
      case WatermarkPosition.topRight:
        x = base.width - stamp.width - 20;
        y = 20;
        break;
      case WatermarkPosition.bottomLeft:
        x = 20;
        y = base.height - stamp.height - 20;
        break;
      case WatermarkPosition.bottomRight:
        x = base.width - stamp.width - 20;
        y = base.height - stamp.height - 20;
        break;
      case WatermarkPosition.diagonal:
      case WatermarkPosition.center:
      case WatermarkPosition.custom:
      case WatermarkPosition.repeat:
        break;
    }
    img.compositeImage(base, stamp, dstX: x, dstY: y);
  }

  void _gridStamp(img.Image base, img.Image stamp) {
    final sx = (base.width / 3).round();
    final sy = (base.height / 4).round();
    for (var gy = 0; gy < 4; gy++) {
      for (var gx = 0; gx < 3; gx++) {
        final x = gx * sx + (sx - stamp.width) ~/ 2;
        final y = gy * sy + (sy - stamp.height) ~/ 2;
        img.compositeImage(base, stamp, dstX: x, dstY: y);
      }
    }
  }

  Rect _sanitizeRect(Rect r, int w, int h) {
    final left = r.left.clamp(0.0, w.toDouble() - 1);
    final top = r.top.clamp(0.0, h.toDouble() - 1);
    final right = r.right.clamp(left + 1, w.toDouble());
    final bottom = r.bottom.clamp(top + 1, h.toDouble());
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _aiInpaintLike(img.Image src, Rect rect) {
    final x1 = rect.left.round(), y1 = rect.top.round();
    final x2 = rect.right.round(), y2 = rect.bottom.round();
    for (var y = y1; y < y2; y++) {
      for (var x = x1; x < x2; x++) {
        var r = 0, g = 0, b = 0, c = 0;
        for (var yy = y - 4; yy <= y + 4; yy++) {
          for (var xx = x - 4; xx <= x + 4; xx++) {
            if (xx < x1 || xx >= x2 || yy < y1 || yy >= y2) {
              if (xx >= 0 && yy >= 0 && xx < src.width && yy < src.height) {
                final p = src.getPixel(xx, yy);
                r += p.r.toInt();
                g += p.g.toInt();
                b += p.b.toInt();
                c++;
              }
            }
          }
        }
        if (c > 0) {
          src.setPixelRgb(
              x, y, (r / c).round(), (g / c).round(), (b / c).round());
        }
      }
    }
  }

  void _bgFill(img.Image src, Rect rect) {
    final x1 = rect.left.round(), y1 = rect.top.round();
    final x2 = rect.right.round(), y2 = rect.bottom.round();
    final samples = <img.Pixel>[];
    for (var x = x1; x < x2; x++) {
      if (y1 - 1 >= 0) samples.add(src.getPixel(x, y1 - 1));
      if (y2 < src.height) samples.add(src.getPixel(x, y2));
    }
    for (var y = y1; y < y2; y++) {
      if (x1 - 1 >= 0) samples.add(src.getPixel(x1 - 1, y));
      if (x2 < src.width) samples.add(src.getPixel(x2, y));
    }
    if (samples.isEmpty) return;
    final r = samples.map((e) => e.r).reduce((a, b) => a + b) ~/ samples.length;
    final g = samples.map((e) => e.g).reduce((a, b) => a + b) ~/ samples.length;
    final b = samples.map((e) => e.b).reduce((a, b) => a + b) ~/ samples.length;
    img.fillRect(src,
        x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgb8(r, g, b));
  }

  void _frequencyFill(img.Image src, Rect rect) {
    final patch = img.copyCrop(
      src,
      x: rect.left.round(),
      y: rect.top.round(),
      width: rect.width.round(),
      height: rect.height.round(),
    );
    final blurred = img.gaussianBlur(patch, radius: 3);
    img.compositeImage(src, blurred,
        dstX: rect.left.round(), dstY: rect.top.round());
  }

  Future<void> _registerDerived(String derivedPath, String originalPath) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadOriginMap();
    map[derivedPath] = originalPath;
    await prefs.setString(_mapKey, jsonEncode(map));
  }

  Future<Map<String, String>> _loadOriginMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mapKey);
    if (raw == null || raw.isEmpty) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  List<WatermarkTemplate> _defaultTemplates() {
    return const [
      WatermarkTemplate(
        name: 'Confidential',
        type: WatermarkType.text,
        text: 'CONFIDENTIAL',
        imagePath: null,
        fontSize: 72,
        colorValue: 0xAAE53935,
        opacity: 0.30,
        angle: -45,
        position: WatermarkPosition.diagonal,
        tiled: false,
        bold: true,
        italic: false,
      ),
      WatermarkTemplate(
        name: 'Draft',
        type: WatermarkType.text,
        text: 'DRAFT',
        imagePath: null,
        fontSize: 66,
        colorValue: 0xAA9E9E9E,
        opacity: 0.28,
        angle: 0,
        position: WatermarkPosition.center,
        tiled: false,
        bold: true,
        italic: false,
      ),
      WatermarkTemplate(
        name: 'Official Copy',
        type: WatermarkType.text,
        text: 'OFFICIAL COPY',
        imagePath: null,
        fontSize: 56,
        colorValue: 0xAA1A237E,
        opacity: 0.24,
        angle: -35,
        position: WatermarkPosition.repeat,
        tiled: true,
        bold: true,
        italic: false,
      ),
      WatermarkTemplate(
        name: 'Paid Stamp',
        type: WatermarkType.text,
        text: 'PAID',
        imagePath: null,
        fontSize: 52,
        colorValue: 0xAA1B5E20,
        opacity: 0.35,
        angle: 0,
        position: WatermarkPosition.bottomRight,
        tiled: false,
        bold: true,
        italic: false,
      ),
      WatermarkTemplate(
        name: 'Void',
        type: WatermarkType.text,
        text: 'VOID',
        imagePath: null,
        fontSize: 72,
        colorValue: 0xAAE53935,
        opacity: 0.32,
        angle: -45,
        position: WatermarkPosition.diagonal,
        tiled: false,
        bold: true,
        italic: false,
      ),
    ];
  }
}
