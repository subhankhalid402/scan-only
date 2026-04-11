import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import 'scan_screen.dart';
import 'documents_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'document_viewer_screen.dart';
import 'camscanner_features_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<DocumentModel> _recentDocs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentDocs();
  }

  Future<void> _loadRecentDocs() async {
    final docs = await DatabaseService.instance.getAllDocuments();
    if (mounted) {
      setState(() => _recentDocs = docs.take(5).toList());
    }
  }

  void _openScanScreen({String scanType = 'document'}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(scanType: scanType)),
    ).then((_) => _loadRecentDocs());
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
          DocumentsScreen(onRefresh: _loadRecentDocs),
          const SearchScreen(),
          const SettingsScreen(),
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
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B1740),
            Color(0xFF162460),
            Color(0xFF1E3A8A),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A4BAA), Color(0xFF162460)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Iconsax.scan, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ScanOnly',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Notification bell
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Iconsax.notification, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Scan type grid — 2 rows of 4
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _scanTile(Iconsax.document_text, 'Document',  'document',   AppColors.gold),
                      _scanTile(Iconsax.card,          'ID Card',   'id_card',    const Color(0xFF3B82F6)),
                      _scanTile(Iconsax.receipt,       'Receipt',   'receipt',    const Color(0xFF22C55E)),
                      _scanTile(Iconsax.scan_barcode,  'QR Code',   'qr',         const Color(0xFF6366F1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _scanTile(Iconsax.book,          'Book',       'book',       const Color(0xFFF97316)),
                      _scanTile(Iconsax.camera,        'Photo',      'photo',      const Color(0xFFA855F7)),
                      _scanTile(Iconsax.gallery,       'Gallery',    'gallery',    const Color(0xFFEF4444)),
                      _scanTile(Iconsax.text_block,    'Whiteboard', 'whiteboard', const Color(0xFF06B6D4)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // All Features button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CamScannerFeaturesScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
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
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
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

  Widget _scanTile(IconData icon, String label, String type, Color color) {
    return GestureDetector(
      onTap: () => _openScanScreen(scanType: type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Recent Documents ─────────────────────────────────────────────────────

  Widget _buildRecentDocuments() {
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
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedIndex = 1),
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
                    Icon(Iconsax.document, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 14),
                    Text(
                      'No documents yet\nTap the camera button to scan!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: AppColors.textMuted,
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
      color: Colors.white,
      elevation: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Iconsax.home_2,         'Home'),
            _navItem(1, Iconsax.folder_2,       'Docs'),
            const SizedBox(width: 56),
            _navItem(2, Iconsax.search_normal,  'Search'),
            _navItem(3, Iconsax.setting_2,      'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: isActive ? AppColors.navyMid : const Color(0xFFAAAAAA),
              size: 22),
            const SizedBox(height: 3),
            Text(label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.navyMid : const Color(0xFFAAAAAA),
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
  final VoidCallback onDelete;

  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  Color _accentColor() {
    switch (doc.fileType) {
      case 'pdf':  return const Color(0xFFEF4444);
      case 'jpg':
      case 'jpeg':
      case 'png':  return const Color(0xFF3B82F6);
      case 'docx':
      case 'doc':  return const Color(0xFF22C55E);
      default:     return const Color(0xFF6366F1);
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4, height: 56,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Iconsax.document_text, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_formatDate(doc.createdAt)} · ${doc.pageCount} page${doc.pageCount > 1 ? 's' : ''}',
                          style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${doc.fileSizeMB.toStringAsFixed(1)} MB',
                            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 3-dot menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                onSelected: (val) {
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share',  child: Text('Share')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
