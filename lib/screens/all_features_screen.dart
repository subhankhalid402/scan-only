import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import 'scan_screen.dart';
import 'document_viewer_screen.dart';
import 'advanced_filters_screen.dart';
import 'templates_screen.dart';
import 'annotation_screen.dart';
import 'advanced_sharing_screen.dart';
import 'id_photo_maker_screen.dart';
import 'text_extraction_screen.dart';
import 'document_conversion_screen.dart';
import 'import_documents_screen.dart';
import 'search_screen.dart';
import 'documents_screen.dart';
import 'edit_scan_screen.dart';
import 'signature_pad_screen.dart';
import 'manual_erase_screen.dart';
import 'merge_pdfs_screen.dart';
import 'office_export_hub_screen.dart';

// ══════════════════════════════════════════════════════════════
//  AllFeaturesScreen  -  category + feature grid layout
//  • Vertical scrolling through sections
//  • Each section uses a compact and readable grid
//  • Keep all core tools visible without deep nesting
// ══════════════════════════════════════════════════════════════

class AllFeaturesScreen extends StatelessWidget {
  final String? imagePath;
  final DocumentModel? document;

  const AllFeaturesScreen({super.key, this.imagePath, this.document});

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: Text(
          'All Features',
          style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        // ── Quick-access search button ──────────────────────────
        actions: [
          IconButton(
            icon: const Icon(Iconsax.search_normal, size: 22),
            tooltip: 'Search',
            onPressed: () => _go(context, const SearchScreen()),
          ),
        ],
      ),

      // ── Body: vertical list of category sections ────────────
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: sections.length,
        itemBuilder: (_, i) => _CategorySection(section: sections[i]),
      ),
    );
  }

  // ── Build all category sections ──────────────────────────────────────────

  List<_Section> _buildSections(BuildContext context) => [
        // ── 1. SCANNING ──────────────────────────────────────────────────────
        _Section(
          title: 'Scanning',
          icon: Iconsax.camera,
          color: AppColors.gold,
          items: [
            _item(
              icon: Iconsax.camera,
              title: 'Document',
              subtitle: 'Camera scanner',
              color: AppColors.gold,
              onTap: () => _go(context, const ScanScreen(scanType: 'document')),
            ),
            _item(
              icon: Iconsax.card,
              title: 'ID Card',
              subtitle: 'ID & license',
              color: const Color(0xFF3B82F6),
              onTap: () => _go(context, const ScanScreen(scanType: 'id_card')),
            ),
            _item(
              icon: Iconsax.personalcard,
              title: 'Passport',
              subtitle: 'Passport scanner',
              color: const Color(0xFFF43F5E),
              onTap: () => _go(context, const ScanScreen(scanType: 'passport')),
            ),
            _item(
              icon: Iconsax.receipt,
              title: 'Receipt',
              subtitle: 'Bills & receipts',
              color: const Color(0xFF22C55E),
              onTap: () => _go(context, const ScanScreen(scanType: 'receipt')),
            ),
            _item(
              icon: Iconsax.scan_barcode,
              title: 'QR / Barcode',
              subtitle: 'Scan codes',
              color: const Color(0xFF6366F1),
              onTap: () => _go(context, const ScanScreen(scanType: 'qr')),
            ),
            _item(
              icon: Iconsax.book,
              title: 'Book',
              subtitle: 'Two-page scan',
              color: const Color(0xFFF97316),
              onTap: () => _go(context, const ScanScreen(scanType: 'book')),
            ),
            _item(
              icon: Iconsax.text_block,
              title: 'Whiteboard',
              subtitle: 'Capture board',
              color: const Color(0xFF06B6D4),
              onTap: () =>
                  _go(context, const ScanScreen(scanType: 'whiteboard')),
            ),
            _item(
              icon: Iconsax.element_3,
              title: 'Table',
              subtitle: 'Spreadsheets',
              color: const Color(0xFF84CC16),
              onTap: () => _go(context, const ScanScreen(scanType: 'table')),
            ),
          ],
        ),

        // ── 2. EDITING ───────────────────────────────────────────────────────
        _Section(
          title: 'Editing',
          icon: Iconsax.magicpen,
          color: AppColors.purple,
          items: [
            _item(
              icon: Iconsax.magicpen,
              title: 'Auto Enhance',
              subtitle: 'Improve quality',
              color: AppColors.gold,
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, AdvancedFiltersScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.setting_2,
              title: 'Filters',
              subtitle: 'Brightness, contrast',
              color: AppColors.blue,
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, AdvancedFiltersScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.crop,
              title: 'Crop',
              subtitle: 'Crop & adjust',
              color: AppColors.purple,
              onTap: () => _withImageForEdit(context),
            ),
            _item(
              icon: Iconsax.rotate_left,
              title: 'Rotate',
              subtitle: '90° / 180°',
              color: AppColors.blue,
              onTap: () => _withImageForEdit(context),
            ),
            _item(
              icon: Iconsax.shield_tick,
              title: 'Watermark',
              subtitle: 'Add watermark',
              color: AppColors.orange,
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
            _item(
              icon: Iconsax.pen_add,
              title: 'Annotate',
              subtitle: 'Draw & mark',
              color: AppColors.blue,
              onTap: () => _withImage(context,
                  (path) => _go(context, AnnotationScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.clock,
              title: 'Timestamp',
              subtitle: 'Date & time',
              color: AppColors.navyMid,
              onTap: () => _withImageForEdit(context),
            ),
            _item(
              icon: Iconsax.eraser,
              title: 'Smart erase',
              subtitle: 'Remove area',
              color: AppColors.red,
              onTap: () => _withImage(context,
                  (path) => _go(context, ManualEraseScreen(imagePath: path))),
            ),
          ],
        ),

        // ── 3. AI / OCR ──────────────────────────────────────────────────────
        _Section(
          title: 'AI & OCR',
          icon: Iconsax.cpu,
          color: const Color(0xFF6366F1),
          items: [
            _item(
              icon: Iconsax.text,
              title: 'Extract Text',
              subtitle: 'OCR — copy text',
              color: AppColors.purple,
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, TextExtractionScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.translate,
              title: 'Translate',
              subtitle: 'Translate text',
              color: AppColors.orange,
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, TextExtractionScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.scan_barcode,
              title: 'Barcode',
              subtitle: 'Advanced reader',
              color: AppColors.green,
              onTap: () => _go(context, const ScanScreen(scanType: 'qr')),
            ),
          ],
        ),

        // ── 4. DOCUMENTS ─────────────────────────────────────────────────────
        _Section(
          title: 'Documents',
          icon: Iconsax.folder_open,
          color: AppColors.navyMid,
          items: [
            _item(
              icon: Iconsax.folder_open,
              title: 'My Files',
              subtitle: 'All documents',
              color: AppColors.navyMid,
              onTap: () => _go(context, const DocumentsScreen()),
            ),
            _item(
              icon: Iconsax.import_2,
              title: 'Import',
              subtitle: 'From device',
              color: AppColors.blue,
              onTap: () => _go(context, const ImportDocumentsScreen()),
            ),
            _item(
              icon: Iconsax.document,
              title: 'Templates',
              subtitle: 'Pre-made formats',
              color: AppColors.green,
              onTap: () => _go(context, const TemplatesScreen()),
            ),
            _item(
              icon: Iconsax.convert_3d_cube,
              title: 'Convert PDF',
              subtitle: 'To Word, Excel…',
              color: AppColors.red,
              onTap: () => _withDoc(
                  context,
                  (doc) => _go(context,
                      DocumentConversionScreen(filePath: doc.filePath))),
            ),
            _item(
              icon: Iconsax.document_upload,
              title: 'Office Export',
              subtitle: 'Excel, Word, PPT, Slides',
              color: AppColors.purple,
              onTap: () => _go(context, const OfficeExportHubScreen()),
            ),
            _item(
              icon: Icons.compress_rounded,
              title: 'Compress PDF',
              subtitle: 'Reduce PDF file size',
              color: AppColors.navyMid,
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
            _item(
              icon: Iconsax.document_download,
              title: 'Export',
              subtitle: 'Save as PDF',
              color: AppColors.gold,
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
            _item(
              icon: Iconsax.document_copy,
              title: 'Merge PDFs',
              subtitle: 'Combine files',
              color: AppColors.purple,
              onTap: () => _go(context, const MergePdfsScreen()),
            ),
          ],
        ),

        // ── 5. SHARING ───────────────────────────────────────────────────────
        _Section(
          title: 'Share & Print',
          icon: Iconsax.share,
          color: AppColors.blue,
          items: [
            _item(
              icon: Iconsax.share,
              title: 'Share',
              subtitle: 'WhatsApp, email…',
              color: AppColors.navyMid,
              onTap: () => _withDoc(
                  context,
                  (doc) => _go(
                      context,
                      AdvancedSharingScreen(
                          filePath: doc.filePath, fileName: doc.name))),
            ),
            _item(
              icon: Iconsax.printer,
              title: 'Print',
              subtitle: 'Print document',
              color: AppColors.navyDark,
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
          ],
        ),

        // ── 6. TOOLS ─────────────────────────────────────────────────────────
        _Section(
          title: 'Tools',
          icon: Iconsax.setting,
          color: AppColors.red,
          items: [
            _item(
              icon: Iconsax.camera,
              title: 'ID Photo',
              subtitle: 'Passport & visa',
              color: AppColors.purple,
              onTap: () => _go(context, const IdPhotoMakerScreen()),
            ),
            _item(
              icon: Iconsax.gallery,
              title: 'Gallery',
              subtitle: 'Pick & scan photo',
              color: AppColors.red,
              onTap: () => _pickAndEdit(context),
            ),
            _item(
              icon: Iconsax.pen_add,
              title: 'Signature',
              subtitle: 'Draw & save',
              color: AppColors.purple,
              onTap: () => _go(context, const SignaturePadScreen()),
            ),
          ],
        ),
      ];

  // ── Shorthand feature-item builder ──────────────────────────────────────
  _FeatureItem _item({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      _FeatureItem(
          icon: icon,
          title: title,
          subtitle: subtitle,
          color: color,
          onTap: onTap);

  // ── Navigation helpers ───────────────────────────────────────────────────

  void _go(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _pickAndEdit(BuildContext context) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty || !context.mounted) return;
    _go(
        context,
        EditScanScreen(
          imagePaths: images.map((e) => e.path).toList(),
          scanType: 'photo',
        ));
  }

  Future<void> _withImage(
      BuildContext context, void Function(String path) onPath) async {
    if (imagePath != null) {
      onPath(imagePath!);
      return;
    }
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null && context.mounted) onPath(img.path);
  }

  Future<void> _withImageForEdit(BuildContext context) async {
    if (imagePath != null) {
      _go(context,
          EditScanScreen(imagePaths: [imagePath!], scanType: 'document'));
      return;
    }
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null && context.mounted) {
      _go(context,
          EditScanScreen(imagePaths: [img.path], scanType: 'document'));
    }
  }

  Future<void> _withDoc(
      BuildContext context, void Function(DocumentModel) onDoc) async {
    if (document != null) {
      onDoc(document!);
      return;
    }
    final docs = await DatabaseService.instance.getAllDocuments();
    if (!context.mounted) return;
    if (docs.isEmpty) {
      _showInfo(context, 'Please scan or import a document first.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select a Document',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          SizedBox(
            height: 280,
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final chosen = docs[i];
                return ListTile(
                  leading: Icon(Iconsax.document, color: AppColors.navyMid),
                  title: Text(
                    chosen.name,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    chosen.fileType.toUpperCase(),
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Future.microtask(() {
                      if (!context.mounted) return;
                      onDoc(chosen);
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: AppColors.navyMid,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ══════════════════════════════════════════════════════════════
//  _CategorySection  –  header + horizontal scrollable row
// ══════════════════════════════════════════════════════════════

class _CategorySection extends StatelessWidget {
  final _Section section;
  const _CategorySection({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 28,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(section.icon, color: section.color, size: 16),
              ),
              const SizedBox(width: 7),
              Text(
                section.title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF1E2A4A),
                ),
              ),
            ],
          ),
        ),

        // ── Grid (no horizontal scroll) ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.90,
            ),
            itemCount: section.items.length,
            itemBuilder: (_, i) => _FeatureTile(item: section.items[i]),
          ),
        ),

        const SizedBox(height: 10),

        // ── Divider between sections ────────────────────────────
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.withValues(alpha: 0.13),
          indent: 18,
          endIndent: 18,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _FeatureTile  –  compact vertical card (icon + label)
// ══════════════════════════════════════════════════════════════

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  color: const Color(0xFF1E2A4A),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 8.5,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Data models
// ══════════════════════════════════════════════════════════════

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FeatureItem> items;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
