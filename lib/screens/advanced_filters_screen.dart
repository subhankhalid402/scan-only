import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;
import '../theme.dart';

// ─── Isolate payload ──────────────────────────────────────────────────────────

class _FilterParams {
  final String inputPath;
  final double brightness;
  final double contrast;
  final double saturation;
  final double sharpness;
  final bool grayscale;
  final bool blackWhite;
  final bool sepia;
  final bool invert;
  final bool cool;
  final bool warm;
  final SendPort sendPort;

  _FilterParams({
    required this.inputPath,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.sharpness,
    required this.grayscale,
    required this.blackWhite,
    required this.sepia,
    required this.invert,
    required this.cool,
    required this.warm,
    required this.sendPort,
  });
}

void _applyFiltersIsolate(_FilterParams p) {
  try {
    final bytes = File(p.inputPath).readAsBytesSync();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      p.sendPort.send({'error': 'Could not decode image'});
      return;
    }

    // 1. Mode filters
    if (p.blackWhite) {
      image = img.grayscale(image);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final lum = img.getLuminance(pixel);
          final val = lum > 128 ? 255 : 0;
          image.setPixelRgb(x, y, val, val, val);
        }
      }
    } else if (p.grayscale) {
      image = img.grayscale(image);
    } else if (p.sepia) {
      image = img.sepia(image);
    } else if (p.invert) {
      image = img.invert(image);
    } else if (p.cool) {
      // Cool: boost blue, reduce red slightly
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = (pixel.r.toInt() - 15).clamp(0, 255);
          final g = pixel.g.toInt();
          final b = (pixel.b.toInt() + 25).clamp(0, 255);
          image.setPixelRgb(x, y, r, g, b);
        }
      }
    } else if (p.warm) {
      // Warm: boost red/green, reduce blue
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = (pixel.r.toInt() + 25).clamp(0, 255);
          final g = (pixel.g.toInt() + 10).clamp(0, 255);
          final b = (pixel.b.toInt() - 20).clamp(0, 255);
          image.setPixelRgb(x, y, r, g, b);
        }
      }
    }

    // 2. Brightness
    if (p.brightness != 0) {
      final amount = (p.brightness * 60).round();
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          image.setPixelRgb(
            x, y,
            (pixel.r.toInt() + amount).clamp(0, 255),
            (pixel.g.toInt() + amount).clamp(0, 255),
            (pixel.b.toInt() + amount).clamp(0, 255),
          );
        }
      }
    }

    // 3. Contrast
    if (p.contrast != 1.0) {
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          image.setPixelRgb(
            x, y,
            ((pixel.r.toDouble() - 128) * p.contrast + 128).clamp(0, 255).round(),
            ((pixel.g.toDouble() - 128) * p.contrast + 128).clamp(0, 255).round(),
            ((pixel.b.toDouble() - 128) * p.contrast + 128).clamp(0, 255).round(),
          );
        }
      }
    }

    // 4. Saturation
    if (p.saturation != 1.0 && !p.grayscale && !p.blackWhite && !p.sepia && !p.invert) {
      final s = p.saturation;
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          image.setPixelRgb(
            x, y,
            (lum + s * (r - lum)).clamp(0.0, 255.0).round(),
            (lum + s * (g - lum)).clamp(0.0, 255.0).round(),
            (lum + s * (b - lum)).clamp(0.0, 255.0).round(),
          );
        }
      }
    }

    // 5. Sharpness (simple unsharp mask)
    if (p.sharpness > 0) {
      final blurred = img.gaussianBlur(image, radius: 1);
      final amount = p.sharpness;
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final orig = image.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          image.setPixelRgb(
            x, y,
            (orig.r + (orig.r - blur.r) * amount).clamp(0, 255).round(),
            (orig.g + (orig.g - blur.g) * amount).clamp(0, 255).round(),
            (orig.b + (orig.b - blur.b) * amount).clamp(0, 255).round(),
          );
        }
      }
    }

    final outPath =
        '${Directory.systemTemp.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';
    File(outPath).writeAsBytesSync(img.encodeJpg(image, quality: 95));
    p.sendPort.send({'path': outPath});
  } catch (e) {
    p.sendPort.send({'error': e.toString()});
  }
}

// ─── Preset model ─────────────────────────────────────────────────────────────

class _Preset {
  final String name;
  final IconData icon;
  final Color color;
  final double brightness;
  final double contrast;
  final double saturation;
  final double sharpness;
  final bool grayscale;
  final bool blackWhite;
  final bool sepia;
  final bool invert;
  final bool cool;
  final bool warm;

  const _Preset({
    required this.name,
    required this.icon,
    required this.color,
    this.brightness = 0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.sharpness = 0,
    this.grayscale = false,
    this.blackWhite = false,
    this.sepia = false,
    this.invert = false,
    this.cool = false,
    this.warm = false,
  });
}

const List<_Preset> _kPresets = [
  _Preset(name: 'Original',  icon: Iconsax.image,        color: Color(0xFF888888)),
  _Preset(name: 'Auto',      icon: Iconsax.magic_star,   color: Color(0xFFD4A017), brightness: 0.05, contrast: 1.25, saturation: 1.1, sharpness: 0.3),
  _Preset(name: 'Sharp Doc', icon: Iconsax.scan,         color: Color(0xFF3B82F6), brightness: -0.05, contrast: 1.6, saturation: 0.7, sharpness: 0.8),
  _Preset(name: 'B&W',       icon: Iconsax.record,       color: Color(0xFF555555), blackWhite: true),
  _Preset(name: 'Grayscale', icon: Iconsax.color_swatch, color: Color(0xFF777777), grayscale: true),
  _Preset(name: 'Sepia',     icon: Iconsax.coffee,       color: Color(0xFFA0522D), sepia: true),
  _Preset(name: 'Vivid',     icon: Iconsax.sun_1,        color: Color(0xFFF97316), brightness: 0.05, contrast: 1.3, saturation: 1.8),
  _Preset(name: 'Soft',      icon: Iconsax.cloud,        color: Color(0xFFA855F7), brightness: 0.12, contrast: 0.85, saturation: 0.85),
  _Preset(name: 'Cool',      icon: Iconsax.wind,         color: Color(0xFF06B6D4), cool: true, contrast: 1.05),
  _Preset(name: 'Warm',      icon: Iconsax.sun,          color: Color(0xFFEF4444), warm: true, contrast: 1.05),
  _Preset(name: 'Invert',    icon: Iconsax.repeat,       color: Color(0xFF6366F1), invert: true),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdvancedFiltersScreen extends StatefulWidget {
  final String imagePath;
  const AdvancedFiltersScreen({super.key, required this.imagePath});

  @override
  State<AdvancedFiltersScreen> createState() => _AdvancedFiltersScreenState();
}

class _AdvancedFiltersScreenState extends State<AdvancedFiltersScreen>
    with SingleTickerProviderStateMixin {
  // Values
  double _brightness = 0;
  double _contrast   = 1.0;
  double _saturation = 1.0;
  double _sharpness  = 0;
  bool   _grayscale  = false;
  bool   _blackWhite = false;
  bool   _sepia      = false;
  bool   _invert     = false;
  bool   _cool       = false;
  bool   _warm       = false;

  int     _selectedPreset = 0;
  bool    _isProcessing   = false;
  String? _previewPath;
  String? _errorMsg;
  bool    _showOriginal   = false; // for compare press-and-hold

  DateTime _lastSliderChange = DateTime.now();

  // Tab: 0=Presets, 1=Adjust
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _previewPath = widget.imagePath;
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Filter processing ──────────────────────────────────────────────────────

  Future<void> _updatePreview() async {
    final changeTime = DateTime.now();
    _lastSliderChange = changeTime;
    await Future.delayed(const Duration(milliseconds: 380));
    if (_lastSliderChange != changeTime || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final receivePort = ReceivePort();
      await Isolate.spawn(
        _applyFiltersIsolate,
        _FilterParams(
          inputPath:  widget.imagePath,
          brightness: _brightness,
          contrast:   _contrast,
          saturation: _saturation,
          sharpness:  _sharpness,
          grayscale:  _grayscale,
          blackWhite: _blackWhite,
          sepia:      _sepia,
          invert:     _invert,
          cool:       _cool,
          warm:       _warm,
          sendPort:   receivePort.sendPort,
        ),
      );

      final result = await receivePort.first as Map;
      if (!mounted) return;

      if (result.containsKey('error')) {
        setState(() { _errorMsg = result['error']; _isProcessing = false; });
      } else {
        // Evict old preview from cache
        if (_previewPath != null && _previewPath != widget.imagePath) {
          FileImage(File(_previewPath!)).evict();
        }
        setState(() {
          _previewPath  = result['path'];
          _isProcessing = false;
          _errorMsg     = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMsg = e.toString(); _isProcessing = false; });
    }
  }

  void _applyPreset(_Preset p, int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreset = index;
      _brightness = p.brightness;
      _contrast   = p.contrast;
      _saturation = p.saturation;
      _sharpness  = p.sharpness;
      _grayscale  = p.grayscale;
      _blackWhite = p.blackWhite;
      _sepia      = p.sepia;
      _invert     = p.invert;
      _cool       = p.cool;
      _warm       = p.warm;
    });

    if (index == 0) {
      // Original — no processing needed
      setState(() { _previewPath = widget.imagePath; _errorMsg = null; });
    } else {
      _updatePreview();
    }
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _brightness = 0; _contrast = 1.0; _saturation = 1.0; _sharpness = 0;
      _grayscale = _blackWhite = _sepia = _invert = _cool = _warm = false;
      _selectedPreset = 0;
      _previewPath = widget.imagePath;
      _errorMsg = null;
    });
  }

  Future<void> _saveAndReturn() async {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _previewPath ?? widget.imagePath);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildImagePreview()),
              _buildBottomPanel(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12, MediaQuery.of(context).padding.top + 6, 12, 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          _topBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
          const Spacer(),
          Text(
            'Filters & Adjust',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Reset',
                style: GoogleFonts.nunito(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image preview ──────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    final displayPath = _showOriginal ? widget.imagePath : (_previewPath ?? widget.imagePath);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: Colors.black,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Image.file(
                File(displayPath),
                key: ValueKey(displayPath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
                  const SizedBox(height: 12),
                  Text(
                    'Applying…',
                    style: GoogleFonts.nunito(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        // Compare button (bottom center of preview)
        Positioned(
          bottom: 12,
          child: GestureDetector(
            onLongPressStart: (_) => setState(() => _showOriginal = true),
            onLongPressEnd:   (_) => setState(() => _showOriginal = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.compare_rounded, color: Colors.white60, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    _showOriginal ? 'Original' : 'Hold to compare',
                    style: GoogleFonts.nunito(
                      color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Error
        if (_errorMsg != null)
          Positioned(
            bottom: 52,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMsg!,
                style: GoogleFonts.nunito(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ── Bottom panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.navyDark,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [Tab(text: 'Presets'), Tab(text: 'Adjust')],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: _tabCtrl.index == 0 ? 90 : 148,
            child: AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) => _tabCtrl.index == 0
                  ? _buildPresetsTab()
                  : _buildAdjustTab(),
            ),
          ),

          // Save button
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: GestureDetector(
              onTap: _isProcessing ? null : _saveAndReturn,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 50,
                decoration: BoxDecoration(
                  color: _isProcessing
                      ? AppColors.gold.withOpacity(0.5)
                      : AppColors.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _isProcessing ? 'Processing…' : 'Save & Apply',
                    style: GoogleFonts.nunito(
                      color: AppColors.navyDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Presets tab ────────────────────────────────────────────────────────────

  Widget _buildPresetsTab() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _kPresets.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final p = _kPresets[i];
        final sel = _selectedPreset == i;
        return GestureDetector(
          onTap: () => _applyPreset(p, i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            decoration: BoxDecoration(
              color: sel
                  ? p.color.withOpacity(0.18)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? p.color : Colors.white.withOpacity(0.12),
                width: sel ? 1.8 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(p.icon,
                    color: sel ? p.color : Colors.white38, size: 22),
                const SizedBox(height: 5),
                Text(
                  p.name,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? p.color : Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Adjust tab ─────────────────────────────────────────────────────────────

  Widget _buildAdjustTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _sliderRow(
            label: 'Light',
            icon: Icons.brightness_6_rounded,
            value: _brightness,
            min: -1.0, max: 1.0,
            display: '${(_brightness * 100).round()}',
            onChanged: (v) {
              setState(() {
                _brightness = v; _selectedPreset = -1;
                _grayscale = _blackWhite = _sepia = _invert = _cool = _warm = false;
              });
              _updatePreview();
            },
          ),
          const SizedBox(height: 6),
          _sliderRow(
            label: 'Contrast',
            icon: Icons.contrast_rounded,
            value: _contrast,
            min: 0.5, max: 2.0,
            display: '${((_contrast - 1) * 100).round()}',
            onChanged: (v) {
              setState(() {
                _contrast = v; _selectedPreset = -1;
                _grayscale = _blackWhite = _sepia = _invert = _cool = _warm = false;
              });
              _updatePreview();
            },
          ),
          const SizedBox(height: 6),
          _sliderRow(
            label: 'Color',
            icon: Icons.color_lens_rounded,
            value: _saturation,
            min: 0.0, max: 2.0,
            display: '${((_saturation - 1) * 100).round()}',
            onChanged: (v) {
              setState(() {
                _saturation = v; _selectedPreset = -1;
                _grayscale = _blackWhite = _sepia = _invert = _cool = _warm = false;
              });
              _updatePreview();
            },
          ),
          const SizedBox(height: 6),
          _sliderRow(
            label: 'Sharp',
            icon: Icons.photo_filter_rounded,
            value: _sharpness,
            min: 0.0, max: 2.0,
            display: '${(_sharpness * 100).round()}',
            onChanged: (v) {
              setState(() { _sharpness = v; _selectedPreset = -1; });
              _updatePreview();
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _topBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 6),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: AppColors.gold,
              overlayColor: AppColors.gold.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 2.5,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}