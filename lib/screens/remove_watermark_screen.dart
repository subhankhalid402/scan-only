import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/watermark_service.dart';
import '../theme.dart';

class RemoveWatermarkScreen extends StatefulWidget {
  final String imagePath;
  const RemoveWatermarkScreen({super.key, required this.imagePath});

  @override
  State<RemoveWatermarkScreen> createState() => _RemoveWatermarkScreenState();
}

class _RemoveWatermarkScreenState extends State<RemoveWatermarkScreen> {
  Rect? _rect;
  bool _before = true;
  bool _busy = false;
  RemovalMethod _method = RemovalMethod.aiFill;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
  }

  Future<void> _autoDetect() async {
    final r = await WatermarkService.instance
        .autoDetectWatermark(inputImage: File(_currentPath));
    if (!mounted) return;
    setState(() => _rect = r);
  }

  Future<void> _remove() async {
    if (_rect == null) return;
    setState(() => _busy = true);
    try {
      final out = await WatermarkService.instance.removeWatermark(
        inputImage: File(_currentPath),
        selectedArea: _rect!,
        method: _method,
      );
      if (!mounted) return;
      setState(() {
        _currentPath = out.path;
        _before = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Remove Watermark',
            style: GoogleFonts.nunito(
                color: AppColors.gold, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              onPressed: () => Navigator.pop(context, _currentPath),
              icon: const Icon(Icons.check))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                    label: const Text('Before'),
                    selected: _before,
                    onSelected: (_) => setState(() => _before = true)),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('After'),
                    selected: !_before,
                    onSelected: (_) => setState(() => _before = false)),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => GestureDetector(
                onPanStart: (d) => setState(() => _rect = Rect.fromLTWH(
                    d.localPosition.dx, d.localPosition.dy, 1, 1)),
                onPanUpdate: (d) {
                  final r = _rect;
                  if (r == null) return;
                  setState(() =>
                      _rect = Rect.fromPoints(r.topLeft, d.localPosition));
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        child: Image.file(
                            File(_before ? widget.imagePath : _currentPath),
                            fit: BoxFit.contain),
                      ),
                    ),
                    if (_rect != null)
                      Positioned.fromRect(
                        rect: _rect!,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: AppColors.gold, width: 2),
                              color: AppColors.gold.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: AppColors.navyDark,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                        onPressed: _busy ? null : _autoDetect,
                        icon: const Icon(Icons.search),
                        label: const Text('Auto Detect')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                        onPressed: _busy ? null : _remove,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Remove Watermark')),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: RemovalMethod.values
                      .map((m) => ChoiceChip(
                            label: Text(m.name),
                            selected: _method == m,
                            onSelected: (_) => setState(() => _method = m),
                          ))
                      .toList(),
                ),
                if (_busy) const LinearProgressIndicator(color: AppColors.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
