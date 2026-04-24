import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import '../services/share_file_service.dart';
import '../app_theme_controller.dart';
import '../services/app_local_storage.dart';
import '../services/biometric_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/database_service.dart';
import '../services/document_export_service.dart';
import '../services/storage_monitor_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'all_features_screen.dart';
import 'onboarding_screen.dart';

// Scanner-focused settings; toggles are wired to prefs / theme / DB where applicable.

class SettingsScreen extends StatefulWidget {
  /// When true (home tab), add bottom padding so the list does not sit under the shell [BottomAppBar].
  final bool padsForBottomTabShell;

  const SettingsScreen({super.key, this.padsForBottomTabShell = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Prefs state ───────────────────────────────────────────────
  bool _autoEnhance = true;
  bool _darkMode = false;
  bool _followSystemTheme = false;
  bool _gridView = false;
  String _defaultQuality = 'High';

  // ── Storage state ─────────────────────────────────────────────
  double _cacheSize = 0; // MB
  double _storageUsed = 0; // MB
  bool _loadingStorage = false;

  bool _prefsLoaded = false;
  bool _biometricLock = false;
  bool _exportingZip = false;
  bool _syncingNow = false;
  bool _cloudBackupEnabled = false;
  double _localWarningLimitMb = 600;

  static const _qualities = ['Low', 'Medium', 'High', 'Ultra'];

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
      _followSystemTheme =
          AppLocalStorage.getBool(AppThemeController.themeFollowSystemKey);
      _gridView = AppLocalStorage.getBool('gridView');
      _defaultQuality =
          AppLocalStorage.getString('defaultQuality', defaultValue: 'High');
      _biometricLock = bio;
      _cloudBackupEnabled = AppLocalStorage.getBool('cloudBackupEnabled');
      _localWarningLimitMb = StorageMonitorService.instance.warningLimitMb;
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
      await ShareFileService.sharePaths(
        [path],
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
      title: 'Clear Cache?',
      body:
          '${_cacheSize.toStringAsFixed(1)} MB of temporary files will be deleted.',
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
      _showSuccess('${freed.toStringAsFixed(1)} MB cache was cleared.');
    } catch (e) {
      _showError('Could not clear cache: $e');
    }
  }

  Future<void> _clearAllDocuments() async {
    final confirmed = await _confirm(
      title: 'Delete All Documents?',
      body:
          'This action cannot be undone. All scans and library records will be permanently deleted.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await DatabaseService.instance.deleteAllDocumentsWithFiles();
      await _calculateStorage();
      _showSuccess('All documents were deleted.');
    } catch (e) {
      _showError('Could not delete documents: $e');
    }
  }

  void _showLegalSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Iconsax.shield, color: AppColors.blue),
              title: Text('Privacy Policy',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _showInfo(
                  'Privacy Policy',
                  'Your data stays on this device. Nothing is uploaded to '
                      'external servers unless you turn on optional cloud backup.',
                );
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.document_text,
                  color: AppColors.navyMid),
              title: Text('Terms of Use',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _showInfo(
                  'Terms of Use',
                  'Free for personal and commercial use. Redistribution of the '
                      'app package is not allowed.',
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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

  /// Must match [HomeScreen] `_buildBottomNav` child height (62) + breathing room above the bar.
  double _homeTabShellBottomInset(BuildContext context) {
    const double bottomAppBarHeight = 62;
    const double gapAboveBar = 20;
    return bottomAppBarHeight +
        MediaQuery.of(context).viewPadding.bottom +
        gapAboveBar;
  }

  double _listBottomPadding(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding.bottom;
    if (!widget.padsForBottomTabShell) {
      return 22 + safe;
    }
    return _homeTabShellBottomInset(context);
  }

  @override
  Widget build(BuildContext context) {
    // Show shimmer/loading until prefs are ready
    if (!_prefsLoaded) {
      return Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            const Expanded(child: Center(child: CircularProgressIndicator())),
            SizedBox(
                height: widget.padsForBottomTabShell
                    ? _homeTabShellBottomInset(context)
                    : 0),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                _listBottomPadding(context),
              ),
              children: [
                _sectionLabel('Scanning', Iconsax.camera, AppColors.gold),
                _navTile(
                  icon: Iconsax.element_4,
                  color: AppColors.gold,
                  title: 'Tools & features',
                  subtitle: 'OCR, PDF, signatures, and more',
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
                  title: 'Auto enhance',
                  subtitle: 'Improve scans after capture',
                  value: _autoEnhance,
                  onChanged: (v) {
                    setState(() => _autoEnhance = v);
                    AppLocalStorage.setBool('autoEnhance', v);
                  },
                ),
                _toggleTile(
                  icon: Iconsax.element_3,
                  color: AppColors.blue,
                  title: 'Grid view',
                  subtitle: 'Layout in Docs tab (grid vs list)',
                  value: _gridView,
                  onChanged: (v) {
                    setState(() => _gridView = v);
                    AppLocalStorage.setBool('gridView', v);
                  },
                ),
                _pickerTile(
                  icon: Iconsax.setting_4,
                  color: AppColors.navyMid,
                  title: 'Default scan quality',
                  subtitle: 'Used when you open the camera scanner',
                  value: _defaultQuality,
                  options: _qualities,
                  onChanged: (v) {
                    setState(() => _defaultQuality = v);
                    AppLocalStorage.setString('defaultQuality', v);
                  },
                ),
                const SizedBox(height: 14),
                _sectionLabel('Cloud backup', Iconsax.cloud, AppColors.blue),
                _toggleTile(
                  icon: Iconsax.cloud,
                  color: AppColors.blue,
                  title: 'Cloud backup',
                  subtitle: SupabaseService.isAvailable
                      ? 'Upload after each local save (Supabase)'
                      : 'Supabase unavailable (check internet or project)',
                  value: _cloudBackupEnabled && SupabaseService.isAvailable,
                  onChanged: SupabaseService.isAvailable
                      ? (v) {
                          setState(() => _cloudBackupEnabled = v);
                          Future(() async {
                            await AppLocalStorage.setBool(
                                'cloudBackupEnabled', v);
                            if (v) {
                              await CloudBackupService.instance
                                  .syncPendingUploads();
                            }
                          });
                        }
                      : (_) {
                          _showInfo(
                            'Supabase unavailable',
                            'The app could not reach Supabase at startup. '
                                'Check your connection, then restart the app. '
                                'If you changed projects, update lib/config/supabase_app_config.dart.',
                          );
                        },
                ),
                _actionTile(
                  icon: Iconsax.refresh_circle,
                  color: AppColors.navyMid,
                  title: _syncingNow ? 'Syncing…' : 'Sync now',
                  subtitle: SupabaseService.isAvailable
                      ? 'Upload queued files'
                      : 'Supabase required',
                  onTap: _syncingNow ? () {} : _syncNow,
                ),
                const SizedBox(height: 14),
                _sectionLabel(
                    'Privacy & data', Iconsax.shield_tick, AppColors.navyMid),
                _toggleTile(
                  icon: Iconsax.lock,
                  color: AppColors.navyMid,
                  title: 'Lock when leaving app',
                  subtitle: 'Face or fingerprint when you return',
                  value: _biometricLock,
                  onChanged: (v) async {
                    if (v) {
                      final can =
                          await BiometricService.instance.canUseBiometrics();
                      if (!can) {
                        if (!mounted) return;
                        _showInfo(
                          'Biometrics unavailable',
                          'Add fingerprint or face unlock in system settings first.',
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
                      : 'Export library (ZIP)',
                  subtitle: 'Not encrypted—keep the file private',
                  onTap: _exportingZip ? () {} : _exportAllZip,
                ),
                const SizedBox(height: 14),
                _sectionLabel('Storage', Iconsax.folder_2, AppColors.gold),
                _storageTile(),
                _tile(
                  icon: Iconsax.notification,
                  color: AppColors.orange,
                  title: 'Storage warning',
                  subtitle:
                      'Alert near ${_localWarningLimitMb.toStringAsFixed(0)} MB',
                  trailing: SizedBox(
                    width: 170,
                    child: Slider(
                      value: _localWarningLimitMb,
                      min: 200,
                      max: 2000,
                      divisions: 18,
                      label: '${_localWarningLimitMb.toStringAsFixed(0)} MB',
                      onChanged: (v) async {
                        setState(() => _localWarningLimitMb = v);
                        await StorageMonitorService.instance
                            .setWarningLimitMb(v);
                      },
                    ),
                  ),
                ),
                _actionTile(
                  icon: Iconsax.broom,
                  color: AppColors.gold,
                  title: 'Clear cache',
                  subtitle: _loadingStorage
                      ? 'Calculating…'
                      : '${_cacheSize.toStringAsFixed(1)} MB temp files',
                  onTap: _clearCache,
                ),
                _actionTile(
                  icon: Iconsax.trash,
                  color: AppColors.red,
                  title: 'Delete all documents',
                  subtitle: 'Remove every scan from this device',
                  onTap: _clearAllDocuments,
                  isDanger: true,
                ),
                const SizedBox(height: 14),
                _sectionLabel('App', Iconsax.brush_2, AppColors.navyMid),
                _toggleTile(
                  icon: Iconsax.mobile,
                  color: AppColors.navyMid,
                  title: 'Use device theme',
                  subtitle: _followSystemTheme
                      ? 'Matches Android light / dark setting'
                      : 'Turn off to choose light or dark manually',
                  value: _followSystemTheme,
                  onChanged: (v) {
                    setState(() => _followSystemTheme = v);
                    AppThemeController.setFollowSystemTheme(v);
                  },
                ),
                _toggleTile(
                  icon: _darkMode ? Iconsax.moon : Iconsax.sun_1,
                  color: AppColors.navyDark,
                  title: 'Dark mode',
                  subtitle: _followSystemTheme
                      ? 'Saved for when device theme is off'
                      : (_darkMode ? 'Dark theme on' : 'Light theme on'),
                  value: _darkMode,
                  onChanged: _followSystemTheme
                      ? null
                      : (v) {
                          setState(() => _darkMode = v);
                          AppThemeController.setDarkMode(v);
                        },
                ),
                _navTile(
                  icon: Iconsax.book,
                  color: AppColors.gold,
                  title: 'Show intro again',
                  subtitle: 'First-launch tour',
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
                  title: 'About ScanOnly',
                  subtitle: 'Version 1.0.0+1',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'ScanOnly',
                    applicationVersion: '1.0.0+1',
                    applicationIcon: const Icon(Iconsax.scan,
                        color: AppColors.navyMid, size: 40),
                    children: [
                      Text(
                        'Fast local scanning and PDFs. Optional biometric lock. '
                        'Optional Supabase backup if you configure it at build time.',
                        style: GoogleFonts.nunito(fontSize: 13, height: 1.45),
                      ),
                    ],
                  ),
                ),
                _navTile(
                  icon: Iconsax.shield,
                  color: AppColors.blue,
                  title: 'Privacy & terms',
                  subtitle: 'Policy and usage',
                  onTap: _showLegalSheet,
                ),
                const SizedBox(height: 12),
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
            colors: [AppColors.navyDark, Color(0xFF0F1E5A), AppColors.navyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Iconsax.setting_2, color: AppColors.gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings',
                          style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                      Text('Preferences & configuration',
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            Expanded(
              child: Text(title,
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyDark,
                      letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis),
            ),
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
    ValueChanged<bool>? onChanged,
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.navyMid.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Iconsax.folder_2, color: AppColors.navyMid, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App documents folder',
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                Text(
                  _loadingStorage
                      ? 'Calculating…'
                      : 'About ${used.toStringAsFixed(1)} MB (scans & saved files)',
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
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
      isScrollControlled: true,
      useSafeArea: true,
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

  Future<void> _syncNow() async {
    if (_syncingNow) return;
    if (!_cloudBackupEnabled) {
      _showInfo(
        'Cloud backup is off',
        'Enable Cloud Backup toggle first.',
      );
      return;
    }
    setState(() => _syncingNow = true);
    try {
      final result = await CloudBackupService.instance.syncPendingUploads();
      if (!mounted) return;
      if (result.uploaded > 0 || result.failed > 0) {
        _showSuccess(
          'Sync done: ${result.uploaded} uploaded, ${result.failed} failed.',
        );
        return;
      }
      if (result.pendingUploadCount > 0) {
        final detail = result.diagnostic?.trim();
        _showInfo(
          'Upload not finished',
          '${result.pendingUploadCount} document(s) are queued but the app did not upload them in this run.\n\n'
              '${detail != null && detail.isNotEmpty ? '$detail\n\n' : ''}'
              'Also confirm in Supabase:\n'
              '• Storage → bucket name exactly: scan-only (not scan-onlu)\n'
              '• Authentication → Providers → Anonymous → enabled\n'
              '• Storage policies allow insert for that bucket\n\n'
              'Then tap Sync now again.',
        );
        return;
      }
      if (result.newlyQueuedCount > 0) {
        _showInfo(
          'Documents queued',
          '${result.newlyQueuedCount} older document(s) were marked for upload. '
              'Tap Sync now again after the connection is stable.',
        );
        return;
      }
      final by = await DatabaseService.instance.countDocumentsBySyncStatus();
      final total = by.values.fold<int>(0, (s, n) => s + n);
      final synced = by['synced'] ?? 0;
      final local = by['local_only'] ?? 0;
      final queued = by['queued_for_upload'] ?? 0;
      final uploadFailed = by['upload_failed'] ?? 0;
      final breakdown = by.entries.map((e) => '${e.key}: ${e.value}').join(', ');

      String body;
      if (total == 0) {
        body =
            'There are no saved documents in this app yet. Scan or import from the Home tab first.';
      } else if (queued == 0 &&
          local == 0 &&
          uploadFailed == 0 &&
          synced == total) {
        body =
            'All $synced saved item(s) are already marked synced — the app is not holding anything back to upload. '
            'Check Supabase → Storage (bucket scan-only) and Table Editor → cloud_documents if you still do not see them online.';
      } else {
        body =
            'Nothing was queued this sync (saved documents: $total — $breakdown). '
            'If a scan shows here but never uploads, the original file may have been deleted from the phone; '
            'try opening it on the Docs tab — if it errors, re-scan or re-import.';
      }
      _showInfo('Nothing to sync', body);
    } finally {
      if (mounted) setState(() => _syncingNow = false);
    }
  }

}
