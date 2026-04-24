import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/ocr_service.dart';
import '../services/watermark_service.dart';
import 'add_watermark_screen.dart';
import 'remove_watermark_screen.dart';
import 'annotation_screen.dart';
import 'advanced_sharing_screen.dart';
import 'document_conversion_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentModel document;
  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late DocumentModel _doc;
  pdfx.PdfControllerPinch? _pdfController;
  String? _pdfControllerPath;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _ensurePdfController(String path) async {
    if (_pdfControllerPath == path && _pdfController != null) return;
    _pdfController?.dispose();
    _pdfControllerPath = path;
    _pdfController = pdfx.PdfControllerPinch(
      document: pdfx.PdfDocument.openFile(path),
    );
    if (mounted) setState(() {});
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  Future<void> _shareDocument() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedSharingScreen(
          filePath: _doc.filePath,
          fileName: _doc.name,
        ),
      ),
    );
  }

  // ── Print ──────────────────────────────────────────────────────────────────

  Future<void> _printDocument() async {
    if (_doc.fileType == 'pdf') {
      final file = File(_doc.filePath);
      if (file.existsSync()) {
        await Printing.layoutPdf(onLayout: (_) async => file.readAsBytesSync());
      }
    } else {
      _showInfo('Print is available for PDF files only.');
    }
  }

  // ── Open External ──────────────────────────────────────────────────────────

  Future<void> _openWithExternal() async {
    await OpenFilex.open(_doc.filePath);
  }

  // ── Rename ─────────────────────────────────────────────────────────────────

  Future<void> _renameDocument(String newName) async {
    final updated = _doc.copyWith(name: newName, modifiedAt: DateTime.now());
    await DatabaseService.instance.updateDocument(updated);
    setState(() => _doc = updated);
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _doc.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Rename Document',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _renameDocument(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text('Save',
                style: GoogleFonts.nunito(
                    color: AppColors.navyDark, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Favorite ───────────────────────────────────────────────────────────────

  Future<void> _toggleFavorite() async {
    await DatabaseService.instance.toggleFavorite(_doc.id!, !_doc.isFavorite);
    setState(() => _doc = _doc.copyWith(isFavorite: !_doc.isFavorite));
  }

  // ── OCR ────────────────────────────────────────────────────────────────────

  Future<void> _extractOcr() async {
    if (!_isRasterDoc(_doc)) {
      _showInfo('OCR is available for image files (JPG, PNG, WebP) only.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Extracting Text...',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: const SizedBox(
            height: 50, child: Center(child: CircularProgressIndicator())),
      ),
    );

    try {
      final ocrText = await OcrService.instance.extractText(_doc.filePath);
      if (ocrText.isNotEmpty) {
        await DatabaseService.instance.updateOcrText(_doc.id!, ocrText);
        setState(() => _doc = _doc.copyWith(ocrText: ocrText));
      }
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Extracted Text',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Text(
              ocrText.isEmpty ? 'No text found in image.' : ocrText,
              style: GoogleFonts.nunito(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
            if (ocrText.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Share.share(ocrText);
                  Navigator.pop(context);
                },
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                child: Text('Share',
                    style: GoogleFonts.nunito(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('OCR failed: $e');
    }
  }

  // ── Watermark ──────────────────────────────────────────────────────────────

  Future<void> _addWatermark() async {
    if (!_isRasterDoc(_doc)) {
      _showInfo('Watermark is available for image files only.');
      return;
    }
    final out = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
          builder: (_) => AddWatermarkScreen(imagePaths: [_doc.filePath])),
    );
    if (out == null || out.isEmpty || !mounted) return;
    await _replaceDocPath(out.first, suffixName: '_watermarked');
  }

  Future<void> _removeWatermark() async {
    final appRemoved = await WatermarkService.instance
        .removeAppAddedWatermark(File(_doc.filePath));
    if (appRemoved != null) {
      await _replaceDocPath(appRemoved.path, suffixName: '_clean');
      _showInfo('App watermark removed.');
      return;
    }
    if (!mounted) return;

    final out = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RemoveWatermarkScreen(imagePath: _doc.filePath),
      ),
    );
    if (out == null || !mounted) return;
    await _replaceDocPath(out, suffixName: '_wm_removed');
    _showInfo('Watermark removal applied.');
  }

  Future<void> _replaceDocPath(String newPath,
      {required String suffixName}) async {
    if (_doc.fileType.toLowerCase() == 'pdf') {
      _pdfController?.dispose();
      _pdfController = null;
      _pdfControllerPath = null;
    }
    final newSizeMB = await PdfService.instance.getFileSizeMB(newPath);
    final updated = _doc.copyWith(
      filePath: newPath,
      name: '${p.basenameWithoutExtension(_doc.name)}$suffixName.jpg',
      fileType: 'jpg',
      modifiedAt: DateTime.now(),
      fileSizeMB: newSizeMB,
    );
    if (_doc.id != null) {
      await DatabaseService.instance.updateDocument(updated);
    }
    setState(() => _doc = updated);
  }

  // ── Annotate ───────────────────────────────────────────────────────────────

  Future<void> _openAnnotation() async {
    if (!_isRasterDoc(_doc)) {
      _showInfo('Annotations are available for image files only.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AnnotationScreen(imagePath: _doc.filePath)),
    );
  }

  // ── Convert ────────────────────────────────────────────────────────────────

  Future<void> _convertDocument() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => DocumentConversionScreen(filePath: _doc.filePath)),
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Document',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Delete "${_doc.name}"? This cannot be undone.',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await DatabaseService.instance.deleteDocument(_doc.id!);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.navyMid),
    );
  }

  bool _isRasterDoc(DocumentModel d) {
    final t = d.fileType.toLowerCase();
    return t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'webp';
  }

  /// System print layout (PDF bytes).
  bool _canPrint(DocumentModel d) => d.fileType.toLowerCase() == 'pdf';

  /// In-app conversion screen can turn these into PDF (not useful when already PDF).
  bool _canConvert(DocumentModel d) {
    final t = d.fileType.toLowerCase();
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'doc',
      'docx',
      'ppt',
      'pptx',
      'txt',
      'csv',
      'json',
      'html',
      'htm',
      'xlsx',
      'xls',
    }.contains(t);
  }

  Color _fileTypeAccentColor() {
    switch (_doc.fileType.toLowerCase()) {
      case 'pdf':
        return AppColors.navyDark;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return AppColors.navyMid;
      case 'docx':
      case 'doc':
        return AppColors.gold;
      default:
        return AppColors.navyMid;
    }
  }

  Future<void> _generatePdf() async {
    if (!_isRasterDoc(_doc)) {
      _showInfo(
        _doc.fileType.toLowerCase() == 'pdf'
            ? 'This file is already a PDF.'
            : 'Generate PDF is available for JPG/PNG scans only.',
      );
      return;
    }
    final f = File(_doc.filePath);
    if (!f.existsSync()) {
      _showError('File not found.');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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
        [_doc.filePath],
        _doc.name,
        scanType: _doc.scanType,
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      if (saved != null) {
        _showInfo('PDF saved to library: ${saved.name}');
      } else {
        _showError('Could not create PDF.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showError('PDF failed: $e');
    }
  }

  // ── Compress PDF ───────────────────────────────────────────────────────────

  Future<void> _compressPdf() async {
    if (_doc.fileType.toLowerCase() != 'pdf') {
      _showInfo('Compress is only available for PDF files.');
      return;
    }

    // Ask user for quality level
    final quality = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Compress PDF',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Smaller file size — choose quality',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _qualityTile(ctx, 'low', 'Low Quality',
                  'Smallest size — ~60% smaller', AppColors.navyMid),
              const SizedBox(height: 8),
              _qualityTile(ctx, 'medium', 'Medium Quality',
                  'Balanced — ~40% smaller', AppColors.gold),
              const SizedBox(height: 8),
              _qualityTile(ctx, 'high', 'High Quality',
                  'Best quality — ~20% smaller', AppColors.gold),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (quality == null || !mounted) return;

    // Map quality string to jpeg quality + maxWidth values
    int jpegQuality;
    int maxWidth;
    switch (quality) {
      case 'low':
        jpegQuality = 35;
        maxWidth = 900;
        break;
      case 'medium':
        jpegQuality = 55;
        maxWidth = 1200;
        break;
      case 'high':
      default:
        jpegQuality = 72;
        maxWidth = 1600;
        break;
    }

    // Show progress dialog
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Compressing PDF…',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Extract images from existing PDF pages using pdfx, then recompress
      final pdfFile = File(_doc.filePath);
      if (!pdfFile.existsSync()) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showInfo('Original file not found.');
        return;
      }

      final stemName = _doc.name
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
          .trim();
      final compressedName = '${stemName}_compressed';

      // Re-encode using PdfService — pass images or use the PDF path
      // Since PdfService.createCompressedPdfFromImages takes image paths,
      // we render the PDF pages to images first using pdfx, then compress.
      final tempDir = await getTemporaryDirectory();
      final pdfDoc = await pdfx.PdfDocument.openFile(_doc.filePath);
      final imagePaths = <String>[];

      try {
        for (var p = 1; p <= pdfDoc.pagesCount; p++) {
          final page = await pdfDoc.getPage(p);
          try {
            final rw = (page.width * 1.5).clamp(600.0, 2000.0);
            final rh = (page.height * (rw / page.width)).clamp(400.0, 3000.0);
            final rendered = await page.render(
              width: rw,
              height: rh,
              format: pdfx.PdfPageImageFormat.jpeg,
              quality: 95,
            );
            if (rendered != null && rendered.bytes.isNotEmpty) {
              final imgFile = File(
                '${tempDir.path}/compress_p${p}_${DateTime.now().microsecondsSinceEpoch}.jpg',
              );
              await imgFile.writeAsBytes(rendered.bytes);
              imagePaths.add(imgFile.path);
            }
          } finally {
            await page.close();
          }
        }
      } finally {
        await pdfDoc.close();
      }

      if (imagePaths.isEmpty) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showInfo('Could not read PDF pages.');
        return;
      }

      final compressedPath =
          await PdfService.instance.createCompressedPdfFromImages(
        imagePaths,
        compressedName,
        jpegQuality: jpegQuality,
        maxWidth: maxWidth,
      );

      // Calculate size reduction
      final originalSize = _doc.fileSizeMB;
      final newSizeMB = await PdfService.instance.getFileSizeMB(compressedPath);
      final savedPct = originalSize > 0
          ? ((1 - newSizeMB / originalSize) * 100).clamp(0, 99).round()
          : 0;

      // Save to library
      final thumbPath =
          await PdfService.instance.generateThumbnail(imagePaths.first);
      final newDoc = DocumentModel(
        name: '$compressedName.pdf',
        filePath: compressedPath,
        fileType: 'pdf',
        scanType: _doc.scanType,
        pageCount: _doc.pageCount,
        fileSizeMB: newSizeMB,
        createdAt: DateTime.now(),
        thumbnailPath: thumbPath,
        tags: const [],
      );
      await DatabaseService.instance.insertDocument(newDoc);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Compressed! ${originalSize.toStringAsFixed(1)} MB → ${newSizeMB.toStringAsFixed(1)} MB  ($savedPct% smaller)',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.navyMid,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) _showError('Compression failed: $e');
    }
  }

  Widget _qualityTile(BuildContext ctx, String value, String title,
      String subtitle, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.compress_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textDark,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.name,
            style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_doc.isFavorite ? Iconsax.heart5 : Iconsax.heart,
                color: _doc.isFavorite ? Colors.red : Colors.white),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              switch (val) {
                case 'rename':
                  _showRenameDialog();
                  break;
                case 'delete':
                  _deleteDocument();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Info badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.background,
            child: Row(
              children: [
                _infoBadge(
                    '${_doc.pageCount} page${_doc.pageCount > 1 ? 's' : ''}',
                    AppColors.navyMid),
                const SizedBox(width: 8),
                _infoBadge(_doc.fileType.toUpperCase(), _fileTypeAccentColor()),
                const SizedBox(width: 8),
                _infoBadge(
                    '${_doc.fileSizeMB.toStringAsFixed(1)} MB', AppColors.gold),
                const SizedBox(width: 8),
                if (_doc.isFavorite) _infoBadge('♥ Favorite', AppColors.gold),
              ],
            ),
          ),

          // Preview
          Expanded(child: _buildPreview()),

          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _actionBtn(Iconsax.share, 'Share', AppColors.navyMid,
                      _shareDocument),
                  if (_canPrint(_doc)) ...[
                    const SizedBox(width: 8),
                    _actionBtn(Iconsax.printer, 'Print', AppColors.blue,
                        _printDocument),
                  ],
                  if (_isRasterDoc(_doc)) ...[
                    const SizedBox(width: 8),
                    _actionBtn(Iconsax.document_download, 'PDF',
                        AppColors.navyMid, _generatePdf),
                  ],
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.export, 'Open', AppColors.navyMid,
                      _openWithExternal),
                  if (_isRasterDoc(_doc)) ...[
                    const SizedBox(width: 8),
                    _actionBtn(
                        Iconsax.text, 'OCR', AppColors.navyMid, _extractOcr),
                    const SizedBox(width: 8),
                    _actionBtn(Iconsax.shield_tick, 'Watermark',
                        AppColors.gold, _addWatermark),
                    const SizedBox(width: 8),
                    _actionBtn(Iconsax.eraser, 'Remove WM', AppColors.navyMid,
                        _removeWatermark),
                    const SizedBox(width: 8),
                    _actionBtn(Iconsax.pen_add, 'Annotate', AppColors.blue,
                        _openAnnotation),
                  ],
                  if (_canConvert(_doc)) ...[
                    const SizedBox(width: 8),
                    _actionBtn(Iconsax.convert_3d_cube, 'Convert',
                        AppColors.navyMid, _convertDocument),
                  ],
                  if (_doc.fileType.toLowerCase() == 'pdf') ...[
                    const SizedBox(width: 8),
                    _actionBtn(Icons.compress_rounded, 'Compress',
                        AppColors.navyMid, _compressPdf),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final file = File(_doc.filePath);
    if (!file.existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.document_cloud, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('File not found',
                style: GoogleFonts.nunito(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Text(_doc.filePath,
                style: GoogleFonts.nunito(
                    fontSize: 11, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final ext = _doc.fileType.toLowerCase();

    // ── Images ──────────────────────────────────────────────────────────────
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') {
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              cacheWidth: 1440,
              filterQuality: FilterQuality.medium,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // ── PDF ──────────────────────────────────────────────────────────────────
    if (ext == 'pdf') {
      _ensurePdfController(file.path);
      if (_pdfController == null) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        );
      }
      return Container(
        color: Colors.black,
        child: pdfx.PdfViewPinch(controller: _pdfController!),
      );
    }

    // ── Plain text / CSV / JSON / HTML ───────────────────────────────────────
    if (ext == 'txt' || ext == 'csv' || ext == 'json' ||
        ext == 'html' || ext == 'htm' || ext == 'xml' ||
        ext == 'log' || ext == 'md') {
      return _TextFileViewer(file: file);
    }

    // ── All other formats (docx, xlsx, ppt, etc.) ────────────────────────────
    // Show file info + open with external app button
    return _UnsupportedFileView(
      doc: _doc,
      onOpenExternal: _openWithExternal,
    );
  }

  Widget _infoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Plain-text viewer ────────────────────────────────────────────────────────

class _TextFileViewer extends StatefulWidget {
  final File file;
  const _TextFileViewer({required this.file});

  @override
  State<_TextFileViewer> createState() => _TextFileViewerState();
}

class _TextFileViewerState extends State<_TextFileViewer> {
  String? _content;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.file.readAsString();
      setState(() {
        _content = raw;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null) {
      return Center(
        child: Text('Could not read file: $_error',
            style: GoogleFonts.nunito(color: AppColors.textMuted)),
      );
    }
    return Container(
      color: Colors.white,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _content ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Unsupported file view (docx, xlsx, ppt, etc.) ────────────────────────────

class _UnsupportedFileView extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onOpenExternal;

  const _UnsupportedFileView({
    required this.doc,
    required this.onOpenExternal,
  });

  IconData _iconForType(String ext) {
    switch (ext) {
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForType(String ext) {
    switch (ext) {
      case 'doc':
      case 'docx':
        return const Color(0xFF2B579A); // Word blue
      case 'xls':
      case 'xlsx':
        return const Color(0xFF217346); // Excel green
      case 'ppt':
      case 'pptx':
        return const Color(0xFFD24726); // PowerPoint orange
      case 'zip':
      case 'rar':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.navyMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = doc.fileType.toLowerCase();
    final color = _colorForType(ext);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Icon(_iconForType(ext), size: 52, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              doc.name,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${ext.toUpperCase()} • ${doc.fileSizeMB.toStringAsFixed(1)} MB',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  'Open with another app',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This file type cannot be previewed in-app.\nTap above to open with Word, Excel, or another app.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
