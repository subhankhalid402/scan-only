import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/app_local_storage.dart';

import '../theme.dart';
import '../services/watermark_style_suggester.dart';

/// Result of the watermark composer — pass to [WatermarkService.addTextWatermark].
class WatermarkApplyConfig {
  final String text;
  final int r;
  final int g;
  final int b;
  final int a;

  const WatermarkApplyConfig({
    required this.text,
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });
}

Future<WatermarkApplyConfig?> showWatermarkComposerSheet(
  BuildContext context, {
  required String imagePath,
  String initialText = 'CONFIDENTIAL',
}) {
  return showModalBottomSheet<WatermarkApplyConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0F1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _WatermarkComposerBody(
      imagePath: imagePath,
      initialText: initialText,
    ),
  );
}

class _WatermarkComposerBody extends StatefulWidget {
  final String imagePath;
  final String initialText;

  const _WatermarkComposerBody({
    required this.imagePath,
    required this.initialText,
  });

  @override
  State<_WatermarkComposerBody> createState() => _WatermarkComposerBodyState();
}

class _WatermarkComposerBodyState extends State<_WatermarkComposerBody> {
  late final TextEditingController _textController;
  bool _loading = true;
  double _luminance = 0.65;
  String _insight = '';
  List<WatermarkStylePreset> _presets = [];
  int _selected = 0;
  double _strength = 1.0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    final lum = await WatermarkStyleSuggester.meanLuminance(widget.imagePath);
    final presets = WatermarkStyleSuggester.presetsForLuminance(lum);
    final lastId = AppLocalStorage.getStringOrNull('watermark_last_preset_id');
    var sel = 0;
    if (lastId != null) {
      final i = presets.indexWhere((p) => p.id == lastId);
      if (i >= 0) sel = i;
    }
    final lastStrength =
        AppLocalStorage.getDouble('watermark_last_strength', defaultValue: 1.0);
    if (!mounted) return;
    setState(() {
      _luminance = lum;
      _insight = WatermarkStyleSuggester.insightLine(lum);
      _presets = presets;
      _loading = false;
      _selected = sel;
      _strength = lastStrength.clamp(0.35, 1.0);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  int get _effectiveAlpha {
    if (_presets.isEmpty) return 100;
    final base = _presets[_selected].a;
    return (base * _strength).round().clamp(36, 245);
  }

  Future<void> _apply() async {
    final t = _textController.text.trim();
    if (t.isEmpty) return;
    if (_presets.isEmpty) {
      if (!mounted) return;
      Navigator.pop(
        context,
        WatermarkApplyConfig(text: t, r: 180, g: 180, b: 180, a: 100),
      );
      return;
    }
    final p = _presets[_selected];
    await AppLocalStorage.setString('watermark_last_preset_id', p.id);
    await AppLocalStorage.setDouble('watermark_last_strength', _strength);
    if (!mounted) return;
    Navigator.pop(
      context,
      WatermarkApplyConfig(
        text: t,
        r: p.r,
        g: p.g,
        b: p.b,
        a: _effectiveAlpha,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom + 20;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Watermark & style',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We read your scan and suggest colours that fit your document.',
                style: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Iconsax.lamp_charge,
                          color: AppColors.gold.withValues(alpha: 0.95), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart tip',
                              style: GoogleFonts.nunito(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _insight,
                              style: GoogleFonts.nunito(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Brightness: ${(_luminance * 100).round()}%',
                              style: GoogleFonts.nunito(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quick labels',
                  style: GoogleFonts.nunito(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in [
                      'CONFIDENTIAL',
                      'DRAFT',
                      'DO NOT COPY',
                      'SCAN ONLY',
                      '© ${DateTime.now().year}',
                    ])
                      ActionChip(
                        label: Text(
                          q,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _textController.text = q);
                        },
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _textController,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Watermark text',
                    labelStyle: GoogleFonts.nunito(color: Colors.white54),
                    hintText: 'e.g. CONFIDENTIAL, DRAFT, © Your Name',
                    hintStyle: GoogleFonts.nunito(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Suggested colours',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final p = _presets[i];
                      final sel = i == _selected;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 132,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: sel ? 0.12 : 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? AppColors.gold : Colors.white12,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Color.fromARGB(255, p.r, p.g, p.b),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  p.tip,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Strength',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${(_strength * 100).round()}%',
                      style: GoogleFonts.nunito(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.gold,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.gold,
                    overlayColor: AppColors.gold.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _strength,
                    min: 0.35,
                    max: 1.0,
                    onChanged: (v) => setState(() => _strength = v),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.navyDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Apply watermark',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
