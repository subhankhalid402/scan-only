import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;

import '../services/document_perspective_service.dart';
import '../services/image_enhancement_service.dart';
import '../theme.dart';

/// Deskew flow: auto edge estimate, drag corners, optional filters, then perspective crop.
class DocumentScanEditorScreen extends StatefulWidget {
  final String imagePath;
  final double? targetAspectRatio;

  const DocumentScanEditorScreen({
    super.key,
    required this.imagePath,
    this.targetAspectRatio,
  });

  @override
  State<DocumentScanEditorScreen> createState() => _DocumentScanEditorScreenState();
}

class _DocumentScanEditorScreenState extends State<DocumentScanEditorScreen> {
  late final String _basePath;
  late String _activePath;
  double _iw = 1, _ih = 1;
  late List<Offset> _norm;
  int? _dragIx;
  bool _busy = false;
  bool _detecting = true;
  bool _ready = false;
  DocumentScanFilterKind _filter = DocumentScanFilterKind.none;

  @override
  void initState() {
    super.initState();
    _basePath = widget.imagePath;
    _activePath = widget.imagePath;
    _norm = DocumentPerspectiveService.instance.defaultCornersNormalized();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _detecting = true;
      _ready = false;
    });
    await _measureImage();
    await _runAutoDetect();
    if (mounted) {
      setState(() {
        _detecting = false;
        _ready = true;
      });
    }
  }

  Future<void> _measureImage() async {
    try {
      final bytes = await File(_activePath).readAsBytes();
      final im = img.decodeImage(bytes);
      if (im != null && mounted) {
        setState(() {
          _iw = im.width.toDouble();
          _ih = im.height.toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _runAutoDetect() async {
    final pts =
        await DocumentPerspectiveService.instance.detectDocumentCorners(_activePath);
    if (!mounted) return;
    if (pts != null && pts.length == 4) {
      setState(() {
        _norm = [
          for (final p in pts) Offset(p.dx / _iw, p.dy / _ih),
        ];
      });
    }
  }

  Future<void> _resetCorners() async {
    HapticFeedback.lightImpact();
    setState(() {
      _norm = DocumentPerspectiveService.instance.defaultCornersNormalized();
      _detecting = true;
    });
    await _runAutoDetect();
    if (mounted) setState(() => _detecting = false);
  }

  Future<void> _setFilter(DocumentScanFilterKind k) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      if (k == DocumentScanFilterKind.none) {
        if (!mounted) return;
        FileImage(File(_activePath)).evict();
        setState(() {
          _activePath = _basePath;
          _filter = k;
        });
        return;
      }
      final next = await ImageEnhancementService.instance.applyDocumentScanFilter(
        _basePath,
        k,
      );
      if (!mounted) return;
      FileImage(File(_activePath)).evict();
      setState(() {
        _activePath = next;
        _filter = k;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyWarp() async {
    if (_busy || !_ready || _iw < 2 || _ih < 2) return;
    setState(() => _busy = true);
    try {
      final px = [
        for (final n in _norm) Offset(n.dx * _iw, n.dy * _ih),
      ];
      final out = await DocumentPerspectiveService.instance.warpToRectangle(
        _activePath,
        px,
        maxOutputSide: 3200,
        targetAspectRatio: widget.targetAspectRatio,
      );
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deskew failed: $e',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails d, int index, Size box) {
    setState(() {
      final nx = (_norm[index].dx + d.delta.dx / box.width).clamp(0.02, 0.98);
      final ny = (_norm[index].dy + d.delta.dy / box.height).clamp(0.02, 0.98);
      _norm[index] = Offset(nx, ny);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0C),
        foregroundColor: Colors.white,
        title: Text(
          'Align document',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          TextButton.icon(
            onPressed: (_busy || _detecting) ? null : _resetCorners,
            icon: const Icon(Iconsax.refresh_left_square, size: 18),
            label: Text('Auto', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_detecting)
            const LinearProgressIndicator(
              color: AppColors.gold,
              backgroundColor: Colors.white12,
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final maxW = c.maxWidth - 24;
                final maxH = c.maxHeight - 24;
                final ia = widget.targetAspectRatio ?? (_iw / _ih);
                final ba = maxW / maxH;
                late double dw, dh;
                if (ba > ia) {
                  dh = maxH;
                  dw = dh * ia;
                } else {
                  dw = maxW;
                  dh = dw / ia;
                }
                final box = Size(dw, dh);
                return Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: dw,
                        height: dh,
                        color: Colors.black,
                        child: Image.file(
                          File(_activePath),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      CustomPaint(
                        size: box,
                        painter: _QuadPainter(
                          corners: _norm,
                          color: AppColors.gold,
                        ),
                      ),
                      for (var i = 0; i < 4; i++)
                        _cornerHandle(
                          i,
                          box,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          _filterBar(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_busy || !_ready || _detecting) ? null : _applyWarp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navyDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Iconsax.tick_circle, size: 20),
                      label: Text(
                        'Apply & continue',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerHandle(int index, Size box) {
    final n = _norm[index];
    final left = n.dx * box.width - 22;
    final top = n.dy * box.height - 22;
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (d) => _onPanUpdate(d, index, box),
        onPanStart: (_) {
          HapticFeedback.lightImpact();
          setState(() => _dragIx = index);
        },
        onPanEnd: (_) => setState(() => _dragIx = null),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _dragIx == index ? AppColors.gold : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.navyDark, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    Widget chip(String label, DocumentScanFilterKind k, IconData icon) {
      final sel = _filter == k;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_busy || _detecting) ? null : () => _setFilter(k),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.gold : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.gold : Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: sel ? AppColors.navyDark : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: sel ? AppColors.navyDark : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF121214),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Original', DocumentScanFilterKind.none, Iconsax.image),
            chip('B & W', DocumentScanFilterKind.blackWhite, Iconsax.document_text),
            chip('Gray', DocumentScanFilterKind.grayscale, Iconsax.colors_square),
            chip('Color', DocumentScanFilterKind.color, Iconsax.sun_1),
            chip('Magic', DocumentScanFilterKind.magic, Iconsax.magic_star),
          ],
        ),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final List<Offset> corners;
  final Color color;

  _QuadPainter({required this.corners, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;
    final path = Path()
      ..moveTo(corners[0].dx * size.width, corners[0].dy * size.height)
      ..lineTo(corners[1].dx * size.width, corners[1].dy * size.height)
      ..lineTo(corners[2].dx * size.width, corners[2].dy * size.height)
      ..lineTo(corners[3].dx * size.width, corners[3].dy * size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _QuadPainter old) =>
      old.corners != corners || old.color != color;
}
