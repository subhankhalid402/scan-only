import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

class AnnotationScreen extends StatefulWidget {
  final String imagePath;
  const AnnotationScreen({super.key, required this.imagePath});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  final GlobalKey _exportKey = GlobalKey();
  final List<DrawingPoint> _points = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  bool _saving = false;

  void _addPoint(Offset offset) {
    setState(() {
      _points.add(DrawingPoint(offset, _selectedColor, _strokeWidth));
    });
  }

  void _clearAnnotations() {
    setState(() => _points.clear());
  }

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() => _points.removeLast());
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return;
      final bytes = bd.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);
      if (mounted) Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Annotate',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Iconsax.undo), onPressed: _undo),
          IconButton(icon: const Icon(Iconsax.trash), onPressed: _clearAnnotations),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RepaintBoundary(
                  key: _exportKey,
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                        CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: AnnotationStrokePainter(_points),
                        ),
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanDown: (d) => _addPoint(d.localPosition),
                            onPanUpdate: (d) => _addPoint(d.localPosition),
                            onPanEnd: (_) {
                              setState(() {
                                _points.add(
                                    DrawingPoint(Offset.zero, Colors.transparent, 0));
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Color:',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    ...[
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                      Colors.yellow,
                      Colors.black,
                      Colors.white,
                    ].map((color) => GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: color,
                              border: Border.all(
                                color: _selectedColor == color
                                    ? AppColors.gold
                                    : Colors.grey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Thickness:',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1,
                        max: 10,
                        activeColor: AppColors.gold,
                        onChanged: (val) => setState(() => _strokeWidth = val),
                      ),
                    ),
                    Text(_strokeWidth.toStringAsFixed(1),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.navyDark,
                            ),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.nunito(
                              color: AppColors.navyDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawingPoint(this.offset, this.color, this.strokeWidth);

  bool get isEmpty => offset == Offset.zero;
}

class AnnotationStrokePainter extends CustomPainter {
  final List<DrawingPoint> points;

  AnnotationStrokePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      if (points[i].isEmpty || points[i + 1].isEmpty) continue;
      canvas.drawLine(
        points[i].offset,
        points[i + 1].offset,
        Paint()
          ..color = points[i].color
          ..strokeWidth = points[i].strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationStrokePainter oldDelegate) => true;
}
