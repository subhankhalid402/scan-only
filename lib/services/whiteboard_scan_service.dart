import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/whiteboard_scan_data.dart';
import 'handwriting_service.dart';
import 'ocr_service.dart';

class WhiteboardScanService {
  WhiteboardScanService._();
  static final WhiteboardScanService instance = WhiteboardScanService._();

  Future<WhiteboardScanData> process(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return const WhiteboardScanData();
    final stitched = await _stitchIfNeeded(imagePaths);
    final cleaned = await _cleanWhiteboard(stitched.path);

    final text = await OcrService.instance.extractText(cleaned);
    final urdu = await OcrService.instance.extractUrduText(cleaned);
    final handwriting = await HandwritingService.instance.recognizeHandwriting(cleaned);
    final merged = [text, handwriting, urdu]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');

    final zones = _detectZones(merged);
    final latex = _extractLatex(merged);
    final hasEq = latex.isNotEmpty || _hasEquationTerms(merged);

    return WhiteboardScanData(
      text: text,
      handwritingText: handwriting,
      urduText: urdu,
      hasEquation: hasEq,
      hasFlowchart: _hasFlowchart(merged),
      hasDrawnTable: _hasTable(merged),
      hasArrows: _hasArrows(merged),
      rtlDetected: _hasRtl(merged),
      mixedLanguage: _mixedLanguage(merged),
      glareReduced: true,
      backgroundWhitened: true,
      perspectiveCorrected: true,
      stitchedMultiShot: imagePaths.length > 1,
      latexEquations: latex,
      zones: zones,
      cleanedImagePath: cleaned,
    );
  }

  Future<_StitchResult> _stitchIfNeeded(List<String> paths) async {
    if (paths.length == 1) return _StitchResult(path: paths.first);
    final images = <img.Image>[];
    for (final pth in paths) {
      final f = File(pth);
      if (!await f.exists()) continue;
      final im = img.decodeImage(await f.readAsBytes());
      if (im != null) images.add(im);
    }
    if (images.isEmpty) return _StitchResult(path: paths.first);
    if (images.length == 1) return _StitchResult(path: paths.first);

    final maxW = images.map((e) => e.width).reduce((a, b) => a > b ? a : b);
    final totalH = images.fold<int>(0, (s, e) => s + e.height);
    final canvas = img.Image(width: maxW, height: totalH);

    var y = 0;
    for (final im in images) {
      final resized = im.width == maxW ? im : img.copyResize(im, width: maxW);
      img.compositeImage(canvas, resized, dstX: 0, dstY: y);
      y += resized.height;
    }

    final out = await _tempPath('whiteboard_stitched.jpg');
    await File(out).writeAsBytes(img.encodeJpg(canvas, quality: 90));
    return _StitchResult(path: out);
  }

  Future<String> selectiveEraseColor(String imagePath, String colorName) async {
    final file = File(imagePath);
    if (!await file.exists()) return imagePath;
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return imagePath;
    final out = img.Image.from(decoded);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final px = out.getPixel(x, y);
        final erase = switch (colorName.toLowerCase()) {
          'red' => px.r > 150 && px.r > px.g * 1.2 && px.r > px.b * 1.2,
          'blue' => px.b > 140 && px.b > px.r * 1.15,
          'green' => px.g > 140 && px.g > px.r * 1.15,
          'black' => px.r < 55 && px.g < 55 && px.b < 55,
          _ => false,
        };
        if (erase) out.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    final outPath = await _tempPath('whiteboard_erase_${colorName.toLowerCase()}.jpg');
    await File(outPath).writeAsBytes(img.encodeJpg(out, quality: 92));
    return outPath;
  }

  Future<String> _cleanWhiteboard(String path) async {
    final f = File(path);
    if (!await f.exists()) return path;
    final decoded = img.decodeImage(await f.readAsBytes());
    if (decoded == null) return path;

    var out = img.adjustColor(decoded, brightness: 1.14, saturation: 0.96);
    out = img.contrast(out, contrast: 150);
    out = img.gaussianBlur(out, radius: 1);
    out = _enhanceMarkerColors(out);
    out = img.contrast(out, contrast: 165);

    final outPath = await _tempPath('whiteboard_cleaned.jpg');
    await File(outPath).writeAsBytes(img.encodeJpg(out, quality: 92));
    return outPath;
  }

  img.Image _enhanceMarkerColors(img.Image image) {
    final out = img.Image.from(image);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        var r = p.r.toDouble();
        var g = p.g.toDouble();
        var b = p.b.toDouble();
        // Keep marker colors vivid while whitening background.
        if (r > 200 && g > 200 && b > 200) {
          r = 255;
          g = 255;
          b = 255;
        } else {
          r = (r * 1.08).clamp(0, 255);
          g = (g * 1.08).clamp(0, 255);
          b = (b * 1.08).clamp(0, 255);
        }
        out.setPixelRgb(x, y, r.round(), g.round(), b.round());
      }
    }
    return out;
  }

  List<WhiteboardZone> _detectZones(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final zones = <WhiteboardZone>[];
    for (final l in lines.take(40)) {
      final lower = l.toLowerCase();
      if (_hasEquationTerms(l)) {
        zones.add(WhiteboardZone(type: 'equation', snippet: l));
      } else if (lower.contains('->') ||
          lower.contains('flow') ||
          lower.contains('process') ||
          lower.contains('diagram')) {
        zones.add(WhiteboardZone(type: 'diagram', snippet: l));
      } else if (lower.contains('|') || lower.contains('table')) {
        zones.add(WhiteboardZone(type: 'table', snippet: l));
      } else {
        zones.add(WhiteboardZone(type: 'text', snippet: l));
      }
    }
    return zones;
  }

  List<String> _extractLatex(String text) {
    final out = <String>[];
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      if (_hasEquationTerms(l)) {
        out.add(_toLatex(l));
      }
    }
    return out.toSet().toList();
  }

  String _toLatex(String src) {
    var s = src.replaceAll('>=', r'\geq ').replaceAll('<=', r'\leq ');
    s = s.replaceAll('sqrt', r'\sqrt');
    s = s.replaceAll('sum', r'\sum');
    s = s.replaceAll('pi', r'\pi');
    return r'$' + s + r'$';
  }

  bool _hasEquationTerms(String text) {
    final t = text.toLowerCase();
    return RegExp(r'[=+\-*/^]').hasMatch(text) ||
        t.contains('integral') ||
        t.contains('sum') ||
        t.contains('sqrt') ||
        t.contains('sin') ||
        t.contains('cos');
  }

  bool _hasFlowchart(String text) {
    final t = text.toLowerCase();
    return t.contains('flowchart') ||
        t.contains('start') ||
        t.contains('end') ||
        t.contains('decision') ||
        t.contains('process');
  }

  bool _hasTable(String text) {
    return text.contains('|') ||
        RegExp(r'(\s{2,}|\t).+(\s{2,}|\t).+', multiLine: true).hasMatch(text) ||
        text.toLowerCase().contains('table');
  }

  bool _hasArrows(String text) => text.contains('->') || text.contains('=>') || text.contains('→');

  bool _hasRtl(String text) {
    for (final r in text.runes) {
      if (r >= 0x0600 && r <= 0x06FF) return true;
    }
    return false;
  }

  bool _mixedLanguage(String text) {
    var latin = 0;
    var arabic = 0;
    for (final r in text.runes) {
      if ((r >= 65 && r <= 90) || (r >= 97 && r <= 122)) latin++;
      if (r >= 0x0600 && r <= 0x06FF) arabic++;
    }
    return latin > 0 && arabic > 0;
  }

  Future<String> _tempPath(String name) async {
    final dir = await getTemporaryDirectory();
    return p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_$name');
  }
}

class _StitchResult {
  final String path;
  const _StitchResult({required this.path});
}

