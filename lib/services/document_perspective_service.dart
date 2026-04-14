import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Document scan: auto quadrilateral detection + perspective correction (CamScanner-style).
class DocumentPerspectiveService {
  DocumentPerspectiveService._();
  static final DocumentPerspectiveService instance = DocumentPerspectiveService._();

  static const int _detectMaxSide = 500;

  /// Returns four corners in **original image pixel space** (TL, TR, BR, BL), or null if detection fails.
  Future<List<Offset>?> detectDocumentCorners(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final full = img.decodeImage(bytes);
      if (full == null) return null;

      final small = full.width > _detectMaxSide || full.height > _detectMaxSide
          ? img.copyResize(
              full,
              width: full.width >= full.height ? _detectMaxSide : null,
              height: full.height > full.width ? _detectMaxSide : null,
              interpolation: img.Interpolation.average,
            )
          : full;

      final gray = img.grayscale(small);
      final blurred = img.gaussianBlur(gray, radius: 2);
      final mag = _sobelMagnitude(blurred);
      final thresh = _otsuThreshold(mag);
      var binary = _threshold(mag, thresh);
      binary = _dilateMax(binary, iterations: 2);

      var contour = _largestContourHull(binary);
      if (contour.length < 12) {
        final t2 = (thresh * 0.85).round().clamp(1, 254);
        binary = _threshold(mag, t2);
        binary = _dilateMax(binary, iterations: 3);
        contour = _largestContourHull(binary);
      }
      if (contour.length < 8) return null;

      final sx = full.width / small.width;
      final sy = full.height / small.height;

      for (var epsFrac = 0.003; epsFrac <= 0.08; epsFrac += 0.004) {
        final peri = _polygonPerimeter(contour);
        final eps = (epsFrac * peri).clamp(2.0, 200.0);
        var simplified = _douglasPeucker(contour, eps);
        if (simplified.length > 8) {
          simplified = _douglasPeucker(contour, eps * 2.5);
        }
        List<_IntPoint>? quad;
        if (simplified.length == 4) {
          quad = simplified;
        } else if (simplified.length > 4) {
          quad = _pickFourFromPolygon(simplified);
        } else if (simplified.length == 3) {
          continue;
        } else {
          quad = _pickFourFromPolygon(_convexHull(contour));
        }
        if (quad == null || quad.length != 4) continue;

        final area = _quadArea(quad);
        final minArea = small.width * small.height * 0.08;
        if (area < minArea) continue;

        final scaled = quad
            .map((e) => Offset(e.x * sx, e.y * sy))
            .toList(growable: false);
        return orderPointsRect(scaled);
      }
    } catch (e, st) {
      debugPrint('detectDocumentCorners: $e\n$st');
    }
    return null;
  }

  /// Default full-frame quad with small inset (normalized 0–1).
  List<Offset> defaultCornersNormalized() {
    const m = 0.02;
    return [
      const Offset(m, m),
      Offset(1 - m, m),
      Offset(1 - m, 1 - m),
      Offset(m, 1 - m),
    ];
  }

  /// Order corners: top-left, top-right, bottom-right, bottom-left.
  List<Offset> orderPointsRect(List<Offset> pts) {
    if (pts.length != 4) return pts;
    final arr = List<Offset>.from(pts);
    final s = arr.map((e) => e.dx + e.dy).toList();
    final d = arr.map((e) => e.dy - e.dx).toList();
    final tl = arr[s.indexOf(s.reduce(math.min))];
    final br = arr[s.indexOf(s.reduce(math.max))];
    final tr = arr[d.indexOf(d.reduce(math.min))];
    final bl = arr[d.indexOf(d.reduce(math.max))];
    return [tl, tr, br, bl];
  }

  /// [corners] in pixel space, ordered TL, TR, BR, BL.
  Future<String> warpToRectangle(
    String imagePath,
    List<Offset> corners, {
    int? maxOutputSide,
    double? targetAspectRatio,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final src = img.decodeImage(bytes);
    if (src == null) throw StateError('Could not decode image');

    final o = orderPointsRect(corners);
    final tl = o[0], tr = o[1], br = o[2], bl = o[3];
    final wTop = _dist(tl, tr);
    final wBot = _dist(bl, br);
    final hRight = _dist(tr, br);
    final hLeft = _dist(tl, bl);
    var outW = math.max(wTop, wBot).round().clamp(64, 10000);
    var outH = math.max(hLeft, hRight).round().clamp(64, 10000);
    if (targetAspectRatio != null && targetAspectRatio > 0) {
      final area = (outW * outH).toDouble();
      outW = math.sqrt(area * targetAspectRatio).round().clamp(64, 10000);
      outH = (outW / targetAspectRatio).round().clamp(64, 10000);
    }

    if (maxOutputSide != null) {
      final scale = maxOutputSide / math.max(outW, outH);
      if (scale < 1) {
        outW = (outW * scale).round();
        outH = (outH * scale).round();
      }
    }

    final dst = img.Image(width: outW, height: outH);
    final h = _homographyFromQuadToRect(
      srcTL: tl,
      srcTR: tr,
      srcBR: br,
      srcBL: bl,
      dstW: outW.toDouble(),
      dstH: outH.toDouble(),
    );

    for (var y = 0; y < outH; y++) {
      for (var x = 0; x < outW; x++) {
        final s = _applyHomographyInverse(h, x.toDouble(), y.toDouble());
        final c = _sampleBilinear(src, s.dx, s.dy);
        dst.setPixelRgba(x, y, c.r, c.g, c.b, c.a);
      }
    }

    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'doc_warp_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(outPath).writeAsBytes(img.encodeJpg(dst, quality: 92));
    return outPath;
  }

  // ── Homography (inverse map: dst pixel → src) ─────────────────────────────

  List<double> _homographyFromQuadToRect({
    required Offset srcTL,
    required Offset srcTR,
    required Offset srcBR,
    required Offset srcBL,
    required double dstW,
    required double dstH,
  }) {
    final dst = <Offset>[
      Offset.zero,
      Offset(dstW, 0),
      Offset(dstW, dstH),
      Offset(0, dstH),
    ];
    final src = [srcTL, srcTR, srcBR, srcBL];
    return _homographyDLT(src, dst);
  }

  /// Forward H: src → dst (homogeneous). Returns 9 values (row-major 3×3), H[8]=1.
  List<double> _homographyDLT(List<Offset> src, List<Offset> dst) {
    assert(src.length == 4 && dst.length == 4);
    final a = List.generate(8, (_) => List<double>.filled(8, 0));
    final b = List<double>.filled(8, 0);
    for (var i = 0; i < 4; i++) {
      final x = src[i].dx, y = src[i].dy;
      final u = dst[i].dx, v = dst[i].dy;
      a[2 * i][0] = x;
      a[2 * i][1] = y;
      a[2 * i][2] = 1;
      a[2 * i][6] = -u * x;
      a[2 * i][7] = -u * y;
      b[2 * i] = u;
      a[2 * i + 1][3] = x;
      a[2 * i + 1][4] = y;
      a[2 * i + 1][5] = 1;
      a[2 * i + 1][6] = -v * x;
      a[2 * i + 1][7] = -v * y;
      b[2 * i + 1] = v;
    }
    final x = _solve8(a, b);
    return [...x, 1.0];
  }

  List<double> _solve8(List<List<double>> a, List<double> b) {
    final m = List.generate(8, (i) => [...a[i], b[i]]);
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var r = col + 1; r < 8; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() < 1e-12) continue;
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
      final div = m[col][col];
      for (var c = col; c < 9; c++) {
        m[col][c] /= div;
      }
      for (var r = 0; r < 8; r++) {
        if (r == col) continue;
        final f = m[r][col];
        if (f == 0) continue;
        for (var c = col; c < 9; c++) {
          m[r][c] -= f * m[col][c];
        }
      }
    }
    return List.generate(8, (i) => m[i][8]);
  }

  Offset _applyHomographyInverse(List<double> h, double xd, double yd) {
    final hi = _invertHomography(h);
    final x = hi[0] * xd + hi[1] * yd + hi[2];
    final y = hi[3] * xd + hi[4] * yd + hi[5];
    final w = hi[6] * xd + hi[7] * yd + hi[8];
    if (w.abs() < 1e-9) return const Offset(0, 0);
    return Offset(x / w, y / w);
  }

  List<double> _invertHomography(List<double> h) {
    final a = h[0], b = h[1], c = h[2];
    final d = h[3], e = h[4], f = h[5];
    final g = h[6], i2 = h[7], j = h[8];
    final det = a * (e * j - f * i2) - b * (d * j - f * g) + c * (d * i2 - e * g);
    if (det.abs() < 1e-12) {
      return [1, 0, 0, 0, 1, 0, 0, 0, 1];
    }
    final inv = <double>[
      (e * j - f * i2) / det,
      (c * i2 - b * j) / det,
      (b * f - c * e) / det,
      (f * g - d * j) / det,
      (a * j - c * g) / det,
      (c * d - a * f) / det,
      (d * i2 - e * g) / det,
      (b * g - a * i2) / det,
      (a * e - b * d) / det,
    ];
    return inv;
  }

  img.Color _sampleBilinear(img.Image src, double xf, double yf) {
    final x = xf.clamp(0.0, src.width - 1.001);
    final y = yf.clamp(0.0, src.height - 1.001);
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = math.min(x0 + 1, src.width - 1);
    final y1 = math.min(y0 + 1, src.height - 1);
    final dx = x - x0;
    final dy = y - y0;
    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);
    double lerp(double a, double b, double t) => a + (b - a) * t;
    final r = lerp(
      lerp(p00.r.toDouble(), p10.r.toDouble(), dx),
      lerp(p01.r.toDouble(), p11.r.toDouble(), dx),
      dy,
    );
    final g = lerp(
      lerp(p00.g.toDouble(), p10.g.toDouble(), dx),
      lerp(p01.g.toDouble(), p11.g.toDouble(), dx),
      dy,
    );
    final b = lerp(
      lerp(p00.b.toDouble(), p10.b.toDouble(), dx),
      lerp(p01.b.toDouble(), p11.b.toDouble(), dx),
      dy,
    );
    return img.ColorRgba8(
      r.round().clamp(0, 255).toInt(),
      g.round().clamp(0, 255).toInt(),
      b.round().clamp(0, 255).toInt(),
      255,
    );
  }

  double _dist(Offset a, Offset b) {
    final dx = a.dx - b.dx, dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ── Edge / contour ────────────────────────────────────────────────────────

  img.Image _sobelMagnitude(img.Image gray) {
    final w = gray.width, h = gray.height;
    final out = img.Image(width: w, height: h);
    double gx(int x, int y) {
      final xm = math.max(0, x - 1), xp = math.min(w - 1, x + 1);
      final ym = math.max(0, y - 1), yp = math.min(h - 1, y + 1);
      final p = gray.getPixel;
      return (-p(xm, ym).r + p(xp, ym).r - 2 * p(xm, y).r + 2 * p(xp, y).r - p(xm, yp).r + p(xp, yp).r)
          .toDouble();
    }

    double gy(int x, int y) {
      final xm = math.max(0, x - 1), xp = math.min(w - 1, x + 1);
      final ym = math.max(0, y - 1), yp = math.min(h - 1, y + 1);
      final p = gray.getPixel;
      return (-p(xm, ym).r + p(xm, yp).r - 2 * p(x, ym).r + 2 * p(x, yp).r - p(xp, ym).r + p(xp, yp).r)
          .toDouble();
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final mx = gx(x, y);
        final my = gy(x, y);
        final m = math.sqrt(mx * mx + my * my).round().clamp(0, 255).toInt();
        out.setPixelRgba(x, y, m, m, m, 255);
      }
    }
    return out;
  }

  int _otsuThreshold(img.Image gray) {
    final hist = List<int>.filled(256, 0);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        hist[gray.getPixel(x, y).r.toInt().clamp(0, 255)] += 1;
      }
    }
    final total = gray.width * gray.height;
    double sum = 0;
    for (var i = 0; i < 256; i++) {
      sum += i * hist[i];
    }
    double sumB = 0;
    var wB = 0;
    var maxVar = 0.0;
    var threshold = 127;
    for (var t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final between = wB * wF * (mB - mF) * (mB - mF);
      if (between >= maxVar) {
        maxVar = between;
        threshold = t;
      }
    }
    return threshold;
  }

  img.Image _threshold(img.Image g, int t) {
    final out = img.Image(width: g.width, height: g.height);
    for (var y = 0; y < g.height; y++) {
      for (var x = 0; x < g.width; x++) {
        final v = g.getPixel(x, y).r.toInt() >= t ? 255 : 0;
        out.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    return out;
  }

  img.Image _dilateMax(img.Image bin, {required int iterations}) {
    var cur = bin;
    for (var n = 0; n < iterations; n++) {
      final next = img.Image(width: cur.width, height: cur.height);
      for (var y = 0; y < cur.height; y++) {
        for (var x = 0; x < cur.width; x++) {
          var mx = 0;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final xx = (x + dx).clamp(0, cur.width - 1).toInt();
              final yy = (y + dy).clamp(0, cur.height - 1).toInt();
              mx = math.max(mx, cur.getPixel(xx, yy).r.toInt());
            }
          }
          next.setPixelRgba(x, y, mx, mx, mx, 255);
        }
      }
      cur = next;
    }
    return cur;
  }

  /// Largest foreground blob → convex hull (document outline proxy).
  List<_IntPoint> _largestContourHull(img.Image binary) {
    final w = binary.width, h = binary.height;
    final vis = List.generate(h, (_) => List<bool>.filled(w, false));
    var bestArea = 0;
    List<_IntPoint> bestHull = [];

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (binary.getPixel(x, y).r < 128 || vis[y][x]) continue;
        final comp = _floodFillComponent(binary, vis, x, y);
        if (comp.length < bestArea) continue;
        var pts = comp;
        if (pts.length > 3000) {
          final step = (pts.length / 2500).ceil();
          pts = [for (var i = 0; i < pts.length; i += step) pts[i]];
        }
        bestArea = comp.length;
        bestHull = _convexHull(pts);
      }
    }
    return bestHull;
  }

  List<_IntPoint> _floodFillComponent(
    img.Image binary,
    List<List<bool>> vis,
    int sx,
    int sy,
  ) {
    final w = binary.width, h = binary.height;
    final q = Queue<List<int>>()..add([sx, sy]);
    vis[sy][sx] = true;
    final comp = <_IntPoint>[];
    const d4 = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];
    while (q.isNotEmpty) {
      final c = q.removeFirst();
      final x = c[0], y = c[1];
      comp.add(_IntPoint(x, y));
      for (final d in d4) {
        final nx = x + d[0], ny = y + d[1];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (vis[ny][nx]) continue;
        if (binary.getPixel(nx, ny).r < 128) continue;
        vis[ny][nx] = true;
        q.add([nx, ny]);
      }
    }
    return comp;
  }

  double _polygonPerimeter(List<_IntPoint> p) {
    if (p.length < 2) return 0;
    double sum = 0;
    for (var i = 0; i < p.length; i++) {
      final a = p[i], b = p[(i + 1) % p.length];
      sum += math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    }
    return sum;
  }

  double _quadArea(List<_IntPoint> q) {
    if (q.length != 4) return 0;
    double a = 0;
    for (var i = 0; i < 4; i++) {
      final p = q[i], r = q[(i + 1) % 4];
      a += p.x * r.y - r.x * p.y;
    }
    return a.abs() / 2;
  }

  List<_IntPoint> _douglasPeucker(List<_IntPoint> pts, double eps) {
    if (pts.length < 3) return List.from(pts);
    double perp(_IntPoint p, _IntPoint a, _IntPoint b) {
      final dx = (b.x - a.x).toDouble(), dy = (b.y - a.y).toDouble();
      if (dx == 0 && dy == 0) {
        return math.sqrt(math.pow(p.x - a.x, 2) + math.pow(p.y - a.y, 2));
      }
      final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy);
      final px = a.x + t * dx, py = a.y + t * dy;
      return math.sqrt(math.pow(p.x - px, 2) + math.pow(p.y - py, 2));
    }

    var dmax = 0.0;
    var idx = 0;
    for (var i = 1; i < pts.length - 1; i++) {
      final d = perp(pts[i], pts.first, pts.last);
      if (d > dmax) {
        dmax = d;
        idx = i;
      }
    }
    if (dmax > eps) {
      final a = _douglasPeucker(pts.sublist(0, idx + 1), eps);
      final b = _douglasPeucker(pts.sublist(idx), eps);
      return [...a.sublist(0, a.length - 1), ...b];
    }
    return [pts.first, pts.last];
  }

  List<_IntPoint> _convexHull(List<_IntPoint> pts) {
    if (pts.length < 3) return List.from(pts);
    final sorted = List<_IntPoint>.from(pts)
      ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    int cross(_IntPoint o, _IntPoint a, _IntPoint b) =>
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    final lower = <_IntPoint>[];
    for (final p in sorted) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <_IntPoint>[];
    for (var i = sorted.length - 1; i >= 0; i--) {
      final p = sorted[i];
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  List<_IntPoint>? _pickFourFromPolygon(List<_IntPoint> poly) {
    if (poly.length < 4) return null;
    if (poly.length == 4) return poly;
    final hull = poly.length > 8 ? _convexHull(poly) : poly;
    if (hull.length == 4) return hull;
    if (hull.length < 4) return null;
    double cx = 0, cy = 0;
    for (final p in hull) {
      cx += p.x;
      cy += p.y;
    }
    cx /= hull.length;
    cy /= hull.length;
    _IntPoint? bestForQ(int q) {
      _IntPoint? best;
      var bestScore = -1e18;
      for (final p in hull) {
        final dx = p.x - cx, dy = p.y - cy;
        double score;
        if (q == 0) {
          score = -dx - dy;
        } else if (q == 1) {
          score = dx - dy;
        } else if (q == 2) {
          score = dx + dy;
        } else {
          score = -dx + dy;
        }
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
      return best;
    }

    final q0 = bestForQ(0)!, q1 = bestForQ(1)!, q2 = bestForQ(2)!, q3 = bestForQ(3)!;
    final set = {q0, q1, q2, q3};
    if (set.length < 4) return null;
    return [q0, q1, q2, q3];
  }
}

class _IntPoint {
  final int x, y;
  const _IntPoint(this.x, this.y);
}
