import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_theme_controller.dart';
import '../services/app_local_storage.dart';
import '../services/biometric_service.dart';
import '../services/database_service.dart';
import '../services/document_export_service.dart';
import '../theme.dart';
import 'all_features_screen.dart';
import 'onboarding_screen.dart';

// Scanner-focused settings; toggles are wired to prefs / theme / DB where applicable.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Prefs state ───────────────────────────────────────────────
  bool _autoEnhance = true;
  bool _darkMode = false;
  bool _gridView = false;
  String _defaultFormat = 'PDF';
  String _defaultQuality = 'High';
  String _language = 'English';

  // ── Storage state ─────────────────────────────────────────────
  double _cacheSize = 0; // MB
  double _storageUsed = 0; // MB
  bool _loadingStorage = false;

  bool _prefsLoaded = false;
  bool _biometricLock = false;
  bool _exportingZip = false;

  static const _formats = ['PDF', 'JPG'];

  static String _normalizeFormat(String? v) {
    if (v == 'JPG' || v == 'PDF') return v!;
    return 'PDF';
  }

  static const _qualities = ['Low', 'Medium', 'High', 'Ultra'];
  static const _languages = [
    ('English', '🇬🇧'),
    ('اردو', '🇵🇰'),
    ('العربية', '🇸🇦'),
    ('Français', '🇫🇷'),
    ('Deutsch', '🇩🇪'),
    ('Español', '🇪🇸'),
    ('हिंदी', '🇮🇳'),
    ('中文', '🇨🇳'),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _calculateStorage();
  }

  Future<void> _loadPrefs() async {
    final bio = await BiometricService.instance.isBiometricLockEnabled();
    if (!mounted) return;
    setState(() {
      _autoEnhance = AppLocalStorage.getBool('autoEnhance', defaultValue: true);
      _darkMode = AppLocalStorage.getBool('darkMode');
      _gridView = AppLocalStorage.getBool('gridView');
      _defaultFormat = _normalizeFormat(
          AppLocalStorage.getString('defaultFormat', defaultValue: 'PDF'));
      _defaultQuality =
          AppLocalStorage.getString('defaultQuality', defaultValue: 'High');
      _language =
          AppLocalStorage.getString('language', defaultValue: 'English');
      _biometricLock = bio;
      _prefsLoaded = true;
    });
  }

  Future<void> _exportAllZip() async {
    if (_exportingZip) return;
    setState(() => _exportingZip = true);
    try {
      final path =
          await DocumentExportService.instance.exportAllDocumentsToZipFile();
      if (!mounted) return;
      if (path == null) {
        _showInfo('Nothing to export', 'Add scans first, then try again.');
        return;
      }
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'ScanOnly backup',
        text:
            'Local backup of your ScanOnly library (ZIP is not encrypted—store safely).',
      );
    } catch (e) {
      if (mounted) {
        _showInfo('Export failed', e.toString());
      }
    } finally {
      if (mounted) setState(() => _exportingZip = false);
    }
  }

  // ── Storage helpers ───────────────────────────────────────────

  Future<void> _calculateStorage() async {
    setState(() => _loadingStorage = true);
    try {
      final tmp = await getTemporaryDirectory();
      final docs = await getApplicationDocumentsDirectory();
      _cacheSize = await _dirSize(tmp);
      _storageUsed = await _dirSize(docs);
    } catch (_) {}
    if (mounted) setState(() => _loadingStorage = false);
  }

  Future<double> _dirSize(Directory dir) async {
    double total = 0;
    try {
      await for (final f in dir.list(recursive: true)) {
        if (f is File) total += await f.length();
      }
    } catch (_) {}
    return total / (1024 * 1024); // bytes → MB
  }

  Future<void> _clearCache() async {
    final confirmed = await _confirm(
      title: 'Cache Clear Karein?',
      body:
          '${_cacheSize.toStringAsFixed(1)} MB temporary files delete ho jaayengi.',
      confirmLabel: 'Clear',
      danger: false,
    );
    if (!confirmed) return;

    try {
      final tmp = await getTemporaryDirectory();
      if (await tmp.exists()) {
        await for (final f in tmp.list()) {
          try {
            await f.delete(recursive: true);
          } catch (_) {}
        }
      }
      final freed = _cacheSize;
      await _calculateStorage();
      _showSuccess('${freed.toStringAsFixed(1)} MB cache clear ho gayi!');
    } catch (e) {
      _showError('Cache clear nahi ho saka: $e');
    }
  }

  Future<void> _clearAllDocuments() async {
    final confirmed = await _confirm(
      title: 'Sare Documents Delete Karein?',
      body:
          'Yeh action undo nahi ho sakta. Library se sare scans aur database entries delete ho jaayengi.',
      confirmLabel: 'Delete Karein',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await DatabaseService.instance.deleteAllDocumentsWithFiles();
      await _calculateStorage();
      _showSuccess('Sare documents delete ho gaye.');
    } catch (e) {
      _showError('Delete nahi ho saka: $e');
    }
  }

  // ── Language sheet ────────────────────────────────────────────

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Zaban Chunein',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          ..._languages.map((l) => ListTile(
                leading: Text(l.$2, style: const TextStyle(fontSize: 22)),
                title: Text(l.$1,
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: _language == l.$1
                    ? Icon(Iconsax.tick_circle,
                        color: AppColors.navyDark, size: 20)
                    : null,
                onTap: () async {
                  setState(() => _language = l.$1);
                  await AppLocalStorage.setString('language', _language);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSuccess(
                    'Zaban save ho gayi. Poori app ke liye app ek dafa band karke kholein.',
                  );
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Confirm dialog ────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required bool danger,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(body, style: GoogleFonts.nunito(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(
                    color: AppColors.navyDark, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: GoogleFonts.nunito(
                    color: danger ? AppColors.red : AppColors.navyDark,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Snackbars ─────────────────────────────────────────────────

  void _showSuccess(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.nunito()),
        backgroundColor: AppColors.navyMid,
        behavior: SnackBarBehavior.floating,
      ));

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.nunito()),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Show shimmer/loading until prefs are ready
    if (!_prefsLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        body: Column(
          children: [
            _buildHeader(),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
              children: [
                // ── 1. Scan Settings ──────────────────────────
                _sectionLabel('Scan Settings', Iconsax.camera, AppColors.gold),
                _navTile(
                  icon: Iconsax.element_4,
                  color: AppColors.gold,
                  title: 'All tools & features',
                  subtitle: 'Tools hub — scan, OCR, PDF, share',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllFeaturesScreen(),
                    ),
                  ),
                ),
                _toggleTile(
                  icon: Iconsax.magic_star,
                  color: AppColors.gold,
                  title: 'Auto Enhance',
                  subtitle: 'Scan quality automatically improve karein',
                  value: _autoEnhance,
                  onChanged: (v) {
                    setState(() => _autoEnhance = v);
                    AppLocalStorage.setBool('autoEnhance', v);
                  },
                ),
                _toggleTile(
                  icon: Iconsax.element_3,
                  color: AppColors.blue,
                  title: 'Grid View',
                  subtitle: 'Documents grid mein dikhao',
                  value: _gridView,
                  onChanged: (v) {
                    setState(() => _gridView = v);
                    AppLocalStorage.setBool('gridView', v);
                  },
                ),
                _pickerTile(
                  icon: Iconsax.document_text,
                  color: AppColors.navyMid,
                  title: 'Default Format',
                  subtitle: 'Save format select karein',
                  value: _defaultFormat,
                  options: _formats,
                  onChanged: (v) {
                    setState(() => _defaultFormat = v);
                    AppLocalStorage.setString('defaultFormat', v);
                  },
                ),
                _pickerTile(
                  icon: Iconsax.setting_4,
                  color: AppColors.navyMid,
                  title: 'Scan Quality',
                  subtitle: 'Scan resolution',
                  value: _defaultQuality,
                  options: _qualities,
                  onChanged: (v) {
                    setState(() => _defaultQuality = v);
                    AppLocalStorage.setString('defaultQuality', v);
                  },
                ),

                const SizedBox(height: 14),

                // ── Privacy & security (on-device value) ─────
                _sectionLabel('Privacy & security', Iconsax.shield_tick,
                    AppColors.navyMid),
                _privacyHighlightsCard(),
                _toggleTile(
                  icon: Iconsax.lock,
                  color: AppColors.navyMid,
                  title: 'Lock when leaving app',
                  subtitle:
                      'Face / fingerprint when returning from home or another app',
                  value: _biometricLock,
                  onChanged: (v) async {
                    if (v) {
                      final can =
                          await BiometricService.instance.canUseBiometrics();
                      if (!can) {
                        if (!mounted) return;
                        _showInfo(
                          'Biometrics unavailable',
                          'Add a fingerprint or face unlock in system settings first.',
                        );
                        return;
                      }
                      final ok = await BiometricService.instance.authenticate();
                      if (!ok) return;
                      await BiometricService.instance.enableBiometricLock();
                      if (mounted) setState(() => _biometricLock = true);
                    } else {
                      await BiometricService.instance.disableBiometricLock();
                      if (mounted) setState(() => _biometricLock = false);
                    }
                  },
                ),
                _actionTile(
                  icon: Iconsax.document_upload,
                  color: AppColors.gold,
                  title: _exportingZip
                      ? 'Creating backup…'
                      : 'Export all documents (ZIP)',
                  subtitle:
                      'On-device backup file. ZIP is not encrypted—keep it private.',
                  onTap: _exportingZip ? () {} : _exportAllZip,
                ),
                _navTile(
                  icon: Iconsax.flash_1,
                  color: AppColors.gold,
                  title: 'Why ScanOnly?',
                  subtitle:
                      'Focused on fast local scanning—not a fax & cloud suite.',
                  onTap: () => _showInfo(
                    'Why ScanOnly?',
                    'We keep the core loop fast: scan → enhance → one PDF on your phone. '
                        'No account is required for saving. OCR and search run on-device. '
                        'We skip bulky corporate extras so the app stays light and respectful of your time.',
                  ),
                ),

                const SizedBox(height: 14),

                // ── 2. Storage ────────────────────────────────
                _sectionLabel('Storage', Iconsax.folder_2, AppColors.gold),
                _storageTile(),
                _actionTile(
                  icon: Iconsax.broom,
                  color: AppColors.gold,
                  title: 'Clear Cache',
                  subtitle: _loadingStorage
                      ? 'Calculating…'
                      : '${_cacheSize.toStringAsFixed(1)} MB temporary files',
                  onTap: _clearCache,
                ),
                _actionTile(
                  icon: Iconsax.trash,
                  color: AppColors.red,
                  title: 'Clear All Documents',
                  subtitle: 'Sare saved documents delete karein',
                  onTap: _clearAllDocuments,
                  isDanger: true,
                ),

                const SizedBox(height: 14),

                // ── 3. Appearance ─────────────────────────────
                _sectionLabel('Appearance', Iconsax.brush_2, AppColors.navyMid),
                _toggleTile(
                  icon: _darkMode ? Iconsax.moon : Iconsax.sun_1,
                  color: AppColors.navyDark,
                  title: 'Dark Mode',
                  subtitle:
                      _darkMode ? 'Dark theme on hai' : 'Light theme on hai',
                  value: _darkMode,
                  onChanged: (v) {
                    setState(() => _darkMode = v);
                    AppLocalStorage.setBool('darkMode', v);
                    AppThemeController.setDarkMode(v);
                  },
                ),
                _navTile(
                  icon: Iconsax.language_circle,
                  color: AppColors.blue,
                  title: 'Language',
                  subtitle: _language,
                  onTap: _showLanguageSheet,
                ),

                const SizedBox(height: 14),

                // ── 4. About ──────────────────────────────────
                _sectionLabel('About', Iconsax.info_circle, AppColors.navyMid),
                _navTile(
                  icon: Iconsax.book,
                  color: AppColors.gold,
                  title: 'Show intro again',
                  subtitle: 'Replay the first-launch tour',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const OnboardingScreen(
                          replaceRootOnFinish: false,
                        ),
                      ),
                    );
                  },
                ),
                _navTile(
                  icon: Iconsax.mobile,
                  color: AppColors.navyMid,
                  title: 'App Version',
                  subtitle: 'v1.0.0 (Build 1)',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'ScanOnly',
                    applicationVersion: '1.0.0+1',
                    applicationIcon: const Icon(Iconsax.scan,
                        color: AppColors.navyMid, size: 40),
                    children: [
                      Text(
                        'ScanOnly: fast local scanning, one-tap PDFs, and optional biometric lock. '
                        'We stay focused—no fax cloud suite.',
                        style: GoogleFonts.nunito(fontSize: 13, height: 1.45),
                      ),
                    ],
                  ),
                ),
                _navTile(
                  icon: Iconsax.shield,
                  color: AppColors.blue,
                  title: 'Privacy Policy',
                  subtitle: 'Data handling policy',
                  onTap: () => _showInfo('Privacy Policy',
                      'Aapka data sirf aapke device pe rehta hai. Koi server pe upload nahi hota.'),
                ),
                _navTile(
                  icon: Iconsax.document_text,
                  color: AppColors.navyMid,
                  title: 'Terms of Use',
                  subtitle: 'Usage terms',
                  onTap: () => _showInfo('Terms of Use',
                      'Personal aur commercial use ke liye free. Redistribution allowed nahi.'),
                ),

                const SizedBox(height: 16),

                // ── App badge ─────────────────────────────────
                _buildAppBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navyDark, AppColors.navyMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Text('Settings',
                    style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const Spacer(),
                Icon(
                  Iconsax.setting_2,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _privacyHighlightsCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On-device by default',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 8),
            _privacyBullet('Scans & PDFs stay on this phone unless you share.'),
            _privacyBullet('No account needed to save or search your library.'),
            _privacyBullet(
                'OCR runs locally so you can find text inside scans.'),
          ],
        ),
      );

  Widget _privacyBullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Iconsax.tick_circle, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────

  Widget _sectionLabel(String title, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark.withValues(alpha: 0.7),
                    letterSpacing: 0.3)),
          ],
        ),
      );

  // ── Toggle tile ───────────────────────────────────────────────

  Widget _toggleTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) =>
      _tile(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.gold,
          activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  // ── Picker tile (segmented chips sheet) ──────────────────────

  Widget _pickerTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required void Function(String) onChanged,
  }) =>
      _tile(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: () => _showPickerSheet(title, options, value, onChanged),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      );

  // ── Action tile (clear cache etc.) ────────────────────────────

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) =>
      _tile(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing: Icon(
          Iconsax.arrow_right_3,
          size: 16,
          color: isDanger
              ? AppColors.red.withValues(alpha: 0.5)
              : Colors.grey[350],
        ),
        titleColor: isDanger ? AppColors.red : null,
      );

  // ── Nav tile ──────────────────────────────────────────────────

  Widget _navTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      _tile(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing:
            Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey[350]),
      );

  // ── Base tile ─────────────────────────────────────────────────

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.navyDark.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: titleColor ?? AppColors.textDark)),
                    Text(subtitle,
                        style: GoogleFonts.nunito(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      );

  // ── Storage bar tile ──────────────────────────────────────────

  Widget _storageTile() {
    final used = _storageUsed;
    const total = 100.0; // mock total in MB — replace with real device storage
    final pct = (used / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.navyDark.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.navyMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Iconsax.chart_square,
                    color: AppColors.navyMid, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Documents Storage',
                        style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    Text(
                      _loadingStorage
                          ? 'Calculating…'
                          : '${used.toStringAsFixed(1)} MB used',
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _loadingStorage ? null : pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                pct > 0.8 ? AppColors.red : AppColors.navyMid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Picker sheet ──────────────────────────────────────────────

  void _showPickerSheet(String title, List<String> options, String current,
      void Function(String) onChanged) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(title,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          ...options.map((o) => ListTile(
                title: Text(o,
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: current == o
                    ? Icon(Iconsax.tick_circle,
                        color: AppColors.navyDark, size: 20)
                    : null,
                onTap: () {
                  onChanged(o);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Info dialog ───────────────────────────────────────────────

  void _showInfo(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title:
            Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content:
            Text(body, style: GoogleFonts.nunito(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: AppColors.navyDark)),
          ),
        ],
      ),
    );
  }

  // ── App badge ─────────────────────────────────────────────────

  Widget _buildAppBadge() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.navyDark.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.navyDark.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: AppColors.navyMid,
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Iconsax.scan, color: AppColors.gold, size: 30),
            ),
            const SizedBox(height: 10),
            Text('ScanOnly',
                style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark)),
            Text('Free • Offline • Private',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('v1.0.0 (Build 1)',
                style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
}
