import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/ocr_service.dart';

// ══════════════════════════════════════════════════════════════
//  TextExtractionScreen  –  CamScanner-style OCR screen
//
//  Working features:
//  ✅ OCR extraction with real loading state
//  ✅ Copy to clipboard  (flutter/services)
//  ✅ Share as text      (share_plus)
//  ✅ Save as .txt file  (path_provider + dart:io)
//  ✅ Edit extracted text + save changes
//  ✅ Re-extract (retry) button
//  ✅ Select-all shortcut
//  ✅ Word / line / confidence stats
//  ✅ Language selector for translate (UI-ready, hook your service)
// ══════════════════════════════════════════════════════════════

class TextExtractionScreen extends StatefulWidget {
  final String imagePath;
  const TextExtractionScreen({super.key, required this.imagePath});

  @override
  State<TextExtractionScreen> createState() => _TextExtractionScreenState();
}

class _TextExtractionScreenState extends State<TextExtractionScreen> {
  // ── State ────────────────────────────────────────────────────
  String _extractedText = '';
  bool _isExtracting = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _textEdited = false;

  late TextEditingController _textController;

  Map<String, dynamic> _stats = {
    'confidence': 0.0,
    'wordCount': 0,
    'lineCount': 0,
  };

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() {
      if (_isEditing && _textController.text != _extractedText) {
        setState(() => _textEdited = true);
      }
    });
    _extractText();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ── OCR ──────────────────────────────────────────────────────

  Future<void> _extractText() async {
    if (!mounted) return;
    setState(() {
      _isExtracting = true;
      _extractedText = '';
      _textEdited = false;
    });

    try {
      final details =
          await OcrService.instance.extractTextWithDetails(widget.imagePath);
      if (mounted) {
        final text = (details['text'] as String? ?? '').trim();
        setState(() {
          _extractedText = text;
          _stats = details;
          _textController.text = text;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        _showError('Text extract nahi ho saka: $e');
      }
    }
  }

  // ── Copy ─────────────────────────────────────────────────────

  Future<void> _copyToClipboard() async {
    final text = _currentText;
    if (text.isEmpty) { _showError('Copy karne ke liye koi text nahi hai'); return; }

    await Clipboard.setData(ClipboardData(text: text));
    _showSuccess('Text clipboard pe copy ho gaya!');
  }

  // ── Share ─────────────────────────────────────────────────────

  Future<void> _shareText() async {
    final text = _currentText;
    if (text.isEmpty) { _showError('Share karne ke liye koi text nahi hai'); return; }

    await Share.share(
      text,
      subject: 'Extracted Text',
    );
  }

  // ── Save as .txt ──────────────────────────────────────────────

  Future<void> _saveAsFile() async {
    final text = _currentText;
    if (text.isEmpty) { _showError('Save karne ke liye koi text nahi hai'); return; }

    setState(() => _isSaving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/extracted_$timestamp.txt');
      await file.writeAsString(text);
      _showSuccess('File save ho gayi:\nextracted_$timestamp.txt');
    } catch (e) {
      _showError('Save nahi ho saka: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Edit helpers ──────────────────────────────────────────────

  void _toggleEdit() {
    if (_isEditing && _textEdited) {
      // Confirm discard
      _showDiscardDialog();
      return;
    }
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) _textController.text = _extractedText; // reset on cancel
    });
  }

  void _applyEdits() {
    setState(() {
      _extractedText = _textController.text;
      _isEditing = false;
      _textEdited = false;
      // Recount stats after edit
      final words = _extractedText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final lines = _extractedText.trim().split('\n').where((l) => l.isNotEmpty).length;
      _stats = {..._stats, 'wordCount': words, 'lineCount': lines};
    });
    _showSuccess('Changes save ho gaaye!');
  }

  void _selectAll() {
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
  }

  // ── Translate sheet ───────────────────────────────────────────

  void _showTranslateSheet() {
    // UI-ready: hook your translate service here.
    // Languages list — extend as needed.
    final langs = [
      ('Urdu', '🇵🇰'), ('English', '🇬🇧'), ('Arabic', '🇸🇦'),
      ('French', '🇫🇷'), ('German', '🇩🇪'), ('Spanish', '🇪🇸'),
      ('Chinese', '🇨🇳'), ('Hindi', '🇮🇳'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Translate to…',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          Wrap(
            spacing: 10, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: langs.map((l) => ActionChip(
              avatar: Text(l.$2, style: const TextStyle(fontSize: 16)),
              label: Text(l.$1, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13)),
              backgroundColor: AppColors.navyDark.withOpacity(0.06),
              onPressed: () {
                Navigator.pop(context);
                // TODO: call your translate service with (text, targetLang: l.$1)
                _showSuccess('Translate feature ke liye apna service hook karein.');
              },
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Changes discard karein?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Aapki editing save nahi hogi.',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.nunito(color: AppColors.navyDark)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _textController.text = _extractedText;
                _isEditing = false;
                _textEdited = false;
              });
            },
            child: Text('Discard', style: GoogleFonts.nunito(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Snackbars ─────────────────────────────────────────────────

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────

  String get _currentText =>
      _isEditing ? _textController.text.trim() : _extractedText;

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: _isExtracting ? _buildLoading() : _buildBody(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.navyDark,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        _isEditing ? 'Edit Text' : 'Extract Text',
        style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      actions: [
        if (!_isExtracting && _extractedText.isNotEmpty) ...[
          // Translate button
          if (!_isEditing)
            IconButton(
              icon: const Icon(Iconsax.translate, size: 22),
              tooltip: 'Translate',
              onPressed: _showTranslateSheet,
            ),
          // Edit / Cancel edit
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Iconsax.edit_2, size: 22),
            tooltip: _isEditing ? 'Cancel' : 'Edit',
            onPressed: _toggleEdit,
          ),
          // Select All (only in edit mode)
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.select_all, size: 22),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
        ],
        // Retry
        if (!_isExtracting)
          IconButton(
            icon: const Icon(Iconsax.refresh, size: 22),
            tooltip: 'Re-extract',
            onPressed: _extractText,
          ),
      ],
    );
  }

  // ── Loading ───────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
          const SizedBox(height: 20),
          Text('Text extract ho raha hai…',
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.navyDark)),
          const SizedBox(height: 6),
          Text('Thoda intezaar karein',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────

  Widget _buildBody() {
    return Column(
      children: [
        // ── Image thumbnail + stats ─────────────────────────────
        _buildHeader(),

        // ── Text area ───────────────────────────────────────────
        Expanded(child: _buildTextArea()),

        // ── Bottom action bar ───────────────────────────────────
        _buildActionBar(),
      ],
    );
  }

  // ── Header: image + stats ─────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Thumbnail
          SizedBox(
            height: 130,
            width: double.infinity,
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),

          // Stats row (only when text found)
          if (_extractedText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navyDark.withOpacity(0.04),
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statChip(Iconsax.verify, '${((_stats['confidence'] as num) * 100).toStringAsFixed(0)}%', 'Confidence'),
                  _dividerDot(),
                  _statChip(Iconsax.text, '${_stats['wordCount']}', 'Words'),
                  _dividerDot(),
                  _statChip(Iconsax.row_horizontal, '${_stats['lineCount']}', 'Lines'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.navyDark),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navyDark)),
            Text(label,
                style: GoogleFonts.nunito(fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _dividerDot() => Container(
        width: 1, height: 28,
        color: Colors.grey.withOpacity(0.25),
      );

  // ── Text area ─────────────────────────────────────────────────

  Widget _buildTextArea() {
    if (_extractedText.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.document_text, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text('Koi text nahi mila',
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text('Roshan tasveer se dobara koshish karein',
                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _extractText,
              icon: const Icon(Iconsax.refresh, size: 18),
              label: Text('Dobara Extract Karein',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyDark,
                side: BorderSide(color: AppColors.navyDark.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: _isEditing
          ? _buildEditField()
          : _buildReadField(),
    );
  }

  Widget _buildReadField() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _extractedText,
        style: GoogleFonts.nunito(fontSize: 14, height: 1.7, color: Colors.black87),
      ),
    );
  }

  Widget _buildEditField() {
    return Column(
      children: [
        // Edit toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.navyDark.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
          ),
          child: Row(
            children: [
              Icon(Iconsax.edit_2, size: 14, color: AppColors.navyDark.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text('Edit mode — changes apply honge',
                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.navyDark.withOpacity(0.6))),
              const Spacer(),
              GestureDetector(
                onTap: _applyEdits,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Save',
                      style: GoogleFonts.nunito(
                          fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        // Text field
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            style: GoogleFonts.nunito(fontSize: 14, height: 1.7, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  // ── Action bar ────────────────────────────────────────────────

  Widget _buildActionBar() {
    // In edit mode — show save / cancel prominently
    if (_isEditing) {
      return _buildEditActionBar();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Row(
        children: [
          _actionBtn(
            icon: Iconsax.copy,
            label: 'Copy',
            color: AppColors.blue,
            onTap: _copyToClipboard,
          ),
          const SizedBox(width: 10),
          _actionBtn(
            icon: Iconsax.share,
            label: 'Share',
            color: AppColors.navyMid,
            onTap: _shareText,
          ),
          const SizedBox(width: 10),
          _actionBtn(
            icon: _isSaving ? null : Iconsax.save_2,
            label: 'Save .txt',
            color: AppColors.green,
            onTap: _isSaving ? null : _saveAsFile,
            isLoading: _isSaving,
          ),
          const SizedBox(width: 10),
          _actionBtn(
            icon: Iconsax.translate,
            label: 'Translate',
            color: AppColors.orange,
            onTap: _extractedText.isEmpty ? null : _showTranslateSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildEditActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _toggleEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: BorderSide(color: AppColors.red.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _applyEdits,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Changes Save Karein',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData? icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final disabled = onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: disabled ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                isLoading
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}