import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/photo_enhancement_service.dart';
import '../services/share_file_service.dart';
import '../theme.dart';

class PhotoEnhancementScreen extends StatefulWidget {
  final List<String> imagePaths;
  const PhotoEnhancementScreen({super.key, required this.imagePaths});

  @override
  State<PhotoEnhancementScreen> createState() => _PhotoEnhancementScreenState();
}

class _PhotoEnhancementScreenState extends State<PhotoEnhancementScreen> {
  late List<String> _pages;
  int _index = 0;
  bool _busy = false;
  double _brightness = 1.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _warmth = 0.0;
  double _sharpness = 0.0;
  double _vignette = 0.0;
  double _fade = 0.0;
  PhotoQualityPreset _quality = PhotoQualityPreset.high;

  @override
  void initState() {
    super.initState();
    _pages = List<String>.from(widget.imagePaths);
  }

  String get _current => _pages[_index];

  Future<void> _applyAutoAll() async {
    setState(() => _busy = true);
    try {
      _pages = await PhotoEnhancementService.instance.batchAutoEnhance(_pages);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyManualCurrent() async {
    setState(() => _busy = true);
    try {
      final out = await PhotoEnhancementService.instance.applyManual(
        _current,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        warmth: _warmth,
        sharpness: _sharpness,
        vignette: _vignette,
        fade: _fade,
      );
      _pages[_index] = out;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyDocMode() async {
    setState(() => _busy = true);
    try {
      _pages[_index] = await PhotoEnhancementService.instance.documentPhotoMode(_current);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyRestore() async {
    setState(() => _busy = true);
    try {
      _pages[_index] = await PhotoEnhancementService.instance.oldPhotoRestore(_current);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyPortraitAi() async {
    setState(() => _busy = true);
    try {
      _pages[_index] = await PhotoEnhancementService.instance.aiPortraitBoost(_current);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportAndShare() async {
    setState(() => _busy = true);
    try {
      final paths = <String>[];
      for (final p in _pages) {
        paths.add(
          await PhotoEnhancementService.instance.exportImage(
            p,
            format: PhotoExportFormat.jpg,
            quality: _quality,
          ),
        );
      }
      final png = await PhotoEnhancementService.instance.exportImage(
        _current,
        format: PhotoExportFormat.png,
        quality: _quality,
      );
      final webp = await PhotoEnhancementService.instance.exportImage(
        _current,
        format: PhotoExportFormat.webp,
        quality: _quality,
      );
      paths.add(png);
      paths.add(webp);
      final pdf = await PdfService.instance.createPdfFromImages(_pages, 'Enhanced_Photos');
      paths.add(pdf);

      final thumb = await PdfService.instance.generateThumbnail(_pages.first);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: 'Enhanced_Photos.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'photo',
          pageCount: _pages.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          tags: const ['Photo', 'Enhanced'],
        ),
      );
      if (!mounted) return;
      await ShareFileService.sharePaths(paths, text: 'Enhanced photos');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Photo Enhancement', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Center(
                    child: Image.file(File(_pages[i]), fit: BoxFit.contain),
                  ),
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                    ),
                  ),
              ],
            ),
          ),
          _controls(),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('Auto Enhance', _applyAutoAll),
                _btn('Manual Apply', _applyManualCurrent),
                _btn('Doc Mode', _applyDocMode),
                _btn('Restore', _applyRestore),
                _btn('Portrait AI', _applyPortraitAi),
              ],
            ),
            const SizedBox(height: 8),
            _slider('Brightness', _brightness, 0.7, 1.4, (v) => setState(() => _brightness = v)),
            _slider('Contrast', _contrast, 0.7, 1.5, (v) => setState(() => _contrast = v)),
            _slider('Saturation', _saturation, 0.5, 1.6, (v) => setState(() => _saturation = v)),
            _slider('Warmth', _warmth, -1.0, 1.0, (v) => setState(() => _warmth = v)),
            _slider('Sharpness', _sharpness, 0.0, 1.5, (v) => setState(() => _sharpness = v)),
            _slider('Vignette', _vignette, 0.0, 1.0, (v) => setState(() => _vignette = v)),
            _slider('Fade', _fade, 0.0, 1.0, (v) => setState(() => _fade = v)),
            Row(
              children: [
                Text('Quality', style: GoogleFonts.nunito(color: Colors.white70)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<PhotoQualityPreset>(
                    isExpanded: true,
                  value: _quality,
                  dropdownColor: const Color(0xFF1A2438),
                  items: const [
                    DropdownMenuItem(value: PhotoQualityPreset.low, child: Text('Low')),
                    DropdownMenuItem(value: PhotoQualityPreset.medium, child: Text('Medium')),
                    DropdownMenuItem(value: PhotoQualityPreset.high, child: Text('High')),
                  ],
                  onChanged: (v) => setState(() => _quality = v ?? PhotoQualityPreset.high),
                ),
                ),  // Expanded
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navyDark,
                  ),
                  onPressed: _busy ? null : _exportAndShare,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String t, VoidCallback onTap) => OutlinedButton(
        onPressed: _busy ? null : onTap,
        child: Text(t),
      );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: GoogleFonts.nunito(color: Colors.white60, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: _busy ? null : onChanged,
          ),
        ),
      ],
    );
  }
}

