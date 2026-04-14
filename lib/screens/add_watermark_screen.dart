import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/watermark_service.dart';
import '../theme.dart';

class AddWatermarkScreen extends StatefulWidget {
  final List<String> imagePaths;
  const AddWatermarkScreen({super.key, required this.imagePaths});

  @override
  State<AddWatermarkScreen> createState() => _AddWatermarkScreenState();
}

class _AddWatermarkScreenState extends State<AddWatermarkScreen> {
  final _textCtrl = TextEditingController(text: 'CONFIDENTIAL');
  WatermarkType _type = WatermarkType.text;
  WatermarkPosition _position = WatermarkPosition.diagonal;
  WatermarkPattern _pattern = WatermarkPattern.diagonalRepeat;
  Color _color = const Color(0x99E53935);
  double _opacity = 0.30;
  double _fontSize = 72;
  double _angle = -45;
  double _imageSize = 0.30;
  bool _bold = true;
  bool _italic = false;
  bool _applyAll = true;
  bool _loading = false;
  String? _watermarkImagePath;
  List<WatermarkTemplate> _templates = const [];
  bool _before = false;

  static const _presets = [
    'CONFIDENTIAL',
    'DRAFT',
    'COPY',
    'SAMPLE',
    'ORIGINAL',
    'PAID',
    'APPROVED',
    'REJECTED',
    'TOP SECRET',
    'FOR REVIEW',
    'DO NOT COPY',
    'PERSONAL',
    'VOID',
    'EXPIRED',
    'CLASSIFIED',
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final t = await WatermarkService.instance.getTemplates();
    if (mounted) setState(() => _templates = t);
  }

  Future<void> _saveTemplate() async {
    final nameCtrl = TextEditingController(text: 'My Template');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        title: Text('Save template',
            style: GoogleFonts.nunito(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Template name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await WatermarkService.instance.saveTemplate(
      WatermarkTemplate(
        name: nameCtrl.text.trim().isEmpty ? 'Template' : nameCtrl.text.trim(),
        type: _type,
        text: _textCtrl.text.trim(),
        imagePath: _watermarkImagePath,
        fontSize: _fontSize,
        colorValue: _color.toARGB32(),
        opacity: _opacity,
        angle: _angle,
        position: _position,
        tiled: _position == WatermarkPosition.repeat,
        bold: _bold,
        italic: _italic,
      ),
    );
    await _loadTemplates();
  }

  void _applyTemplate(WatermarkTemplate t) {
    setState(() {
      _type = t.type;
      _textCtrl.text = t.text;
      _watermarkImagePath = t.imagePath;
      _fontSize = t.fontSize;
      _color = Color(t.colorValue);
      _opacity = t.opacity;
      _angle = t.angle;
      _position = t.position;
      _bold = t.bold;
      _italic = t.italic;
    });
  }

  Future<void> _pickImage() async {
    final pick = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pick == null) return;
    setState(() => _watermarkImagePath = pick.path);
  }

  Future<void> _apply() async {
    setState(() => _loading = true);
    final targets = _applyAll ? widget.imagePaths : [widget.imagePaths.first];
    final out = <String>[];
    try {
      for (final p in targets) {
        final src = File(p);
        File result;
        if (_type == WatermarkType.image && _watermarkImagePath != null) {
          result = await WatermarkService.instance.addImageWatermarkFile(
            inputImage: src,
            watermarkImage: File(_watermarkImagePath!),
            opacity: _opacity,
            size: _imageSize,
            position: _position,
          );
        } else if (_type == WatermarkType.pattern) {
          result = await WatermarkService.instance.addPatternWatermark(
            inputImage: src,
            text: _textCtrl.text.trim(),
            pattern: _pattern,
            color: _color,
            opacity: _opacity,
            angle: _angle,
          );
        } else {
          result = await WatermarkService.instance.addTextWatermarkFile(
            inputImage: src,
            text: _textCtrl.text.trim(),
            fontSize: _fontSize,
            color: _color,
            opacity: _opacity,
            angle: _angle,
            position: _position,
            tiled: _position == WatermarkPosition.repeat,
            bold: _bold,
            italic: _italic,
          );
        }
        out.add(result.path);
      }
      if (!mounted) return;
      Navigator.pop(context, out);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = widget.imagePaths.first;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Watermark',
            style: GoogleFonts.nunito(
                color: AppColors.gold, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              onPressed: _loading ? null : _saveTemplate,
              icon: const Icon(Icons.bookmark_add)),
          IconButton(
              onPressed: _loading ? null : _apply,
              icon: const Icon(Icons.check_circle)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                      child:
                          Image.file(File(previewPath), fit: BoxFit.contain)),
                ),
                if (!_before)
                  Positioned.fill(
                      child: IgnorePointer(child: _watermarkOverlay())),
              ],
            ),
          ),
          Container(
            color: AppColors.navyDark,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    ChoiceChip(
                        label: const Text('Text'),
                        selected: _type == WatermarkType.text,
                        onSelected: (_) =>
                            setState(() => _type = WatermarkType.text)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: const Text('Image'),
                        selected: _type == WatermarkType.image,
                        onSelected: (_) =>
                            setState(() => _type = WatermarkType.image)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: const Text('Pattern'),
                        selected: _type == WatermarkType.pattern,
                        onSelected: (_) =>
                            setState(() => _type = WatermarkType.pattern)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => setState(() => _before = !_before),
                        child: Text(_before ? 'After' : 'Before')),
                  ],
                ),
                if (_type != WatermarkType.image)
                  TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Watermark text',
                          labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 6),
                if (_type == WatermarkType.text ||
                    _type == WatermarkType.pattern)
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _presets
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                    label: Text(t),
                                    onPressed: () =>
                                        setState(() => _textCtrl.text = t)),
                              ))
                          .toList(),
                    ),
                  ),
                if (_templates.isNotEmpty)
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _templates
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                    label: Text(t.name),
                                    onPressed: () => _applyTemplate(t)),
                              ))
                          .toList(),
                    ),
                  ),
                Row(children: [
                  const Text('Size', style: TextStyle(color: Colors.white70)),
                  Expanded(
                      child: Slider(
                          value: _type == WatermarkType.image
                              ? _imageSize
                              : _fontSize,
                          min: _type == WatermarkType.image ? 0.1 : 20,
                          max: _type == WatermarkType.image ? 1.0 : 200,
                          activeColor: AppColors.gold,
                          onChanged: (v) => setState(() =>
                              _type == WatermarkType.image
                                  ? _imageSize = v
                                  : _fontSize = v))),
                  Text(
                      _type == WatermarkType.image
                          ? '${(_imageSize * 100).round()}%'
                          : _fontSize.round().toString(),
                      style: const TextStyle(color: Colors.white)),
                ]),
                Row(children: [
                  const Text('Opacity',
                      style: TextStyle(color: Colors.white70)),
                  Expanded(
                      child: Slider(
                          value: _opacity,
                          min: 0,
                          max: 1,
                          activeColor: AppColors.gold,
                          onChanged: (v) => setState(() => _opacity = v))),
                  Text('${(_opacity * 100).round()}%',
                      style: const TextStyle(color: Colors.white)),
                ]),
                if (_type != WatermarkType.image)
                  Row(children: [
                    const Text('Angle',
                        style: TextStyle(color: Colors.white70)),
                    Expanded(
                        child: Slider(
                            value: _angle,
                            min: -90,
                            max: 90,
                            activeColor: AppColors.gold,
                            onChanged: (v) => setState(() => _angle = v))),
                    Text('${_angle.round()}°',
                        style: const TextStyle(color: Colors.white)),
                  ]),
                Wrap(
                  spacing: 6,
                  children: WatermarkPosition.values
                      .map((p) => ChoiceChip(
                          label: Text(p.name),
                          selected: _position == p,
                          onSelected: (_) => setState(() => _position = p)))
                      .toList(),
                ),
                if (_type == WatermarkType.pattern)
                  Wrap(
                    spacing: 6,
                    children: WatermarkPattern.values
                        .map((p) => ChoiceChip(
                            label: Text(p.name),
                            selected: _pattern == p,
                            onSelected: (_) => setState(() => _pattern = p)))
                        .toList(),
                  ),
                if (_type == WatermarkType.image)
                  Row(
                    children: [
                      ElevatedButton(
                          onPressed: _pickImage,
                          child: const Text('Pick image/logo')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final pick = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          if (pick?.files.single.path != null) {
                            setState(() =>
                                _watermarkImagePath = pick!.files.single.path!);
                          }
                        },
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Checkbox(
                        value: _bold,
                        onChanged: (v) => setState(() => _bold = v ?? false)),
                    const Text('Bold', style: TextStyle(color: Colors.white)),
                    Checkbox(
                        value: _italic,
                        onChanged: (v) => setState(() => _italic = v ?? false)),
                    const Text('Italic', style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    Checkbox(
                        value: _applyAll,
                        onChanged: (v) =>
                            setState(() => _applyAll = v ?? true)),
                    const Text('All pages',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
                ColorPicker(
                  pickerColor: _color,
                  onColorChanged: (c) => setState(() => _color = c),
                  enableAlpha: true,
                  labelTypes: const [],
                  pickerAreaHeightPercent: 0.3,
                ),
                if (_loading)
                  const LinearProgressIndicator(color: AppColors.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _watermarkOverlay() {
    final text =
        _textCtrl.text.trim().isEmpty ? 'WATERMARK' : _textCtrl.text.trim();
    final style = GoogleFonts.nunito(
      fontSize: (_fontSize / 4).clamp(16.0, 64.0),
      color: _color.withValues(alpha: _opacity),
      fontWeight: _bold ? FontWeight.w800 : FontWeight.w500,
      fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: 2,
    );
    Alignment align = Alignment.center;
    switch (_position) {
      case WatermarkPosition.topLeft:
        align = Alignment.topLeft;
        break;
      case WatermarkPosition.topRight:
        align = Alignment.topRight;
        break;
      case WatermarkPosition.bottomLeft:
        align = Alignment.bottomLeft;
        break;
      case WatermarkPosition.bottomRight:
        align = Alignment.bottomRight;
        break;
      default:
        align = Alignment.center;
    }
    return Align(
      alignment: align,
      child: Transform.rotate(
        angle: _angle * 3.14159 / 180,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: style),
        ),
      ),
    );
  }
}
