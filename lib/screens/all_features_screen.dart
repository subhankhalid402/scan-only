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
import 'photo_enhancement_screen.dart';

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
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
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
          tagline:
              'Each mode sets capture tips, import shortcuts, and polish presets like a dedicated scanner profile.',
          items: [
            _item(
              icon: Iconsax.document_text,
              title: 'Document',
              subtitle: 'Papers, letters, contracts',
              color: AppColors.gold,
              highlights: const ['Auto deskew', 'Multi-page'],
              onTap: () => _go(context, const ScanScreen(scanType: 'document')),
            ),
            _item(
              icon: Iconsax.receipt,
              title: 'Receipt',
              subtitle: 'Bills, invoices, thermal rolls',
              color: const Color(0xFF22C55E),
              highlights: const ['Amount OCR', 'Long receipt mode'],
              onTap: () => _go(context, const ScanScreen(scanType: 'receipt')),
            ),
            _item(
              icon: Iconsax.card,
              title: 'ID card',
              subtitle: 'National ID, NICOP, etc.',
              color: const Color(0xFF3B82F6),
              highlights: const ['Front & back', 'Glare-friendly'],
              onTap: () => _go(context, const ScanScreen(scanType: 'id_card')),
            ),
            _item(
              icon: Iconsax.personalcard,
              title: 'Passport',
              subtitle: 'Photo page & MRZ',
              color: const Color(0xFFF43F5E),
              highlights: const ['MRZ-aware crop', 'Field extract'],
              onTap: () => _go(context, const ScanScreen(scanType: 'passport')),
            ),
            _item(
              icon: Iconsax.card_tick_1,
              title: 'Driving license',
              subtitle: 'DL front / back',
              color: const Color(0xFF0EA5E9),
              highlights: const ['Dual-side flow', 'Text extract'],
              onTap: () =>
                  _go(context, const ScanScreen(scanType: 'driving_license')),
            ),
            _item(
              icon: Iconsax.book,
              title: 'Book',
              subtitle: 'Curved pages & spreads',
              color: const Color(0xFFF97316),
              highlights: const ['Spine cleanup', 'Dual page'],
              onTap: () => _go(context, const ScanScreen(scanType: 'book')),
            ),
            _item(
              icon: Iconsax.text_block,
              title: 'Whiteboard',
              subtitle: 'Meeting boards & notes',
              color: const Color(0xFF06B6D4),
              highlights: const ['Glare removal', 'Perspective'],
              onTap: () =>
                  _go(context, const ScanScreen(scanType: 'whiteboard')),
            ),
            _item(
              icon: Iconsax.element_3,
              title: 'Table',
              subtitle: 'Printed grids → CSV',
              color: const Color(0xFF84CC16),
              highlights: const ['Cell OCR', 'Export sheet'],
              onTap: () => _go(context, const ScanScreen(scanType: 'table')),
            ),
            _item(
              icon: Iconsax.camera,
              title: 'Photo',
              subtitle: 'High-res, minimal processing',
              color: const Color(0xFF94A3B8),
              highlights: const ['Natural color', 'No doc flatten'],
              onTap: () => _go(context, const ScanScreen(scanType: 'photo')),
            ),
            _item(
              icon: Icons.school_rounded,
              title: 'Certificate',
              subtitle: 'Degrees, diplomas, transcripts',
              color: const Color(0xFF8B5CF6),
              highlights: const ['Seals & QR', 'Portfolio PDF'],
              onTap: () => _go(
                  context, const ScanScreen(scanType: 'academic_certificate')),
            ),
            _item(
              icon: Iconsax.car,
              title: 'Vehicle RC',
              subtitle: 'Registration card fields',
              color: const Color(0xFF0D9488),
              highlights: const ['OCR layout', 'Multi-page'],
              onTap: () =>
                  _go(context, const ScanScreen(scanType: 'vehicle_rc')),
            ),
            _item(
              icon: Iconsax.note_text,
              title: 'Prescription',
              subtitle: 'Medicine list extract',
              color: const Color(0xFFEC4899),
              highlights: const ['Dose & name rows', 'Share text'],
              onTap: () => _go(
                  context, const ScanScreen(scanType: 'medical_prescription')),
            ),
            _item(
              icon: Iconsax.bank,
              title: 'Bank statement',
              subtitle: 'Tables & balances',
              color: const Color(0xFF64748B),
              highlights: const ['Long pages', 'CSV-style'],
              onTap: () =>
                  _go(context, const ScanScreen(scanType: 'bank_statement')),
            ),
            _item(
              icon: Iconsax.scan_barcode,
              title: 'QR & barcode',
              subtitle: 'Live camera decode',
              color: const Color(0xFF6366F1),
              highlights: const ['QR + 1D/2D', 'Copy & open URL'],
              onTap: () => _go(context, const ScanScreen(scanType: 'qr')),
            ),
          ],
        ),

        // ── 2. EDITING ───────────────────────────────────────────────────────
        _Section(
          title: 'Editing',
          icon: Iconsax.magicpen,
          color: AppColors.purple,
          tagline:
              'Polish scans after capture — pick a tool that matches what you want to change.',
          items: [
            _item(
              icon: Iconsax.magicpen,
              title: 'Auto enhance',
              subtitle: 'Photo tools — Auto Enhance button',
              color: AppColors.gold,
              highlights: const ['Tone & clarity', 'Doc mode & export'],
              onTap: () => _withImage(
                  context,
                  (path) => _go(
                        context,
                        PhotoEnhancementScreen(imagePaths: [path]),
                      )),
            ),
            _item(
              icon: Iconsax.setting_2,
              title: 'Manual filters',
              subtitle: 'Sliders & fine control',
              color: AppColors.blue,
              highlights: const ['Brightness', 'Curves-style'],
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, AdvancedFiltersScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.crop,
              title: 'Crop & perspective',
              subtitle: 'Full editor with pages',
              color: AppColors.purple,
              highlights: const ['Corners', 'Reorder pages'],
              onTap: () => _withImageForEdit(context),
            ),
            _item(
              icon: Iconsax.rotate_left,
              title: 'Rotate pages',
              subtitle: '90° steps in editor',
              color: AppColors.blue,
              highlights: const ['Per page', 'Batch view'],
              onTap: () => _withImageForEdit(context),
            ),
            _item(
              icon: Iconsax.shield_tick,
              title: 'Watermark',
              subtitle: 'Open file → ⋮ menu',
              color: AppColors.orange,
              highlights: const ['Text or image stamp', 'Opacity & angle'],
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
            _item(
              icon: Iconsax.pen_add,
              title: 'Annotate',
              subtitle: 'Pen, highlighter, shapes',
              color: AppColors.blue,
              highlights: const ['On top of scan', 'Export with marks'],
              onTap: () => _withImage(context,
                  (path) => _go(context, AnnotationScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.clock,
              title: 'Timestamp',
              subtitle: 'Stamp date/time in editor',
              color: AppColors.navyMid,
              highlights: const ['Audit trail style', 'Position control'],
              onTap: () => _withImageForEdit(context),
            ),
            _item(
              icon: Iconsax.eraser,
              title: 'Smart erase',
              subtitle: 'Paint out fingers & stains',
              color: AppColors.red,
              highlights: const ['Local only', 'Refine edges'],
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
          tagline:
              'On-device text intelligence — nothing leaves your phone unless you enable cloud backup.',
          items: [
            _item(
              icon: Iconsax.text,
              title: 'Extract text',
              subtitle: 'OCR to copy or share',
              color: AppColors.purple,
              highlights: const ['ML Kit offline', 'Selectable result'],
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, TextExtractionScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.translate,
              title: 'Translate',
              subtitle: 'Same screen as extract',
              color: AppColors.orange,
              highlights: const ['Pick target language', 'Side-by-side'],
              onTap: () => _withImage(
                  context,
                  (path) =>
                      _go(context, TextExtractionScreen(imagePath: path))),
            ),
            _item(
              icon: Iconsax.scan_barcode,
              title: 'Barcode lab',
              subtitle: 'Dedicated live scanner',
              color: AppColors.green,
              highlights: const ['Batch-friendly', 'Actions after scan'],
              onTap: () => _go(context, const ScanScreen(scanType: 'qr')),
            ),
          ],
        ),

        // ── 4. DOCUMENTS ─────────────────────────────────────────────────────
        _Section(
          title: 'Documents',
          icon: Iconsax.folder_open,
          color: AppColors.navyMid,
          tagline:
              'Library, import, and office workflows — each entry opens a focused workflow.',
          items: [
            _item(
              icon: Iconsax.folder_open,
              title: 'My files',
              subtitle: 'Library & favorites',
              color: AppColors.navyMid,
              highlights: const ['Search & tags', 'Open in viewer'],
              onTap: () => _go(context, const DocumentsScreen()),
            ),
            _item(
              icon: Iconsax.import_2,
              title: 'Import',
              subtitle: 'Images & PDFs from device',
              color: AppColors.blue,
              highlights: const ['Bulk add', 'Into library'],
              onTap: () => _go(context, const ImportDocumentsScreen()),
            ),
            _item(
              icon: Iconsax.document,
              title: 'Templates',
              subtitle: 'Covers, invoices, layouts',
              color: AppColors.green,
              highlights: const ['Start from preset', 'Fill & export'],
              onTap: () => _go(context, const TemplatesScreen()),
            ),
            _item(
              icon: Iconsax.convert_3d_cube,
              title: 'Convert PDF',
              subtitle: 'Needs a saved file',
              color: AppColors.red,
              highlights: const ['Word / Excel paths', 'Pick from list'],
              onTap: () => _withDoc(
                  context,
                  (doc) => _go(context,
                      DocumentConversionScreen(filePath: doc.filePath))),
            ),
            _item(
              icon: Iconsax.document_upload,
              title: 'Office export hub',
              subtitle: 'Spreadsheets & decks',
              color: AppColors.purple,
              highlights: const ['Excel / PPT / Slides', 'Batch-friendly'],
              onTap: () => _go(context, const OfficeExportHubScreen()),
            ),
            _item(
              icon: Icons.compress_rounded,
              title: 'Compress PDF',
              subtitle: 'From document viewer',
              color: AppColors.navyMid,
              highlights: const ['Smaller share size', 'Pick doc first'],
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
            _item(
              icon: Iconsax.document_download,
              title: 'Export PDF',
              subtitle: 'Share-ready output',
              color: AppColors.gold,
              highlights: const ['Viewer share sheet', 'Print-ready'],
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
            _item(
              icon: Iconsax.document_copy,
              title: 'Merge PDFs',
              subtitle: 'Combine & reorder',
              color: AppColors.purple,
              highlights: const ['Drag order', 'Single output'],
              onTap: () => _go(context, const MergePdfsScreen()),
            ),
          ],
        ),

        // ── 5. SHARING ───────────────────────────────────────────────────────
        _Section(
          title: 'Share & print',
          icon: Iconsax.share,
          color: AppColors.blue,
          tagline:
              'Uses the selected file from your library — same flows as in the document viewer.',
          items: [
            _item(
              icon: Iconsax.share,
              title: 'Share',
              subtitle: 'Links, apps, size options',
              color: AppColors.navyMid,
              highlights: const ['Advanced sharing UI', 'Pick any saved doc'],
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
              subtitle: 'System print dialog',
              color: AppColors.navyDark,
              highlights: const ['From viewer', 'Best for PDF'],
              onTap: () => _withDoc(context,
                  (doc) => _go(context, DocumentViewerScreen(document: doc))),
            ),
          ],
        ),

        // ── 6. TOOLS ─────────────────────────────────────────────────────────
        _Section(
          title: 'Specialty tools',
          icon: Iconsax.setting,
          color: AppColors.red,
          tagline:
              'Utilities that do not fit a single scan mode — each opens its own dedicated screen.',
          items: [
            _item(
              icon: Iconsax.camera,
              title: 'ID photo booth',
              subtitle: 'Passport / visa sizing',
              color: AppColors.purple,
              highlights: const ['Background color', 'Print sheet'],
              onTap: () => _go(context, const IdPhotoMakerScreen()),
            ),
            _item(
              icon: Iconsax.gallery,
              title: 'Gallery → edit',
              subtitle: 'Multi-photo session',
              color: AppColors.red,
              highlights: const ['Photo scan type', 'Merge in editor'],
              onTap: () => _pickAndEdit(context),
            ),
            _item(
              icon: Iconsax.pen_add,
              title: 'Signature pad',
              subtitle: 'Draw once, reuse PNG',
              color: AppColors.purple,
              highlights: const ['Transparent export', 'Insert into PDF'],
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
    List<String> highlights = const [],
  }) =>
      _FeatureItem(
        icon: icon,
        title: title,
        subtitle: subtitle,
        color: color,
        onTap: onTap,
        highlights: highlights,
      );

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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Expanded(
                    child: Text(
                      section.title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF1E2A4A),
                      ),
                    ),
                  ),
                ],
              ),
              if (section.tagline != null && section.tagline!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    section.tagline!,
                    style: GoogleFonts.nunito(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
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
              childAspectRatio: 0.78,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: item.color.withValues(alpha: 0.12),
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
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
              width: 44,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  height: 1.1,
                  color: const Color(0xFF1E2A4A),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                item.subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 8.8,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.highlights.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.highlights.take(2).join(' · '),
                  style: GoogleFonts.nunito(
                    fontSize: 7.6,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
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
  /// One line under the section title (scanner-style category description).
  final String? tagline;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.tagline,
  });
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  /// Short bullets specific to this tool (shown under subtitle).
  final List<String> highlights;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlights = const [],
  });
}
