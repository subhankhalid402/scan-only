import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';

class AnnotationScreen extends StatefulWidget {
  final String imagePath;
  const AnnotationScreen({super.key, required this.imagePath});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  late Image _baseImage;
  final List<DrawingPoint> _points = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    _baseImage = Image.file(File(widget.imagePath));
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Annotate Document', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.undo),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Iconsax.trash),
            onPressed: _clearAnnotations,
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas
          Expanded(
            child: GestureDetector(
              onPanDown: (details) {
                _addPoint(details.localPosition);
              },
              onPanUpdate: (details) {
                _addPoint(details.localPosition);
              },
              onPanEnd: (details) {
                _points.add(DrawingPoint(Offset.zero, Colors.transparent, 0));
              },
              child: CustomPaint(
                painter: AnnotationPainter(_baseImage, _points),
                child: Container(
                  color: Colors.black,
                  child: _baseImage,
                ),
              ),
            ),
          ),

          // Tools
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Color picker
                Row(
                  children: [
                    Text('Color:', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    ...[Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.black, Colors.white]
                        .map((color) => GestureDetector(
                              onTap: () => setState(() => _selectedColor = color),
                              child: Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  border: Border.all(
                                    color: _selectedColor == color ? AppColors.gold : Colors.grey,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ))
                        .toList(),
                  ],
                ),
                const SizedBox(height: 12),

                // Stroke width
                Row(
                  children: [
                    Text('Thickness:', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1,
                        max: 10,
                        activeColor: AppColors.gold,
                        onChanged: (val) => setState(() => _strokeWidth = val),
                      ),
                    ),
                    Text('${_strokeWidth.toStringAsFixed(1)}', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _points),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                    child: Text(
                      'Save Annotations',
                      style: GoogleFonts.nunito(color: AppColors.navyDark, fontWeight: FontWeight.w800),
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

class AnnotationPainter extends CustomPainter {
  final Image baseImage;
  final List<DrawingPoint> points;

  AnnotationPainter(this.baseImage, this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
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
  bool shouldRepaint(AnnotationPainter oldDelegate) => true;
}
