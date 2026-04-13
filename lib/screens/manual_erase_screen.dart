import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:iconsax/iconsax.dart';

import '../services/smart_erase_service.dart';
import '../theme.dart';

/// User drags a rectangle on the page to choose what to remove.
class ManualEraseScreen extends StatefulWidget {
  const ManualEraseScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ManualEraseScreen> createState() => _ManualEraseScreenState();
}

class _ManualEraseScreenState extends State<ManualEraseScreen> {
  int? _iw;
  int? _ih;
  String? _loadError;

  /// Selection in **display** coordinates (same as SizedBox around the image).
  Offset? _dragStart;
  Offset? _dragEnd;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final im = img.decodeImage(bytes);
      if (!mounted) return;
      if (im == null) {
        setState(() => _loadError = 'Could not read image');
        return;
      }
      setState(() {
        _iw = im.width;
        _ih = im.height;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  void _clearSelection() {
    setState(() {
      _dragStart = null;
      _dragEnd = null;
    });
  }

  Rect? _displayRect() {
    if (_dragStart == null || _dragEnd == null) return null;
    final l = math.min(_dragStart!.dx, _dragEnd!.dx);
    final t = math.min(_dragStart!.dy, _dragEnd!.dy);
    final r = math.max(_dragStart!.dx, _dragEnd!.dx);
    final b = math.max(_dragStart!.dy, _dragEnd!.dy);
    if (r - l < 4 || b - t < 4) return null;
    return Rect.fromLTRB(l, t, r, b);
  }

  Future<void> _apply() async {
    final iw = _iw;
    final ih = _ih;
    if (iw == null || ih == null) return;

    final layout = _lastLayout;
    if (layout == null) return;

    final disp = layout.dispSize;
    final scale = layout.scale;
    final dispRect = _displayRect();
    if (dispRect == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Drag on the page to select an area to remove',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    double imgX = dispRect.left / scale;
    double imgY = dispRect.top / scale;
    double imgW = dispRect.width / scale;
    double imgH = dispRect.height / scale;

    imgX = imgX.clamp(0.0, iw.toDouble());
    imgY = imgY.clamp(0.0, ih.toDouble());
    imgW = imgW.clamp(0.0, iw.toDouble() - imgX);
    imgH = imgH.clamp(0.0, ih.toDouble() - imgY);

    if (imgW < 6 || imgH < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selection is too small',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await SmartEraseService.instance.smartErase(
        widget.imagePath,
        eraseAreas: [
          EraseRect(x: imgX, y: imgY, width: imgW, height: imgH),
        ],
      );
      if (!mounted) return;
      if (!result.applied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not apply erase',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.pop(context, result.imagePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erase failed: $e',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Latest layout metrics from [LayoutBuilder] (for mapping to image pixels).
  _LayoutMetrics? _lastLayout;

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1A2E),
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left_2),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Erase area', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center,
                style: GoogleFonts.nunito(color: Colors.white70)),
          ),
        ),
      );
    }

    if (_iw == null || _ih == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final iw = _iw!;
    final ih = _ih!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1A2E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Select area to remove',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _clearSelection,
            child: Text('Clear', style: GoogleFonts.nunito(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Drag a rectangle over the part you want to remove.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14, height: 1.35),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;
                final scale = math.min(maxW / iw, maxH / ih);
                final dispW = iw * scale;
                final dispH = ih * scale;
                _lastLayout = _LayoutMetrics(scale: scale, dispSize: Size(dispW, dispH));

                return Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) {
                      setState(() {
                        _dragStart = _clampLocal(d.localPosition, dispW, dispH);
                        _dragEnd = _dragStart;
                      });
                    },
                    onPanUpdate: (d) {
                      setState(() {
                        _dragEnd = _clampLocal(d.localPosition, dispW, dispH);
                      });
                    },
                    onPanEnd: (_) {},
                    child: CustomPaint(
                      foregroundPainter: _SelectionPainter(
                        start: _dragStart,
                        end: _dragEnd,
                      ),
                      child: SizedBox(
                        width: dispW,
                        height: dispH,
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF0F1A2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F1A2E)),
                        )
                      : Text(
                          'Remove selected area',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Offset _clampLocal(Offset p, double w, double h) {
    return Offset(p.dx.clamp(0.0, w), p.dy.clamp(0.0, h));
  }
}

class _LayoutMetrics {
  _LayoutMetrics({required this.scale, required this.dispSize});

  final double scale;
  final Size dispSize;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({this.start, this.end});

  final Offset? start;
  final Offset? end;

  @override
  void paint(Canvas canvas, Size size) {
    if (start == null || end == null) return;
    final l = math.min(start!.dx, end!.dx);
    final t = math.min(start!.dy, end!.dy);
    final r = math.max(start!.dx, end!.dx);
    final b = math.max(start!.dy, end!.dy);
    if (r - l < 2 || b - t < 2) return;

    final rect = Rect.fromLTRB(l, t, r, b);
    final fill = Paint()..color = AppColors.gold.withOpacity(0.28);
    final border = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}
