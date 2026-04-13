import 'dart:io';

import 'package:image/image.dart' as img;

/// One suggested look for a text watermark (colour + opacity + UX copy).
class WatermarkStylePreset {
  final String id;
  final String title;
  final String tip;
  final int r;
  final int g;
  final int b;
  final int a;

  const WatermarkStylePreset({
    required this.id,
    required this.title,
    required this.tip,
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });
}

/// Samples the scan and builds presets + short insight text.
class WatermarkStyleSuggester {
  WatermarkStyleSuggester._();

  static double _channelLuminance(int r, int g, int b) =>
      (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;

  /// Mean perceived brightness: 0 = dark, 1 = bright.
  static Future<double> meanLuminance(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return 0.65;
      final bytes = await file.readAsBytes();
      final im = img.decodeImage(bytes);
      if (im == null) return 0.65;
      final small = img.copyResize(im, width: 120);
      var sum = 0.0;
      var n = 0;
      for (var y = 0; y < small.height; y += 2) {
        for (var x = 0; x < small.width; x += 2) {
          final p = small.getPixel(x, y);
          sum += _channelLuminance(p.r.toInt(), p.g.toInt(), p.b.toInt());
          n++;
        }
      }
      if (n == 0) return 0.65;
      return (sum / n).clamp(0.0, 1.0);
    } catch (_) {
      return 0.65;
    }
  }

  static String insightLine(double luminance) {
    if (luminance >= 0.55) {
      return 'This scan looks bright — darker watermarks usually stay readable on light paper.';
    }
    if (luminance <= 0.4) {
      return 'This scan looks dark — lighter watermarks stand out better here.';
    }
    return 'Contrast looks balanced — pick a style below. You can adjust strength before applying.';
  }

  /// Ordered list: image-aware options first, then universal accents.
  static List<WatermarkStylePreset> presetsForLuminance(double luminance) {
    final bright = luminance >= 0.52;
    final dark = luminance < 0.42;
    final out = <WatermarkStylePreset>[];

    if (bright) {
      out.addAll(const [
        WatermarkStylePreset(
          id: 'deep_ink',
          title: 'Deep ink',
          tip: 'Best match for bright documents.',
          r: 26,
          g: 30,
          b: 46,
          a: 118,
        ),
        WatermarkStylePreset(
          id: 'charcoal',
          title: 'Charcoal',
          tip: 'Strong but still professional.',
          r: 58,
          g: 58,
          b: 64,
          a: 98,
        ),
      ]);
    } else if (dark) {
      out.addAll(const [
        WatermarkStylePreset(
          id: 'mist',
          title: 'Soft white',
          tip: 'Best match for dark or shadowy scans.',
          r: 242,
          g: 244,
          b: 250,
          a: 102,
        ),
        WatermarkStylePreset(
          id: 'silver',
          title: 'Silver',
          tip: 'Readable on photos and grey backgrounds.',
          r: 198,
          g: 204,
          b: 214,
          a: 92,
        ),
      ]);
    } else {
      out.add(const WatermarkStylePreset(
        id: 'balanced',
        title: 'Balanced grey',
        tip: 'Safe default for typical scans.',
        r: 92,
        g: 98,
        b: 112,
        a: 102,
      ));
    }

    out.addAll(const [
      WatermarkStylePreset(
        id: 'subtle',
        title: 'Subtle',
        tip: 'Very light — minimal distraction.',
        r: 158,
        g: 164,
        b: 176,
        a: 68,
      ),
      WatermarkStylePreset(
        id: 'gold',
        title: 'Accent gold',
        tip: 'Warm brand-style highlight.',
        r: 215,
        g: 165,
        b: 20,
        a: 112,
      ),
      WatermarkStylePreset(
        id: 'navy',
        title: 'Navy',
        tip: 'Formal, certificate-style tone.',
        r: 26,
        g: 47,
        b: 107,
        a: 108,
      ),
      WatermarkStylePreset(
        id: 'confidential',
        title: 'Alert red',
        tip: 'Stands out for confidential / internal use.',
        r: 208,
        g: 68,
        b: 62,
        a: 102,
      ),
    ]);

    return out;
  }
}
