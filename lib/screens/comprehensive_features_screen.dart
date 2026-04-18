import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import 'document_conversion_screen.dart';
import 'scan_screen.dart';
import 'document_viewer_screen.dart';
import 'advanced_filters_screen.dart';
import 'templates_screen.dart';
import 'annotation_screen.dart';
import 'advanced_sharing_screen.dart';
import 'id_photo_maker_screen.dart';
import 'text_extraction_screen.dart';
import 'import_documents_screen.dart';
import 'search_screen.dart';
import 'documents_screen.dart';
import 'edit_scan_screen.dart';
import 'settings_screen.dart';
import 'office_export_hub_screen.dart';
import 'photo_enhancement_screen.dart';

class ComprehensiveFeaturesScreen extends StatefulWidget {
  const ComprehensiveFeaturesScreen({super.key});

  @override
  State<ComprehensiveFeaturesScreen> createState() =>
      _ComprehensiveFeaturesScreenState();
}

class _ComprehensiveFeaturesScreenState
    extends State<ComprehensiveFeaturesScreen> {
  String _selectedCategory = 'all';

  // ── Feature definitions ────────────────────────────────────────────────────
  late final List<_Feature> _allFeatures;

  @override
  void initState() {
    super.initState();
    _allFeatures = _buildAllFeatures();
  }

  List<_Feature> _buildAllFeatures() => [
        // SCANNING
        _Feature(
            icon: Iconsax.camera,
            title: 'Scan Document',
            subtitle: 'Camera scanner',
            color: AppColors.gold,
            cat: 'scanning',
            action: _scanDocument),
        _Feature(
            icon: Iconsax.card,
            title: 'Scan ID Card',
            subtitle: 'ID, license, passport',
            color: AppColors.blue,
            cat: 'scanning',
            action: _scanIdCard),
        _Feature(
            icon: Iconsax.receipt,
            title: 'Scan Receipt',
            subtitle: 'Bills and receipts',
            color: AppColors.green,
            cat: 'scanning',
            action: _scanReceipt),
        _Feature(
            icon: Iconsax.scan_barcode,
            title: 'QR / Barcode',
            subtitle: 'Scan codes instantly',
            color: const Color(0xFF6366F1),
            cat: 'scanning',
            action: _scanQr),
        _Feature(
            icon: Iconsax.book,
            title: 'Scan Book',
            subtitle: 'Two-page book scanning',
            color: AppColors.orange,
            cat: 'scanning',
            action: _scanBook),
        _Feature(
            icon: Iconsax.text_block,
            title: 'Whiteboard',
            subtitle: 'Capture whiteboard',
            color: const Color(0xFF06B6D4),
            cat: 'scanning',
            action: _scanWhiteboard),
        _Feature(
            icon: Iconsax.element_3,
            title: 'Scan Table',
            subtitle: 'Tables & spreadsheets',
            color: const Color(0xFF84CC16),
            cat: 'scanning',
            action: _scanTable),
        _Feature(
            icon: Iconsax.personalcard,
            title: 'Scan Passport',
            subtitle: 'Passport scanner',
            color: const Color(0xFFF43F5E),
            cat: 'scanning',
            action: _scanPassport),
        _Feature(
            icon: Iconsax.gallery,
            title: 'Import Photo',
            subtitle: 'Pick from gallery',
            color: AppColors.red,
            cat: 'scanning',
            action: _pickAndEdit),

        // EDITING
        _Feature(
            icon: Iconsax.magicpen,
            title: 'Auto Enhance',
            subtitle: 'Improve scan quality',
            color: AppColors.gold,
            cat: 'editing',
            action: _autoEnhance),
        _Feature(
            icon: Iconsax.setting_2,
            title: 'Advanced Filters',
            subtitle: 'Brightness, contrast',
            color: AppColors.blue,
            cat: 'editing',
            action: _advancedFilters),
        _Feature(
            icon: Iconsax.crop,
            title: 'Crop & Edit',
            subtitle: 'Crop and adjust pages',
            color: AppColors.purple,
            cat: 'editing',
            action: _cropEdit),
        _Feature(
            icon: Iconsax.rotate_left,
            title: 'Rotate',
            subtitle: 'Rotate 90° / 180°',
            color: AppColors.blue,
            cat: 'editing',
            action: _cropEdit),
        _Feature(
            icon: Iconsax.shield_tick,
            title: 'Watermark',
            subtitle: 'Add text watermark',
            color: AppColors.orange,
            cat: 'editing',
            action: _watermark),
        _Feature(
            icon: Iconsax.pen_add,
            title: 'Annotate',
            subtitle: 'Draw and mark docs',
            color: AppColors.blue,
            cat: 'editing',
            action: _annotate),
        _Feature(
            icon: Iconsax.clock,
            title: 'Timestamp',
            subtitle: 'Add date & time stamp',
            color: AppColors.navyMid,
            cat: 'editing',
            action: _cropEdit),
        _Feature(
            icon: Iconsax.copy,
            title: 'Batch Process',
            subtitle: 'Apply to multiple files',
            color: AppColors.red,
            cat: 'editing',
            action: _batchProcess),

        // AI / OCR
        _Feature(
            icon: Iconsax.text,
            title: 'Extract Text',
            subtitle: 'OCR — copy text',
            color: AppColors.purple,
            cat: 'ai',
            action: _extractText),
        _Feature(
            icon: Iconsax.translate,
            title: 'Translate',
            subtitle: 'Translate document text',
            color: AppColors.orange,
            cat: 'ai',
            action: _extractText),
        _Feature(
            icon: Iconsax.scan_barcode,
            title: 'Barcode Reader',
            subtitle: 'Advanced barcode scan',
            color: AppColors.green,
            cat: 'ai',
            action: _scanQr),
        _Feature(
            icon: Iconsax.people,
            title: 'Face Detection',
            subtitle: 'Detect faces',
            color: AppColors.purple,
            cat: 'ai',
            action: _extractText),
        _Feature(
            icon: Iconsax.eye,
            title: 'Object Detect',
            subtitle: 'Identify objects',
            color: AppColors.blue,
            cat: 'ai',
            action: _extractText),

        // DOCUMENTS
        _Feature(
            icon: Iconsax.folder_open,
            title: 'My Documents',
            subtitle: 'All saved documents',
            color: AppColors.navyMid,
            cat: 'documents',
            action: _myDocuments),
        _Feature(
            icon: Iconsax.import_2,
            title: 'Import Files',
            subtitle: 'Import from device',
            color: AppColors.blue,
            cat: 'documents',
            action: _importFiles),
        _Feature(
            icon: Iconsax.search_normal,
            title: 'Search',
            subtitle: 'Find documents fast',
            color: AppColors.navyMid,
            cat: 'documents',
            action: _search),
        _Feature(
            icon: Iconsax.document,
            title: 'Templates',
            subtitle: 'Pre-made formats',
            color: AppColors.green,
            cat: 'documents',
            action: _templates),
        _Feature(
            icon: Iconsax.convert_3d_cube,
            title: 'Convert PDF',
            subtitle: 'PDF to Word, Excel...',
            color: AppColors.red,
            cat: 'documents',
            action: _convertPdf),
        _Feature(
            icon: Iconsax.document_upload,
            title: 'Office Export',
            subtitle: 'Excel, Word, PPT, Slides',
            color: AppColors.purple,
            cat: 'documents',
            action: _officeExport),
        _Feature(
            icon: Iconsax.document_download,
            title: 'Export',
            subtitle: 'Save as PDF or image',
            color: AppColors.gold,
            cat: 'documents',
            action: _exportDoc),
        _Feature(
            icon: Iconsax.edit_2,
            title: 'Batch Rename',
            subtitle: 'Rename multiple docs',
            color: AppColors.blue,
            cat: 'documents',
            action: _myDocuments),
        _Feature(
            icon: Iconsax.arrow_swap_horizontal,
            title: 'Compare Docs',
            subtitle: 'Compare two documents',
            color: AppColors.navyMid,
            cat: 'documents',
            action: _myDocuments),
        _Feature(
            icon: Iconsax.document_copy,
            title: 'PDF Editing',
            subtitle: 'Advanced PDF tools',
            color: AppColors.purple,
            cat: 'documents',
            action: _exportDoc),
        _Feature(
            icon: Iconsax.document_download,
            title: 'Excel Export',
            subtitle: 'Export to Excel format',
            color: AppColors.green,
            cat: 'documents',
            action: _exportDoc),

        // SHARING
        _Feature(
            icon: Iconsax.share,
            title: 'Share',
            subtitle: 'WhatsApp, email, Drive',
            color: AppColors.navyMid,
            cat: 'sharing',
            action: _share),
        _Feature(
            icon: Iconsax.printer,
            title: 'Print',
            subtitle: 'Print documents',
            color: AppColors.navyDark,
            cat: 'sharing',
            action: _print),

        // SECURITY
        _Feature(
            icon: Iconsax.lock,
            title: 'Biometric Lock',
            subtitle: 'Fingerprint/Face lock',
            color: AppColors.red,
            cat: 'security',
            action: _biometric),

        // TOOLS
        _Feature(
            icon: Iconsax.camera,
            title: 'ID Photo Maker',
            subtitle: 'Passport & visa photos',
            color: AppColors.purple,
            cat: 'tools',
            action: _idPhoto),
        _Feature(
            icon: Iconsax.notification,
            title: 'Notifications',
            subtitle: 'Document reminders',
            color: AppColors.gold,
            cat: 'tools',
            action: _notifications),
      ];

  List<_Feature> get _filtered {
    if (_selectedCategory == 'all') return _allFeatures;
    return _allFeatures.where((f) => f.cat == _selectedCategory).toList();
  }

  // ── Category tabs ──────────────────────────────────────────────────────────
  static const _categories = [
    ('all', 'All'),
    ('scanning', 'Scanning'),
    ('editing', 'Editing'),
    ('ai', 'AI'),
    ('documents', 'Documents'),
    ('sharing', 'Sharing'),
    ('security', 'Security'),
    ('tools', 'Tools'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Features',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 18)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter chips
          Container(
            color: AppColors.navyDark,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isActive = _selectedCategory == cat.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppColors.gold : Colors.white24,
                        ),
                      ),
                      child: Text(cat.$2,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppColors.navyDark : Colors.white,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Features grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _FeatureCard(feature: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _scanDocument() => _go(const ScanScreen(scanType: 'document'));
  void _scanIdCard() => _go(const ScanScreen(scanType: 'id_card'));
  void _scanReceipt() => _go(const ScanScreen(scanType: 'receipt'));
  void _scanQr() => _go(const ScanScreen(scanType: 'qr'));
  void _scanBook() => _go(const ScanScreen(scanType: 'book'));
  void _scanWhiteboard() => _go(const ScanScreen(scanType: 'whiteboard'));
  void _scanTable() => _go(const ScanScreen(scanType: 'table'));
  void _scanPassport() => _go(const ScanScreen(scanType: 'passport'));
  void _templates() => _go(const TemplatesScreen());
  void _idPhoto() => _go(const IdPhotoMakerScreen());
  void _myDocuments() => _go(const DocumentsScreen());
  void _importFiles() => _go(const ImportDocumentsScreen());
  void _search() => _go(const SearchScreen());

  Future<void> _pickAndEdit() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty || !mounted) return;
    _go(EditScanScreen(
        imagePaths: images.map((e) => e.path).toList(), scanType: 'photo'));
  }

  Future<void> _autoEnhance() async {
    final path = await _pickSingleImage();
    if (path == null || !mounted) return;
    _go(PhotoEnhancementScreen(imagePaths: [path]));
  }

  Future<void> _advancedFilters() async {
    final path = await _pickSingleImage();
    if (path == null || !mounted) return;
    _go(AdvancedFiltersScreen(imagePath: path));
  }

  Future<void> _cropEdit() async {
    final path = await _pickSingleImage();
    if (path == null || !mounted) return;
    _go(EditScanScreen(imagePaths: [path], scanType: 'document'));
  }

  Future<void> _annotate() async {
    final path = await _pickSingleImage();
    if (path == null || !mounted) return;
    _go(AnnotationScreen(imagePath: path));
  }

  Future<void> _extractText() async {
    final path = await _pickSingleImage();
    if (path == null || !mounted) return;
    _go(TextExtractionScreen(imagePath: path));
  }

  Future<void> _watermark() async {
    final doc = await _pickDoc();
    if (doc == null || !mounted) return;
    _go(DocumentViewerScreen(document: doc));
  }

  Future<void> _convertPdf() async {
    final doc = await _pickDoc();
    if (doc == null || !mounted) return;
    _go(DocumentConversionScreen(filePath: doc.filePath));
  }

  void _officeExport() {
    _go(const OfficeExportHubScreen());
  }

  Future<void> _exportDoc() async {
    final doc = await _pickDoc();
    if (doc == null || !mounted) return;
    _go(DocumentViewerScreen(document: doc));
  }

  Future<void> _share() async {
    final doc = await _pickDoc();
    if (doc == null || !mounted) return;
    _go(AdvancedSharingScreen(filePath: doc.filePath, fileName: doc.name));
  }

  Future<void> _print() async {
    final doc = await _pickDoc();
    if (doc == null || !mounted) return;
    _go(DocumentViewerScreen(document: doc));
  }

  Future<void> _batchProcess() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isEmpty || !mounted) return;
    _go(EditScanScreen(
        imagePaths: images.map((e) => e.path).toList(), scanType: 'document'));
  }

  void _biometric() {
    _go(const SettingsScreen(padsForBottomTabShell: false));
  }

  void _notifications() {
    _go(const SettingsScreen(padsForBottomTabShell: false));
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  Future<String?> _pickSingleImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    return img?.path;
  }

  Future<DocumentModel?> _pickDoc() async {
    final docs = await DatabaseService.instance.getAllDocuments();
    if (!mounted) return null;
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please scan or import a document first.',
            style: GoogleFonts.nunito()),
        backgroundColor: AppColors.navyMid,
        behavior: SnackBarBehavior.floating,
      ));
      return null;
    }
    DocumentModel? selected;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              itemBuilder: (_, i) => ListTile(
                leading: Icon(Iconsax.document, color: AppColors.navyMid),
                title: Text(docs[i].name,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                subtitle: Text(docs[i].fileType.toUpperCase(),
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: AppColors.textMuted)),
                onTap: () {
                  selected = docs[i];
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    return selected;
  }
}

// ── Feature card widget ────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: feature.action,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(feature.icon, color: feature.color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(feature.title,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(feature.subtitle,
                  style: GoogleFonts.nunito(
                      fontSize: 10, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String cat;
  final VoidCallback action;
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.cat,
    required this.action,
  });
}
