import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';
import '../models/vehicle_rc_data.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_service.dart';
import '../services/vehicle_rc_ocr_service.dart';
import '../theme.dart';

class VehicleRcResultScreen extends StatefulWidget {
  final List<String> imagePaths;

  const VehicleRcResultScreen({super.key, required this.imagePaths});

  @override
  State<VehicleRcResultScreen> createState() => _VehicleRcResultScreenState();
}

class _VehicleRcResultScreenState extends State<VehicleRcResultScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showBoxes = true;
  VehicleRcData _data = const VehicleRcData();
  List<Rect> _boxes = const [];
  double _iw = 1;
  double _ih = 1;

  final _reg = TextEditingController();
  final _owner = TextEditingController();
  final _ownerAddr = TextEditingController();
  final _father = TextEditingController();
  final _cnic = TextEditingController();
  final _engine = TextEditingController();
  final _chassis = TextEditingController();
  final _makeModel = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _fuel = TextEditingController();
  final _seat = TextEditingController();
  final _tokenStatus = TextEditingController();
  final _tokenDue = TextEditingController();
  final _fitness = TextEditingController();
  final _permit = TextEditingController();
  final _excise = TextEditingController();
  final _province = TextEditingController();
  final _history = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    for (final c in [
      _reg,
      _owner,
      _ownerAddr,
      _father,
      _cnic,
      _engine,
      _chassis,
      _makeModel,
      _year,
      _color,
      _fuel,
      _seat,
      _tokenStatus,
      _tokenDue,
      _fitness,
      _permit,
      _excise,
      _province,
      _history,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final result = await VehicleRcOcrService.instance.extractFromPages(widget.imagePaths);
      _data = result.data;
      _boxes = result.textBoxes;
      _fill(result.data);
      await _measureImage(widget.imagePaths.first);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _measureImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final im = img.decodeImage(bytes);
    if (im == null || !mounted) return;
    setState(() {
      _iw = im.width.toDouble();
      _ih = im.height.toDouble();
    });
  }

  void _fill(VehicleRcData d) {
    _reg.text = d.registrationNumber;
    _owner.text = d.ownerName;
    _ownerAddr.text = d.ownerAddress;
    _father.text = d.fatherName;
    _cnic.text = d.cnicNumber;
    _engine.text = d.engineNumber;
    _chassis.text = d.chassisNumber;
    _makeModel.text = d.makeModel;
    _year.text = d.manufacturingYear;
    _color.text = d.color;
    _fuel.text = d.fuelType;
    _seat.text = d.seatingCapacity;
    _tokenStatus.text = d.tokenTaxStatus;
    _tokenDue.text = d.tokenTaxDueDate;
    _fitness.text = d.fitnessExpiry;
    _permit.text = d.routePermit;
    _excise.text = d.exciseTaxationNumber;
    _province.text = d.provinceCity;
    _history.text = d.ownershipHistory;
  }

  VehicleRcData _currentData() {
    return _data.copyWith(
      registrationNumber: _reg.text.trim(),
      ownerName: _owner.text.trim(),
      ownerAddress: _ownerAddr.text.trim(),
      fatherName: _father.text.trim(),
      cnicNumber: _cnic.text.trim(),
      engineNumber: _engine.text.trim(),
      chassisNumber: _chassis.text.trim(),
      makeModel: _makeModel.text.trim(),
      manufacturingYear: _year.text.trim(),
      color: _color.text.trim(),
      fuelType: _fuel.text.trim(),
      seatingCapacity: _seat.text.trim(),
      tokenTaxStatus: _tokenStatus.text.trim(),
      tokenTaxDueDate: _tokenDue.text.trim(),
      fitnessExpiry: _fitness.text.trim(),
      routePermit: _permit.text.trim(),
      exciseTaxationNumber: _excise.text.trim(),
      provinceCity: _province.text.trim(),
      ownershipHistory: _history.text.trim(),
    );
  }

  Future<void> _copyField(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<String> _saveJson(VehicleRcData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/VehicleRC');
    await out.create(recursive: true);
    final file = File('${out.path}/vehicle_rc_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return file.path;
  }

  Future<void> _exportAll() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final d = _currentData();
      final title = d.registrationNumber.isEmpty ? 'Vehicle_RC' : d.registrationNumber.replaceAll(' ', '_');
      final pdfPath = await PdfService.instance.createPdfFromImages(widget.imagePaths, title);
      final thumb = await PdfService.instance.generateThumbnail(widget.imagePaths.first);
      final size = await PdfService.instance.getFileSizeMB(pdfPath);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$title.pdf',
          filePath: pdfPath,
          fileType: 'pdf',
          scanType: 'vehicle_rc',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: d.rawText,
          tags: const ['Vehicle RC'],
        ),
      );
      final json = await _saveJson(d);
      final xlsx =
          await ExcelExportService.instance.exportVehicleRcToExcel([d.toJsonMap()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved PDF + JSON + Excel (${p.basename(json)}, ${p.basename(xlsx)})',
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
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Vehicle Registration', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showBoxes = !_showBoxes),
            icon: Icon(_showBoxes ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _historyCard(d),
                  const SizedBox(height: 10),
                  _preview(),
                  const SizedBox(height: 10),
                  _validation(d),
                  const SizedBox(height: 10),
                  _field('Registration Number', _reg, isError: _reg.text.isNotEmpty && !d.registrationNumberValid),
                  _field('Owner Name', _owner),
                  _field('Owner Address', _ownerAddr, maxLines: 2),
                  _field('Father Name', _father),
                  _field('CNIC', _cnic),
                  _field('Engine Number', _engine),
                  _field('Chassis Number', _chassis),
                  _field('Make & Model', _makeModel),
                  _field('Manufacturing Year', _year),
                  _field('Color', _color),
                  _field('Fuel Type', _fuel),
                  _field('Seating Capacity', _seat),
                  _field('Token Tax Status', _tokenStatus),
                  _field('Token Tax Due Date', _tokenDue),
                  _field('Fitness Expiry', _fitness),
                  _field('Route Permit', _permit),
                  _field('Excise & Taxation Number', _excise),
                  _field('Province / City', _province),
                  _field('Ownership History', _history, maxLines: 3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _saveJson(_currentData()),
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
                          onPressed: _saving ? null : _exportAll,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Export'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _historyCard(VehicleRcData d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ScanResultFormStyle.insightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vehicle History Summary', style: ScanResultFormStyle.cardTitle()),
          const SizedBox(height: 8),
          Text(
            'Format: ${d.documentFormat.isEmpty ? 'Unknown' : d.documentFormat}',
            style: ScanResultFormStyle.muted(),
          ),
          Text(
            'Province/City: ${d.provinceCity.isEmpty ? 'N/A' : d.provinceCity}',
            style: ScanResultFormStyle.muted(),
          ),
          Text(
            'Ownership: ${d.ownershipHistory.isEmpty ? 'Not detected' : d.ownershipHistory}',
            style: ScanResultFormStyle.muted(),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final first = widget.imagePaths.first;
    return AspectRatio(
      aspectRatio: _iw / _ih,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(first), fit: BoxFit.cover),
            if (_showBoxes) CustomPaint(painter: _RcBoxesPainter(boxes: _boxes, iw: _iw, ih: _ih)),
          ],
        ),
      ),
    );
  }

  Widget _validation(VehicleRcData d) {
    Widget row(String l, String v, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(width: 150, child: Text(l, style: ScanResultFormStyle.muted())),
              Expanded(child: Text(v, style: GoogleFonts.nunito(color: c, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ScanResultFormStyle.insightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Validation', style: ScanResultFormStyle.cardTitle()),
          const SizedBox(height: 8),
          row('Reg number format', d.registrationNumberValid ? 'Valid' : 'Invalid', d.registrationNumberValid ? AppColors.green : Colors.redAccent),
          row('Token tax', d.tokenTaxValid ? 'Valid' : 'Expired/Unknown', d.tokenTaxValid ? AppColors.green : Colors.orange),
          row('Fitness', d.fitnessValid ? 'Valid' : 'Expired/Unknown', d.fitnessValid ? AppColors.green : Colors.orange),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool isError = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: ScanResultFormStyle.label())),
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
            style: ScanResultFormStyle.inputText(),
            decoration: ScanResultFormStyle.textFieldDecoration(
              radius: 10,
              errorText: isError ? 'Invalid value' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RcBoxesPainter extends CustomPainter {
  final List<Rect> boxes;
  final double iw;
  final double ih;
  const _RcBoxesPainter({required this.boxes, required this.iw, required this.ih});

  @override
  void paint(Canvas canvas, Size size) {
    if (iw <= 1 || ih <= 1) return;
    final sx = size.width / iw;
    final sy = size.height / ih;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.gold.withValues(alpha: 0.9);
    for (final b in boxes) {
      canvas.drawRect(Rect.fromLTRB(b.left * sx, b.top * sy, b.right * sx, b.bottom * sy), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RcBoxesPainter oldDelegate) =>
      oldDelegate.boxes != boxes || oldDelegate.iw != iw || oldDelegate.ih != ih;
}

