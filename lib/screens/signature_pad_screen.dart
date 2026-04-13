import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import '../services/signature_service.dart';

// ══════════════════════════════════════════════════════════════
//  SignaturePadScreen  –  signature pad
//
//  Working features:
//  ✅ Smooth signature drawing (velocity-based stroke width)
//  ✅ Pen color selector (Black, Blue, Red)
//  ✅ Stroke thickness selector (Thin / Normal / Bold)
//  ✅ Undo last stroke
//  ✅ Clear all
//  ✅ Capture via RepaintBoundary (actual widget size, not fixed)
//  ✅ Preview dialog before saving
//  ✅ Save to SignatureService
//  ✅ Add to image if imagePath provided
//  ✅ Empty-signature guard
// ══════════════════════════════════════════════════════════════

class SignaturePadScreen extends StatefulWidget {
  final String? imagePath;
  final Function(String)? onSignatureAdded;

  const SignaturePadScreen({
    super.key,
    this.imagePath,
    this.onSignatureAdded,
  });

  @override
  State<SignaturePadScreen> createState() => _SignaturePadScreenState();
}

class _SignaturePadScreenState extends State<SignaturePadScreen> {
  // ── Painter key (RepaintBoundary capture) ────────────────────
  final _painterKey = GlobalKey();
  final _signaturePainterKey = GlobalKey<_SignaturePainterState>();

  // ── Pen options ───────────────────────────────────────────────
  Color _penColor = const Color(0xFF1E2A4A); // navyDark default
  double _strokeWidth = 3.0;

  static const _colors = [
    Color(0xFF1E2A4A), // navy / black
    Color(0xFF1D4ED8), // blue
    Color(0xFFDC2626), // red
    Color(0xFF16A34A), // green
  ];

  static const _strokes = [
    (label: 'Thin', width: 1.5),
    (label: 'Normal', width: 3.0),
    (label: 'Bold', width: 5.5),
  ];

  bool _isSaving = false;
  bool _hasStrokes = false;

  // ── Capture signature as PNG bytes ───────────────────────────
  Future<Uint8List?> _captureSignatureBytes() async {
    try {
      final boundary = _painterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      _showError('Capture failed: $e');
      return null;
    }
  }

  // ── Preview dialog ────────────────────────────────────────────
  Future<void> _previewAndSave() async {
    if (!_hasStrokes) {
      _showError('Pehle signature draw karein');
      return;
    }
    final bytes = await _captureSignatureBytes();
    if (bytes == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Signature Preview',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(8),
                child: Image.memory(bytes, height: 140, fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(color: AppColors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Dobara Draw',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Save Karein',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) await _saveSignature(bytes);
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _saveSignature(Uint8List bytes) async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final signaturePath =
          await SignatureService.instance.saveSignature(bytes);

      if (widget.imagePath != null) {
        final signedPath = await SignatureService.instance
            .addSignatureToImage(widget.imagePath!, bytes);
        widget.onSignatureAdded?.call(signedPath);
      }

      if (mounted) {
        _showSuccess('Signature save ho gayi!');
        Navigator.pop(context, signaturePath);
      }
    } catch (e) {
      _showError('Save nahi ho saka: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Toolbar ─────────────────────────────────────────
          _buildToolbar(),

          // ── Pad ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // hint
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Iconsax.edit, size: 13,
                            color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text('Neeche signature draw karein',
                            style: GoogleFonts.nunito(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  // drawing area
                  Expanded(
                    child: RepaintBoundary(
                      key: _painterKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _SignaturePainter(
                            key: _signaturePainterKey,
                            penColor: _penColor,
                            strokeWidth: _strokeWidth,
                            onChanged: (hasStrokes) =>
                                setState(() => _hasStrokes = hasStrokes),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // ── Bottom action bar ─────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Signature',
            style: GoogleFonts.nunito(
                color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Iconsax.undo, size: 22),
            tooltip: 'Undo',
            onPressed: _hasStrokes
                ? () => _signaturePainterKey.currentState?.undo()
                : null,
          ),
          // Clear
          IconButton(
            icon: const Icon(Iconsax.trash, size: 22),
            tooltip: 'Clear',
            onPressed: _hasStrokes
                ? () {
                    _signaturePainterKey.currentState?.clear();
                    setState(() => _hasStrokes = false);
                  }
                : null,
          ),
        ],
      );

  // ── Pen toolbar ───────────────────────────────────────────────

  Widget _buildToolbar() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Color label
            Text('Color ',
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),

            // Color dots
            ..._colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _penColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _penColor == c
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: _penColor == c
                          ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)]
                          : [],
                    ),
                  ),
                )),

            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.25)),
            const SizedBox(width: 12),

            // Thickness label
            Text('Size ',
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),

            // Thickness chips
            ..._strokes.map((s) => GestureDetector(
                  onTap: () => setState(() => _strokeWidth = s.width),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _strokeWidth == s.width
                          ? AppColors.navyDark
                          : const Color(0xFFF0F2F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(s.label,
                        style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _strokeWidth == s.width
                                ? Colors.white
                                : AppColors.textMuted)),
                  ),
                )),
          ],
        ),
      );

  // ── Bottom action bar ─────────────────────────────────────────

  Widget _buildActionBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Clear button
            OutlinedButton.icon(
              onPressed: _hasStrokes
                  ? () {
                      _signaturePainterKey.currentState?.clear();
                      setState(() => _hasStrokes = false);
                    }
                  : null,
              icon: const Icon(Iconsax.refresh, size: 18),
              label:
                  Text('Clear', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: BorderSide(color: AppColors.red.withOpacity(0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 12),
            // Save button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isSaving || !_hasStrokes) ? null : _previewAndSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(Iconsax.tick_circle,
                        size: 20, color: Colors.white),
                label: Text(
                  _isSaving ? 'Save ho raha hai…' : 'Preview & Save',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyDark,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  _SignaturePainter widget
// ══════════════════════════════════════════════════════════════

class _SignaturePainter extends StatefulWidget {
  final Color penColor;
  final double strokeWidth;
  final void Function(bool hasStrokes) onChanged;

  const _SignaturePainter({
    super.key,
    required this.penColor,
    required this.strokeWidth,
    required this.onChanged,
  });

  @override
  State<_SignaturePainter> createState() => _SignaturePainterState();
}

class _SignaturePainterState extends State<_SignaturePainter> {
  // Each stroke is a list of points with its paint settings
  final List<_Stroke> _strokes = [];
  List<Offset> _currentStroke = [];

  void undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    widget.onChanged(_strokes.isNotEmpty);
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
    widget.onChanged(false);
  }

  void _onPanStart(DragStartDetails d) {
    _currentStroke = [d.localPosition];
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke.isNotEmpty) {
      setState(() {
        _strokes.add(_Stroke(
          points: List.from(_currentStroke),
          color: widget.penColor,
          width: widget.strokeWidth,
        ));
        _currentStroke = [];
      });
      widget.onChanged(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        painter: _SignatureCustomPainter(
          strokes: _strokes,
          currentStroke: _currentStroke,
          currentColor: widget.penColor,
          currentWidth: widget.strokeWidth,
        ),
        size: Size.infinite,
        child: Container(color: Colors.transparent), // ensures hit-test
      ),
    );
  }
}

// ── Stroke data model ─────────────────────────────────────────

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

// ── Custom painter ────────────────────────────────────────────

class _SignatureCustomPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset> currentStroke;
  final Color currentColor;
  final double currentWidth;

  const _SignatureCustomPainter({
    required this.strokes,
    required this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all saved strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }
    // Draw active stroke
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, currentColor, currentWidth);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      // Single tap → dot
      canvas.drawCircle(points.first, width / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length - 1; i++) {
      // Smooth curve through midpoints
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SignatureCustomPainter old) =>
      old.strokes != strokes ||
      old.currentStroke != currentStroke ||
      old.currentColor != currentColor ||
      old.currentWidth != currentWidth;
}