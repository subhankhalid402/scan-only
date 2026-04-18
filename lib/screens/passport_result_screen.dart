import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';
import '../models/passport_data.dart';
import '../services/database_service.dart';
import '../services/passport_ocr_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class PassportResultScreen extends StatefulWidget {
  final String imagePath;

  const PassportResultScreen({super.key, required this.imagePath});

  @override
  State<PassportResultScreen> createState() => _PassportResultScreenState();
}

class _PassportResultScreenState extends State<PassportResultScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showTextBoxes = true;
  bool _showMrzZone = true;

  PassportData _data = const PassportData();
  List<Rect> _boxes = const [];
  Rect? _mrzRect;
  Rect? _photoRect;
  String? _photoPath;
  double _iw = 1;
  double _ih = 1;

  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _initControllers();
    _extract();
  }

  void _initControllers() {
    for (final key in _fieldKeys) {
      _controllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final im = img.decodeImage(bytes);
      if (im != null) {
        _iw = im.width.toDouble();
        _ih = im.height.toDouble();
      }
      final res = await PassportOcrService.instance.extract(widget.imagePath);
      _data = res.data;
      _boxes = res.textBoxes;
      _mrzRect = res.mrzRect;
      _photoRect = res.photoRect;
      _syncControllers(_data);
      _photoPath = await _extractPhotoCrop(_photoRect);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Passport OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncControllers(PassportData d) {
    _controllers['fullName']!.text = d.fullName;
    _controllers['surname']!.text = d.surname;
    _controllers['givenNames']!.text = d.givenNames;
    _controllers['passportNumber']!.text = d.passportNumber;
    _controllers['nationality']!.text = d.nationality;
    _controllers['countryCode']!.text = d.countryCode;
    _controllers['dateOfBirth']!.text = d.dateOfBirth;
    _controllers['gender']!.text = d.gender;
    _controllers['dateOfExpiry']!.text = d.dateOfExpiry;
    _controllers['dateOfIssue']!.text = d.dateOfIssue;
    _controllers['placeOfBirth']!.text = d.placeOfBirth;
    _controllers['issuingAuthority']!.text = d.issuingAuthority;
    _controllers['personalNumber']!.text = d.personalNumber;
    _controllers['fatherName']!.text = d.fatherName;
    _controllers['motherName']!.text = d.motherName;
    _controllers['cnicNumber']!.text = d.cnicNumber;
    _controllers['nicNumber']!.text = d.nicNumber;
    _controllers['oldPassportNumber']!.text = d.oldPassportNumber;
    _controllers['profession']!.text = d.profession;
    _controllers['religion']!.text = d.religion;
    _controllers['maritalStatus']!.text = d.maritalStatus;
  }

  PassportData _currentData() {
    return _data.copyWith(
      fullName: _controllers['fullName']!.text.trim(),
      surname: _controllers['surname']!.text.trim(),
      givenNames: _controllers['givenNames']!.text.trim(),
      passportNumber: _controllers['passportNumber']!.text.trim(),
      nationality: _controllers['nationality']!.text.trim(),
      countryCode: _controllers['countryCode']!.text.trim(),
      dateOfBirth: _controllers['dateOfBirth']!.text.trim(),
      gender: _controllers['gender']!.text.trim(),
      dateOfExpiry: _controllers['dateOfExpiry']!.text.trim(),
      dateOfIssue: _controllers['dateOfIssue']!.text.trim(),
      placeOfBirth: _controllers['placeOfBirth']!.text.trim(),
      issuingAuthority: _controllers['issuingAuthority']!.text.trim(),
      personalNumber: _controllers['personalNumber']!.text.trim(),
      fatherName: _controllers['fatherName']!.text.trim(),
      motherName: _controllers['motherName']!.text.trim(),
      cnicNumber: _controllers['cnicNumber']!.text.trim(),
      nicNumber: _controllers['nicNumber']!.text.trim(),
      oldPassportNumber: _controllers['oldPassportNumber']!.text.trim(),
      profession: _controllers['profession']!.text.trim(),
      religion: _controllers['religion']!.text.trim(),
      maritalStatus: _controllers['maritalStatus']!.text.trim(),
    );
  }

  Future<String?> _extractPhotoCrop(Rect? photo) async {
    if (photo == null) return null;
    try {
      final source =
          img.decodeImage(await File(widget.imagePath).readAsBytes());
      if (source == null) return null;
      final x = photo.left.round().clamp(0, source.width - 1);
      final y = photo.top.round().clamp(0, source.height - 1);
      final w = photo.width.round().clamp(1, source.width - x);
      final h = photo.height.round().clamp(1, source.height - y);
      final crop = img.copyCrop(source, x: x, y: y, width: w, height: h);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/passport_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(img.encodeJpg(crop, quality: 92));
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<String> _saveJson(PassportData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/Passports');
    await outDir.create(recursive: true);
    final out = File(
        '${outDir.path}/passport_${DateTime.now().millisecondsSinceEpoch}.json');
    await out.writeAsString(
        const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return out.path;
  }

  Future<void> _exportJson() async {
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

  Future<void> _exportPdf() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final d = _currentData();
      final title = d.passportNumber.isEmpty
          ? 'Passport'
          : 'Passport_${d.passportNumber}';
      final pdf = await PdfService.instance
          .createPdfFromImages([widget.imagePath], title);
      final thumb =
          await PdfService.instance.generateThumbnail(widget.imagePath);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$title.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'passport',
          pageCount: 1,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: d.rawText,
          tags: const ['Passport'],
        ),
      );
      await _saveJson(d);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passport PDF + JSON exported',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
    final d = _currentData();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Passport Details',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Toggle MRZ zone',
            onPressed: () => setState(() => _showMrzZone = !_showMrzZone),
            icon: const Icon(Icons.view_agenda_rounded),
          ),
          IconButton(
            tooltip: 'Toggle OCR boxes',
            onPressed: () => setState(() => _showTextBoxes = !_showTextBoxes),
            icon: const Icon(Icons.grid_view_rounded),
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
                  _passportPreview(),
                  const SizedBox(height: 10),
                  _validationCard(d),
                  const SizedBox(height: 10),
                  if (_photoPath != null) ...[
                    Text('Extracted Passport Photo',
                        style: GoogleFonts.nunito(
                            color: AppColors.navyDark,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_photoPath!),
                          height: 120, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                        _field('Full Name', 'fullName'),
                        _field('Surname', 'surname'),
                        _field('Given Names', 'givenNames'),
                        _field(
                          'Passport Number',
                          'passportNumber',
                          isError: d.passportNumber.isNotEmpty &&
                              !d.passportNumberValid,
                        ),
                        _field('Nationality', 'nationality'),
                        _field('Country Code', 'countryCode'),
                        _field('Date of Birth', 'dateOfBirth'),
                        _field('Gender', 'gender'),
                        _field('Date of Issue', 'dateOfIssue'),
                        _field('Date of Expiry', 'dateOfExpiry'),
                        _field('Place of Birth', 'placeOfBirth'),
                        _field('Issuing Authority', 'issuingAuthority'),
                        _field('Personal Number', 'personalNumber'),
                        _field('Father Name', 'fatherName'),
                        _field('Mother Name', 'motherName'),
                        _field('CNIC Number', 'cnicNumber'),
                        _field('NIC Number', 'nicNumber'),
                        _field('Old Passport Number', 'oldPassportNumber'),
                        _field('Profession/Occupation', 'profession'),
                        _field('Religion', 'religion'),
                        _field('Marital Status', 'maritalStatus'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _exportJson,
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text('Export JSON'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navyDark,
                          ),
                          onPressed: _saving ? null : _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
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

  Widget _passportPreview() {
    return AspectRatio(
      aspectRatio: 125 / 88,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(widget.imagePath), fit: BoxFit.cover),
              if (_showTextBoxes)
                CustomPaint(
                    painter: _OverlayPainter(
                        boxes: _boxes,
                        color: AppColors.gold,
                        iw: _iw,
                        ih: _ih)),
              if (_showMrzZone && _mrzRect != null)
                CustomPaint(
                    painter: _OverlayPainter(
                        boxes: [_mrzRect!],
                        color: Colors.redAccent,
                        iw: _iw,
                        ih: _ih,
                        stroke: 2)),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentData().isExpired
                        ? Colors.redAccent
                        : AppColors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentData().isExpired ? 'Expired' : 'Valid',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _validationCard(PassportData d) {
    Widget row(String k, String v, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                  width: 130,
                  child: Text(k,
                      style: GoogleFonts.nunito(color: AppColors.textMuted))),
              Text(v,
                  style: GoogleFonts.nunito(
                      color: c, fontWeight: FontWeight.w800)),
            ],
          ),
        );
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
          Text('Validation',
              style: GoogleFonts.nunito(
                  color: AppColors.navyDark, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          row('MRZ checksum', d.mrzChecksumValid ? 'Passed' : 'Failed',
              d.mrzChecksumValid ? AppColors.green : Colors.redAccent),
          row('MRZ vs visual', d.mrzVisualCrossCheck ? 'Matched' : 'Mismatch',
              d.mrzVisualCrossCheck ? AppColors.green : Colors.orange),
          row('Passport number', d.passportNumberValid ? 'Valid' : 'Invalid',
              d.passportNumberValid ? AppColors.green : Colors.redAccent),
          row(
              'Expiry',
              d.hasExpiry ? (d.isExpired ? 'Expired' : 'Valid') : 'Unknown',
              d.hasExpiry
                  ? (d.isExpired ? Colors.redAccent : AppColors.green)
                  : Colors.orange),
        ],
      ),
    );
  }

  Widget _field(String label, String key, {bool isError = false}) {
    final ctrl = _controllers[key]!;
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
                onPressed: () => _copy(label, ctrl.text.trim()),
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.navyMid,
              ),
            ],
          ),
          TextField(
            controller: ctrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(_iconForLabel(label), color: AppColors.navyMid),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              errorText: isError ? 'Invalid format' : null,
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
    if (key.contains('passport')) return Icons.badge_outlined;
    if (key.contains('cnic') || key.contains('nic')) return Icons.credit_card;
    if (key.contains('birth') ||
        key.contains('issue') ||
        key.contains('expiry')) {
      return Icons.event_note_outlined;
    }
    if (key.contains('country') || key.contains('nationality')) {
      return Icons.flag_outlined;
    }
    if (key.contains('profession')) return Icons.work_outline_rounded;
    return Icons.edit_note_rounded;
  }
}

class _OverlayPainter extends CustomPainter {
  final List<Rect> boxes;
  final Color color;
  final double iw;
  final double ih;
  final double stroke;

  const _OverlayPainter({
    required this.boxes,
    required this.color,
    required this.iw,
    required this.ih,
    this.stroke = 1.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (iw <= 1 || ih <= 1) return;
    final sx = size.width / iw;
    final sy = size.height / ih;
    final p = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final b in boxes) {
      final r =
          Rect.fromLTRB(b.left * sx, b.top * sy, b.right * sx, b.bottom * sy);
      canvas.drawRect(r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.boxes != boxes ||
      oldDelegate.color != color ||
      oldDelegate.iw != iw ||
      oldDelegate.ih != ih;
}

const _fieldKeys = [
  'fullName',
  'surname',
  'givenNames',
  'passportNumber',
  'nationality',
  'countryCode',
  'dateOfBirth',
  'gender',
  'dateOfExpiry',
  'dateOfIssue',
  'placeOfBirth',
  'issuingAuthority',
  'personalNumber',
  'fatherName',
  'motherName',
  'cnicNumber',
  'nicNumber',
  'oldPassportNumber',
  'profession',
  'religion',
  'maritalStatus',
];
