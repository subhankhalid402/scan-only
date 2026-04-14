import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';
import '../models/driving_license_data.dart';
import '../services/database_service.dart';
import '../services/driving_license_ocr_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class DrivingLicenseResultScreen extends StatefulWidget {
  final String frontImagePath;
  final String? backImagePath;

  const DrivingLicenseResultScreen({
    super.key,
    required this.frontImagePath,
    this.backImagePath,
  });

  @override
  State<DrivingLicenseResultScreen> createState() =>
      _DrivingLicenseResultScreenState();
}

class _DrivingLicenseResultScreenState
    extends State<DrivingLicenseResultScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showBoxes = true;
  DrivingLicenseData _data = const DrivingLicenseData();
  List<Rect> _frontBoxes = const [];
  List<Rect> _backBoxes = const [];

  final _name = TextEditingController();
  final _father = TextEditingController();
  final _cnic = TextEditingController();
  final _licNo = TextEditingController();
  final _dob = TextEditingController();
  final _issue = TextEditingController();
  final _expiry = TextEditingController();
  final _addr = TextEditingController();
  final _cats = TextEditingController();
  final _blood = TextEditingController();
  final _auth = TextEditingController();
  final _dlims = TextEditingController();
  final _province = TextEditingController();
  final _type = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _father,
      _cnic,
      _licNo,
      _dob,
      _issue,
      _expiry,
      _addr,
      _cats,
      _blood,
      _auth,
      _dlims,
      _province,
      _type,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final result = await DrivingLicenseOcrService.instance.extractFromSides(
        frontImagePath: widget.frontImagePath,
        backImagePath: widget.backImagePath,
      );
      _data = result.data;
      _frontBoxes = result.frontBoxes;
      _backBoxes = result.backBoxes;
      _name.text = _data.fullName;
      _father.text = _data.fatherName;
      _cnic.text = _data.cnicNumber;
      _licNo.text = _data.licenseNumber;
      _dob.text = _data.dateOfBirth;
      _issue.text = _data.dateOfIssue;
      _expiry.text = _data.dateOfExpiry;
      _addr.text = _data.address;
      _cats.text = _data.vehicleCategories.join(', ');
      _blood.text = _data.bloodGroup;
      _auth.text = _data.issuingAuthority;
      _dlims.text = _data.dlimsNumber;
      _province.text = _data.province;
      _type.text = _data.licenseType;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DrivingLicenseData _currentData() {
    final cats = _cats.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return _data.copyWith(
      fullName: _name.text.trim(),
      fatherName: _father.text.trim(),
      cnicNumber: _cnic.text.trim(),
      licenseNumber: _licNo.text.trim(),
      dateOfBirth: _dob.text.trim(),
      dateOfIssue: _issue.text.trim(),
      dateOfExpiry: _expiry.text.trim(),
      address: _addr.text.trim(),
      vehicleCategories: cats,
      bloodGroup: _blood.text.trim(),
      issuingAuthority: _auth.text.trim(),
      dlimsNumber: _dlims.text.trim(),
      province: _province.text.trim(),
      licenseType: _type.text.trim(),
    );
  }

  Future<void> _copyField(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<String> _saveJson(DrivingLicenseData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/DrivingLicenses');
    await out.create(recursive: true);
    final file = File(
        '${out.path}/driving_license_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return file.path;
  }

  Future<void> _export() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final d = _currentData();
      final title = d.fullName.isEmpty
          ? 'Driving_License'
          : d.fullName.replaceAll(' ', '_');
      final pdfPath = await PdfService.instance.createIdCardTwoSidePdf(
        frontPath: widget.frontImagePath,
        backPath: widget.backImagePath,
        documentName: title,
      );
      final thumb =
          await PdfService.instance.generateThumbnail(widget.frontImagePath);
      final size = await PdfService.instance.getFileSizeMB(pdfPath);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$title.pdf',
          filePath: pdfPath,
          fileType: 'pdf',
          scanType: 'driving_license',
          pageCount: 1,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: '${d.rawFrontText}\n${d.rawBackText}',
          tags: const ['Driving License'],
        ),
      );
      final jsonPath = await _saveJson(d);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved PDF + JSON (${p.basename(jsonPath)})',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.green,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _currentData();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Driving License',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showBoxes = !_showBoxes),
            icon: Icon(_showBoxes ? Icons.visibility : Icons.visibility_off),
          )
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
                            boxes: _showBoxes ? _frontBoxes : const []),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CardPreview(
                            title: 'Back',
                            imagePath: widget.backImagePath,
                            boxes: _showBoxes ? _backBoxes : const []),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _validation(d),
                  const SizedBox(height: 10),
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
                        _field('Full Name', _name),
                        _field('Father Name', _father),
                        _field(
                          'CNIC',
                          _cnic,
                          isError: _cnic.text.isNotEmpty && !d.cnicValid,
                        ),
                        _field(
                          'License Number',
                          _licNo,
                          isError:
                              _licNo.text.isNotEmpty && !d.licenseNumberValid,
                        ),
                        _field('Date of Birth', _dob),
                        _field('Issue Date', _issue),
                        _field('Expiry Date', _expiry),
                        _field('Address', _addr, maxLines: 2),
                        _field(
                          'Vehicle Categories',
                          _cats,
                          isError: _cats.text.isNotEmpty &&
                              !d.vehicleCategoriesValid,
                        ),
                        _field('Blood Group', _blood),
                        _field('Issuing Authority / RTO', _auth),
                        _field('DLIMS Number', _dlims),
                        _field('Province', _province),
                        _field('License Type (Learner/Full)', _type),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _saving ? null : () => _saveJson(_currentData()),
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text('JSON'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navyDark,
                          ),
                          onPressed: _saving ? null : _export,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Export'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }

  Widget _validation(DrivingLicenseData d) {
    Widget row(String l, String v, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                  width: 140,
                  child: Text(l,
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
          row(
              'Expiry',
              d.hasExpiry ? (d.isExpired ? 'Expired' : 'Valid') : 'Unknown',
              d.hasExpiry
                  ? (d.isExpired ? Colors.redAccent : AppColors.green)
                  : Colors.orange),
          row('License number', d.licenseNumberValid ? 'Valid' : 'Invalid',
              d.licenseNumberValid ? AppColors.green : Colors.redAccent),
          row(
              'Vehicle classes',
              d.vehicleCategoriesValid ? 'Valid' : 'Check classes',
              d.vehicleCategoriesValid ? AppColors.green : Colors.orange),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool isError = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                onPressed: () => _copyField(label, c.text.trim()),
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.navyMid,
              ),
            ],
          ),
          TextField(
            controller: c,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(_iconForLabel(label), color: AppColors.navyMid),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
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
    if (key.contains('license') || key.contains('dlims')) {
      return Icons.credit_card;
    }
    if (key.contains('birth') ||
        key.contains('issue') ||
        key.contains('expiry')) {
      return Icons.event_note_outlined;
    }
    if (key.contains('address') || key.contains('province')) {
      return Icons.home_outlined;
    }
    if (key.contains('blood')) return Icons.bloodtype_outlined;
    return Icons.edit_note_rounded;
  }
}

class _CardPreview extends StatefulWidget {
  final String title;
  final String? imagePath;
  final List<Rect> boxes;
  const _CardPreview(
      {required this.title, required this.imagePath, required this.boxes});

  @override
  State<_CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<_CardPreview> {
  double _iw = 1;
  double _ih = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = widget.imagePath;
    if (p == null) return;
    final bytes = await File(p).readAsBytes();
    final im = img.decodeImage(bytes);
    if (im == null || !mounted) return;
    setState(() {
      _iw = im.width.toDouble();
      _ih = im.height.toDouble();
    });
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
                child: Text('${widget.title}\nNot captured',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(color: Colors.white54)))
            : ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(widget.imagePath!), fit: BoxFit.cover),
                    CustomPaint(
                      painter:
                          _BoxesPainter(boxes: widget.boxes, iw: _iw, ih: _ih),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(widget.title,
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BoxesPainter extends CustomPainter {
  final List<Rect> boxes;
  final double iw;
  final double ih;
  const _BoxesPainter(
      {required this.boxes, required this.iw, required this.ih});

  @override
  void paint(Canvas canvas, Size size) {
    if (iw <= 1 || ih <= 1) return;
    final sx = size.width / iw;
    final sy = size.height / ih;
    final p = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final b in boxes) {
      canvas.drawRect(
        Rect.fromLTRB(b.left * sx, b.top * sy, b.right * sx, b.bottom * sy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoxesPainter oldDelegate) =>
      oldDelegate.boxes != boxes ||
      oldDelegate.iw != iw ||
      oldDelegate.ih != ih;
}
