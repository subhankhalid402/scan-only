import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../services/watermark_service.dart';
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

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _renameDocument(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text('Save', style: GoogleFonts.nunito(color: AppColors.navyDark, fontWeight: FontWeight.w700)),
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
    if (_doc.fileType != 'jpg' && _doc.fileType != 'png') {
      _showInfo('OCR is available for image files (JPG/PNG) only.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Extracting Text...', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
      ),
    );

    try {
      final ocrText = await OcrService.instance.extractText(_doc.filePath);
      if (ocrText.isNotEmpty) {
        await DatabaseService.instance.updateOcrText(_doc.id!, ocrText);
        setState(() => _doc = _doc.copyWith(ocrText: ocrText));
      }
      if (mounted) Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Extracted Text', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Text(
              ocrText.isEmpty ? 'No text found in image.' : ocrText,
              style: GoogleFonts.nunito(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            if (ocrText.isNotEmpty)
              ElevatedButton(
                onPressed: () { Share.share(ocrText); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                child: Text('Share', style: GoogleFonts.nunito(color: AppColors.navyDark, fontWeight: FontWeight.w700)),
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
    if (_doc.fileType != 'jpg' && _doc.fileType != 'png') {
      _showInfo('Watermark is available for image files only.');
      return;
    }

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Watermark', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter watermark text',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _applyWatermark(controller.text); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text('Apply', style: GoogleFonts.nunito(color: AppColors.navyDark, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _applyWatermark(String text) async {
    if (text.trim().isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
      ),
    );
    try {
      await WatermarkService.instance.addTextWatermark(_doc.filePath, text: text);
      if (mounted) Navigator.pop(context);
      _showInfo('Watermark added successfully!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Watermark failed: $e');
    }
  }

  // ── Annotate ───────────────────────────────────────────────────────────────

  Future<void> _openAnnotation() async {
    if (_doc.fileType != 'jpg' && _doc.fileType != 'png') {
      _showInfo('Annotations are available for image files only.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnotationScreen(imagePath: _doc.filePath)),
    );
  }

  // ── Convert ────────────────────────────────────────────────────────────────

  Future<void> _convertDocument() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentConversionScreen(filePath: _doc.filePath)),
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Document', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Delete "${_doc.name}"? This cannot be undone.', style: GoogleFonts.nunito()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await DatabaseService.instance.deleteDocument(_doc.id!);
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.name,
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _doc.isFavorite ? Iconsax.heart5 : Iconsax.heart,
              color: _doc.isFavorite ? Colors.red : Colors.white),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              switch (val) {
                case 'rename':  _showRenameDialog(); break;
                case 'share':   _shareDocument(); break;
                case 'print':   _printDocument(); break;
                case 'open':    _openWithExternal(); break;
                case 'convert': _convertDocument(); break;
                case 'delete':  _deleteDocument(); break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename',  child: Text('Rename')),
              PopupMenuItem(value: 'share',   child: Text('Share')),
              PopupMenuItem(value: 'print',   child: Text('Print')),
              PopupMenuItem(value: 'open',    child: Text('Open with...')),
              PopupMenuItem(value: 'convert', child: Text('Convert')),
              PopupMenuItem(value: 'delete',  child: Text('Delete', style: TextStyle(color: Colors.red))),
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
                _infoBadge('${_doc.pageCount} page${_doc.pageCount > 1 ? 's' : ''}', AppColors.navyMid),
                const SizedBox(width: 8),
                _infoBadge(_doc.fileType.toUpperCase(), AppColors.red),
                const SizedBox(width: 8),
                _infoBadge('${_doc.fileSizeMB.toStringAsFixed(1)} MB', AppColors.green),
                const SizedBox(width: 8),
                if (_doc.isFavorite)
                  _infoBadge('♥ Favorite', AppColors.red),
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
                  _actionBtn(Iconsax.share,        'Share',     AppColors.navyMid,   _shareDocument),
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.printer,      'Print',     AppColors.blue,      _printDocument),
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.export,       'Open',      AppColors.green,     _openWithExternal),
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.text,         'OCR',       AppColors.purple,    _extractOcr),
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.shield_tick,  'Watermark', AppColors.orange,    _addWatermark),
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.pen_add,      'Annotate',  AppColors.blue,      _openAnnotation),
                  const SizedBox(width: 8),
                  _actionBtn(Iconsax.convert_3d_cube, 'Convert', AppColors.red,     _convertDocument),
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
            Text('File not found', style: GoogleFonts.nunito(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Text(_doc.filePath, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_doc.fileType == 'jpg' || _doc.fileType == 'jpeg' || _doc.fileType == 'png') {
      return InteractiveViewer(
        child: Center(child: Image.file(file, fit: BoxFit.contain)),
      );
    }

    if (_doc.fileType == 'pdf') {
      return PdfPreview(
        build: (_) => file.readAsBytesSync(),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canDebug: false,
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_doc.name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _openWithExternal,
            icon: const Icon(Iconsax.export),
            label: const Text('Open with app'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyMid),
          ),
        ],
      ),
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
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
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
            Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
