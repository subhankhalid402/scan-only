import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/app_local_storage.dart';
import '../services/cloud_backup_service.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_monitor_service.dart';
import 'scan_screen.dart';
import 'smart_gallery_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'document_viewer_screen.dart';
import 'features_hub_screen.dart';
import 'advanced_sharing_screen.dart';
import 'id_photo_maker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _docsRefreshToken = 0;
  List<DocumentModel> _recentDocs = [];
  void _openTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) _docsRefreshToken++;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadRecentDocs();
    if (AppLocalStorage.getBool('cloudBackupEnabled')) {
      CloudBackupService.instance.syncPendingUploads();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStorageLimitWarning();
    });
  }

  Future<void> _loadRecentDocs() async {
    final docs = await DatabaseService.instance.getRecentDocuments(5);
    if (mounted) {
      setState(() => _recentDocs = docs);
    }
  }

  Future<void> _checkStorageLimitWarning() async {
    final cloudBackupEnabled = AppLocalStorage.getBool('cloudBackupEnabled');
    if (cloudBackupEnabled) return;
    if (!StorageMonitorService.instance.shouldShowWarningNow()) return;

    final usage = await StorageMonitorService.instance.getUsage();
    if (!mounted || !usage.nearLimit) return;

    await StorageMonitorService.instance.markWarningShownNow();
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Storage almost full',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Your local data has reached ${usage.usedMb.toStringAsFixed(0)} MB. '
          'Enable Cloud Backup to help prevent accidental data loss.',
          style: GoogleFonts.nunito(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppLocalStorage.setBool('cloudBackupEnabled', true);
              await CloudBackupService.instance.syncPendingUploads();
              if (!mounted) return;
              _openTab(3); // open settings tab
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cloud backup enabled. Existing documents will upload in the background; '
                      'use Settings → Sync now if you want to check progress.',
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Keep Data Online',
              style: GoogleFonts.nunito(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openScanScreen({String scanType = 'document'}) {
    if (scanType == 'id_maker') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdPhotoMakerScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(scanType: scanType)),
    ).then((_) => _loadRecentDocs());
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedSharingScreen(
          filePath: doc.filePath,
          fileName: doc.name,
        ),
      ),
    );
  }

  Future<void> _renameDocument(DocumentModel doc) async {
    final controller = TextEditingController(text: doc.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rename document',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text(
              'Save',
              style: GoogleFonts.nunito(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty && mounted) {
      await DatabaseService.instance.updateDocument(
        doc.copyWith(
          name: controller.text.trim(),
          modifiedAt: DateTime.now(),
        ),
      );
      _loadRecentDocs();
    }
    controller.dispose();
  }

  bool _isRasterDoc(DocumentModel d) {
    final t = d.fileType.toLowerCase();
    if (t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'webp') return true;
    final dot = d.filePath.lastIndexOf('.');
    if (dot < 0 || dot >= d.filePath.length - 1) return false;
    final ext = d.filePath.substring(dot + 1).toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
  }

  Future<void> _generatePdf(DocumentModel doc) async {
    if (!_isRasterDoc(doc)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Generate PDF is for JPG/PNG scans only.')),
      );
      return;
    }
    if (!await File(doc.filePath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found.')),
      );
      return;
    }
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Generating PDF…',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final saved = await PdfService.instance.createLibraryPdfFromImages(
        [doc.filePath],
        doc.name,
        scanType: doc.scanType,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: ${saved.name}'),
            backgroundColor: AppColors.navyMid,
          ),
        );
        _loadRecentDocs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create PDF.')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          SmartGalleryScreen(
            onRefresh: _loadRecentDocs,
            refreshToken: _docsRefreshToken,
          ),
          const SearchScreen(),
          const SettingsScreen(padsForBottomTabShell: true),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openScanScreen(),
        backgroundColor: AppColors.gold,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Iconsax.camera, color: AppColors.navyDark, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ─── Home Page ────────────────────────────────────────────────────────────

  Widget _buildHomePage() {
    return Column(
      children: [
        _buildHeroSection(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: _buildRecentDocuments(),
          ),
        ),
      ],
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navyDark,
            Color(0xFF0F1E5A),
            AppColors.navyLight,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/launcher_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ScanOnly',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Scan · Extract · Export',
                          style: GoogleFonts.nunito(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold.withValues(alpha: 0.85),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Scan type grid — 2 rows of 5
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 6.0;
                  final tileWidth = (constraints.maxWidth - (spacing * 4)) / 5;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 10,
                    children: [
                      _scanTile(
                        Iconsax.document_text,
                        'Document',
                        'document',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.card,
                        'ID Card',
                        'id_card',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.receipt,
                        'Receipt',
                        'receipt',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.scan_barcode,
                        'QR Code',
                        'qr',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.book,
                        'Book',
                        'book',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.camera,
                        'Photo',
                        'photo',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.user_square,
                        'ID Maker',
                        'id_maker',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.personalcard,
                        'Passport',
                        'passport',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.text_block,
                        'Whiteboard',
                        'whiteboard',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                      _scanTile(
                        Iconsax.element_3,
                        'Table',
                        'table',
                        AppColors.gold,
                        width: tileWidth,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // All Features button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeaturesHubScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'All Features',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _scanTile(
    IconData icon,
    String label,
    String type,
    Color color, {
    double? width,
  }) {
    return GestureDetector(
      onTap: () => _openScanScreen(scanType: type),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recent Documents ─────────────────────────────────────────────────────

  Widget _buildRecentDocuments() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Documents',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              GestureDetector(
                onTap: () => _openTab(1),
                child: Text(
                  'See all',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_recentDocs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.document, size: 64, color: muted.withValues(alpha: 0.35)),
                    const SizedBox(height: 14),
                    Text(
                      'No documents yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: _recentDocs.length,
                itemBuilder: (context, index) {
                  final doc = _recentDocs[index];
                  return _DocCard(
                    doc: doc,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(document: doc),
                        ),
                      );
                      _loadRecentDocs();
                    },
                    onShare: () => _shareDocument(doc),
                    onRename: () => _renameDocument(doc),
                    onGeneratePdf:
                        _isRasterDoc(doc) ? () => _generatePdf(doc) : null,
                    onDelete: () async {
                      await DatabaseService.instance.deleteDocument(doc.id!);
                      _loadRecentDocs();
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.navyDark,
      elevation: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Iconsax.home_2, 'Home'),
            _navItem(1, Iconsax.folder_2, 'Docs'),
            const SizedBox(width: 56),
            _navItem(2, Iconsax.search_normal, 'Search'),
            _navItem(3, Iconsax.setting_2, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _openTab(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? AppColors.gold : Colors.white54,
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.gold : Colors.white54,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Document Card (Home) ─────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback? onGeneratePdf;
  final VoidCallback onDelete;

  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onShare,
    required this.onRename,
    this.onGeneratePdf,
    required this.onDelete,
  });

  Color _chipBg(ColorScheme scheme) {
    return Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.06),
      scheme.surface,
    );
  }

  Color _accentColor() {
    final t = doc.fileType.toLowerCase();
    switch (t) {
      case 'pdf':
        return AppColors.red;
      case 'doc':
      case 'docx':
        return AppColors.blue;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return AppColors.green;
      case 'ppt':
      case 'pptx':
        return AppColors.orange;
      case 'txt':
      case 'json':
      case 'xml':
        return AppColors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return AppColors.navyMid;
      case 'zip':
      case 'rar':
      case '7z':
        return AppColors.gold;
      default:
        return AppColors.navyMid;
    }
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor();
    final scheme = Theme.of(context).colorScheme;
    final titleColor = scheme.onSurface;
    final subtitleColor = scheme.onSurfaceVariant;
    // Whole row is one surface — tap anywhere (except ⋮) opens
    // the document with a ripple. [PopupMenuButton] handles its own tap only.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: Theme.of(context).brightness == Brightness.dark
              ? BorderSide(color: scheme.outline.withValues(alpha: 0.22))
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Iconsax.document_text, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_formatDate(doc.createdAt)} · ${doc.pageCount}p · ${doc.fileType.toUpperCase()}',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _chipBg(scheme),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${doc.fileSizeMB.toStringAsFixed(1)}MB',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: subtitleColor, size: 20),
                  onSelected: (val) {
                    switch (val) {
                      case 'share':
                        onShare();
                        break;
                      case 'rename':
                        onRename();
                        break;
                      case 'pdf':
                        onGeneratePdf?.call();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    if (onGeneratePdf != null)
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Text('Generate PDF'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
