import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';
import '../models/id_card_data.dart';
import '../services/database_service.dart';
import '../services/id_card_ocr_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class IdCardResultScreen extends StatefulWidget {
  final String frontImagePath;
  final String? backImagePath;

  const IdCardResultScreen({
    super.key,
    required this.frontImagePath,
    this.backImagePath,
  });

  @override
  State<IdCardResultScreen> createState() => _IdCardResultScreenState();
}

class _IdCardResultScreenState extends State<IdCardResultScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showTextBoxes = true;

  IdCardData _data = const IdCardData();
  List<Rect> _frontBoxes = const [];
  List<Rect> _backBoxes = const [];

  final _name = TextEditingController();
  final _father = TextEditingController();
  final _cnic = TextEditingController();
  final _dob = TextEditingController();
  final _issue = TextEditingController();
  final _expiry = TextEditingController();
  final _address = TextEditingController();
  final _gender = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    _name.dispose();
    _father.dispose();
    _cnic.dispose();
    _dob.dispose();
    _issue.dispose();
    _expiry.dispose();
    _address.dispose();
    _gender.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final res = await IdCardOcrService.instance.extractFromCardSides(
        frontImagePath: widget.frontImagePath,
        backImagePath: widget.backImagePath,
      );
      _data = res.data;
      _frontBoxes = res.frontBoxes;
      _backBoxes = res.backBoxes;
      _name.text = _data.name;
      _father.text = _data.fatherName;
      _cnic.text = _data.cnicNumber;
      _dob.text = _data.dateOfBirth;
      _issue.text = _data.issueDate;
      _expiry.text = _data.expiryDate;
      _address.text = _data.address;
      _gender.text = _data.gender;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IdCardData _currentData() {
    return _data.copyWith(
      name: _name.text.trim(),
      fatherName: _father.text.trim(),
      cnicNumber: _cnic.text.trim(),
      dateOfBirth: _dob.text.trim(),
      issueDate: _issue.text.trim(),
      expiryDate: _expiry.text.trim(),
      address: _address.text.trim(),
      gender: _gender.text.trim(),
    );
  }

  Future<void> _copyField(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<String> _saveJson(IdCardData card) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/IDCards');
    await outDir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${outDir.path}/id_card_$ts.json');
    final payload =
        const JsonEncoder.withIndent('  ').convert(card.toJsonMap());
    await file.writeAsString(payload);
    return file.path;
  }

  Future<void> _exportJsonOnly() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final path = await _saveJson(_currentData());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON saved: ${p.basename(path)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdfAndSaveDoc() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final card = _currentData();
      final title =
          card.name.isEmpty ? 'ID_Card' : card.name.replaceAll(' ', '_');
      final pdfPath = await PdfService.instance.createIdCardTwoSidePdf(
        frontPath: widget.frontImagePath,
        backPath: widget.backImagePath,
        documentName: title,
      );
      final thumb =
          await PdfService.instance.generateThumbnail(widget.frontImagePath);
      final size = await PdfService.instance.getFileSizeMB(pdfPath);
      final doc = DocumentModel(
        name: '$title.pdf',
        filePath: pdfPath,
        fileType: 'pdf',
        scanType: 'id_card',
        pageCount: 1,
        fileSizeMB: size,
        createdAt: DateTime.now(),
        thumbnailPath: thumb,
        ocrText: '${card.rawFrontText}\n${card.rawBackText}',
        tags: const ['ID Card'],
      );
      await DatabaseService.instance.insertDocument(doc);
      final jsonPath = await _saveJson(card);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved PDF + JSON (${p.basename(jsonPath)})',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _currentData();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text(
          'ID Card Details',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: _showTextBoxes ? 'Hide text areas' : 'Show text areas',
            onPressed: () => setState(() => _showTextBoxes = !_showTextBoxes),
            icon: Icon(
              _showTextBoxes
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CardPreview(
                          title: 'Front',
                          imagePath: widget.frontImagePath,
                          boxes: _showTextBoxes ? _frontBoxes : const [],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CardPreview(
                          title: 'Back',
                          imagePath: widget.backImagePath,
                          boxes: _showTextBoxes ? _backBoxes : const [],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _validationCard(card),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.navyDark.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _field('Name', _name),
                        _field('Father Name', _father),
                        _field(
                          'CNIC Number',
                          _cnic,
                          helper: 'Format: XXXXX-XXXXXXX-X',
                          isError:
                              _cnic.text.trim().isNotEmpty && !card.isCnicValid,
                        ),
                        _field(
                          'Date of Birth',
                          _dob,
                          helper: 'dd-mm-yyyy or dd/mm/yyyy',
                        ),
                        _field('Issue Date', _issue),
                        _field('Expiry Date', _expiry),
                        _field('Address', _address, maxLines: 2),
                        _field('Gender', _gender),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _exportJsonOnly,
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text('Save JSON'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navyDark,
                          ),
                          onPressed: _saving ? null : _exportPdfAndSaveDoc,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Export PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _validationCard(IdCardData card) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyDark.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validation',
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _validationRow(
            'CNIC',
            card.isCnicValid ? 'Valid' : 'Invalid format',
            card.isCnicValid ? AppColors.green : Colors.redAccent,
          ),
          _validationRow(
            'Expiry',
            !card.hasExpiry
                ? 'No expiry date'
                : (card.isExpired ? 'Expired' : 'Valid'),
            !card.hasExpiry
                ? Colors.amber
                : (card.isExpired ? Colors.redAccent : AppColors.green),
          ),
        ],
      ),
    );
  }

  Widget _validationRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.nunito(color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style:
                GoogleFonts.nunito(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? helper,
    bool isError = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    color: AppColors.navyDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.navyMid,
                onPressed: () => _copyField(ctrl.text.trim(), label),
                tooltip: 'Copy $label',
              ),
            ],
          ),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w700,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: Icon(_iconForLabel(label), color: AppColors.navyMid),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              helperText: helper,
              helperStyle:
                  GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11),
              errorText: isError ? 'Invalid value' : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.navyDark.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.navyDark.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final key = label.toLowerCase();
    if (key.contains('name')) return Icons.person_outline_rounded;
    if (key.contains('cnic')) return Icons.badge_outlined;
    if (key.contains('birth')) return Icons.cake_outlined;
    if (key.contains('issue')) return Icons.event_note_outlined;
    if (key.contains('expiry')) return Icons.event_busy_outlined;
    if (key.contains('address')) return Icons.home_outlined;
    if (key.contains('gender')) return Icons.wc_outlined;
    return Icons.edit_note_rounded;
  }
}

class _CardPreview extends StatefulWidget {
  final String title;
  final String? imagePath;
  final List<Rect> boxes;

  const _CardPreview({
    required this.title,
    required this.imagePath,
    required this.boxes,
  });

  @override
  State<_CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<_CardPreview> {
  double _iw = 1;
  double _ih = 1;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void didUpdateWidget(covariant _CardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _loadSize();
  }

  Future<void> _loadSize() async {
    final path = widget.imagePath;
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      if (!mounted) return;
      setState(() {
        _iw = decoded.width.toDouble();
        _ih = decoded.height.toDouble();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1624),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: widget.imagePath == null
            ? Center(
                child: Text(
                  '${widget.title}\nNot captured',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(color: Colors.white54),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath!),
                      fit: BoxFit.cover,
                    ),
                    CustomPaint(
                      painter: _TextBoxesPainter(
                        boxes: widget.boxes,
                        imageW: _iw,
                        imageH: _ih,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.title,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TextBoxesPainter extends CustomPainter {
  final List<Rect> boxes;
  final double imageW;
  final double imageH;

  const _TextBoxesPainter({
    required this.boxes,
    required this.imageW,
    required this.imageH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty || imageW <= 1 || imageH <= 1) return;
    final sx = size.width / imageW;
    final sy = size.height / imageH;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AppColors.gold.withValues(alpha: 0.9);
    for (final b in boxes) {
      final r = Rect.fromLTRB(
        b.left * sx,
        b.top * sy,
        b.right * sx,
        b.bottom * sy,
      );
      canvas.drawRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TextBoxesPainter oldDelegate) {
    return oldDelegate.boxes != boxes ||
        oldDelegate.imageW != imageW ||
        oldDelegate.imageH != imageH;
  }
}
