import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_model.dart';
import '../models/medical_prescription_data.dart';
import '../services/database_service.dart';
import '../services/medical_prescription_ocr_service.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class MedicalPrescriptionResultScreen extends StatefulWidget {
  final List<String> imagePaths;

  const MedicalPrescriptionResultScreen({super.key, required this.imagePaths});

  @override
  State<MedicalPrescriptionResultScreen> createState() =>
      _MedicalPrescriptionResultScreenState();
}

class _MedicalPrescriptionResultScreenState
    extends State<MedicalPrescriptionResultScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _showBoxes = true;
  MedicalPrescriptionData _data = const MedicalPrescriptionData();
  List<Rect> _boxes = const [];

  final _doc = TextEditingController();
  final _qual = TextEditingController();
  final _clinic = TextEditingController();
  final _contact = TextEditingController();
  final _docAddr = TextEditingController();
  final _pmdc = TextEditingController();
  final _patient = TextEditingController();
  final _age = TextEditingController();
  final _date = TextEditingController();
  final _diag = TextEditingController();
  final _tests = TextEditingController();
  final _follow = TextEditingController();
  List<MedicineEntry> _meds = [];

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    for (final c in [
      _doc,
      _qual,
      _clinic,
      _contact,
      _docAddr,
      _pmdc,
      _patient,
      _age,
      _date,
      _diag,
      _tests,
      _follow
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final res =
          await MedicalPrescriptionOcrService.instance.extractFromPages(widget.imagePaths);
      _data = res.data;
      _boxes = res.textBoxes;
      _doc.text = _data.doctorName;
      _qual.text = _data.qualification;
      _clinic.text = _data.clinicName;
      _contact.text = _data.doctorContact;
      _docAddr.text = _data.doctorAddress;
      _pmdc.text = _data.pmdcNumber;
      _patient.text = _data.patientName;
      _age.text = _data.patientAge;
      _date.text = _data.prescriptionDate;
      _diag.text = _data.diagnosis;
      _tests.text = _data.labTests.join(', ');
      _follow.text = _data.followUpDate;
      _meds = List<MedicineEntry>.from(_data.medicines);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MedicalPrescriptionData _currentData() {
    final tests = _tests.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return _data.copyWith(
      doctorName: _doc.text.trim(),
      qualification: _qual.text.trim(),
      clinicName: _clinic.text.trim(),
      doctorContact: _contact.text.trim(),
      doctorAddress: _docAddr.text.trim(),
      pmdcNumber: _pmdc.text.trim(),
      pmdcValid: RegExp(r'^[A-Z0-9\-]{4,}$', caseSensitive: false)
          .hasMatch(_pmdc.text.trim()),
      patientName: _patient.text.trim(),
      patientAge: _age.text.trim(),
      prescriptionDate: _date.text.trim(),
      diagnosis: _diag.text.trim(),
      medicines: List<MedicineEntry>.from(_meds),
      labTests: tests,
      followUpDate: _follow.text.trim(),
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<String> _saveJson(MedicalPrescriptionData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Medical');
    await out.create(recursive: true);
    final file = File('${out.path}/prescription_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return file.path;
  }

  Future<void> _setupReminders(MedicalPrescriptionData d) async {
    var id = 6000;
    for (final m in d.medicines.take(5)) {
      final t = m.name.isEmpty ? 'Medicine' : m.name;
      await NotificationService.instance.showNotification(
        id: id++,
        title: 'Medicine Reminder',
        body: 'Take $t ${m.frequency.isEmpty ? '' : '(${m.frequency})'}',
      );
    }
  }

  Future<void> _exportAndShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = _currentData();
      final title = d.patientName.isEmpty
          ? 'Prescription'
          : 'Prescription_${d.patientName.replaceAll(' ', '_')}';
      final pdf = await PdfService.instance.createPdfFromImages(widget.imagePaths, title);
      final thumb = await PdfService.instance.generateThumbnail(widget.imagePaths.first);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$title.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'medical_prescription',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: d.rawText,
          tags: const ['Medical', 'Prescription'],
        ),
      );
      final json = await _saveJson(d);
      await _setupReminders(d);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(pdf), XFile(json)],
        text: 'Prescription for ${d.patientName}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported PDF + JSON and setup reminders',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.green,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _currentData();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Medical Prescription',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
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
                  _preview(),
                  const SizedBox(height: 10),
                  _validationCard(d),
                  const SizedBox(height: 10),
                  _field('Doctor Name', _doc),
                  _field('Qualification', _qual),
                  _field('Clinic/Hospital', _clinic),
                  _field('Doctor Contact', _contact),
                  _field('Doctor Address', _docAddr, maxLines: 2),
                  _field('PMDC Number', _pmdc, isError: _pmdc.text.isNotEmpty && !d.pmdcValid),
                  _field('Patient Name', _patient),
                  _field('Patient Age', _age),
                  _field('Prescription Date', _date),
                  _field('Diagnosis/Symptoms', _diag, maxLines: 2),
                  _medicineSection(),
                  _field('Lab Tests', _tests, maxLines: 2),
                  _field('Follow Up Date', _follow),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _saveJson(_currentData()),
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
                          onPressed: _busy ? null : _exportAndShare,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Export & Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _preview() {
    final first = widget.imagePaths.first;
    return AspectRatio(
      aspectRatio: 0.72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(first), fit: BoxFit.cover),
            if (_showBoxes)
              CustomPaint(
                painter: _PrescriptionBoxesPainter(boxes: _boxes),
              ),
          ],
        ),
      ),
    );
  }

  Widget _validationCard(MedicalPrescriptionData d) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Checks', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('PMDC: ${d.pmdcValid ? 'Valid format' : 'Needs review'}',
              style: GoogleFonts.nunito(
                  color: d.pmdcValid ? AppColors.green : Colors.orange)),
          Text('Urdu support: ${d.urduText.isEmpty ? 'No Urdu detected' : 'Detected'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Signature: ${d.signatureDetected ? 'Detected' : 'Not clear'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _medicineSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF162232),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEB341)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Medicines', style: GoogleFonts.nunito(color: const Color(0xFFEEB341), fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _meds.add(const MedicineEntry())),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
              )
            ],
          ),
          ...List.generate(_meds.length, (i) {
            final m = _meds[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _inline('Name', m.name, (v) => _meds[i] = _meds[i].copyWith(name: v)),
                  _inline('Dosage', m.dosage, (v) => _meds[i] = _meds[i].copyWith(dosage: v)),
                  _inline('Frequency', m.frequency, (v) => _meds[i] = _meds[i].copyWith(frequency: v)),
                  _inline('Duration', m.duration, (v) => _meds[i] = _meds[i].copyWith(duration: v)),
                  _inline('Meal', m.mealInstruction, (v) => _meds[i] = _meds[i].copyWith(mealInstruction: v)),
                  if (m.genericSuggestion.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Generic: ${m.genericSuggestion}',
                          style: GoogleFonts.nunito(color: Colors.greenAccent, fontSize: 11)),
                    ),
                  if (m.interactionWarning)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Interaction warning',
                          style: GoogleFonts.nunito(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            );
          })
        ],
      ),
    );
  }

  Widget _inline(String label, String value, ValueChanged<String> onChanged) {
    final c = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: GoogleFonts.nunito(color: Colors.white54, fontSize: 12))),
          Expanded(
            child: TextField(
              controller: c,
              onChanged: (v) => setState(() => onChanged(v)),
              style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
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
                child: Text(label,
                    style: GoogleFonts.nunito(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => _copy(label, c.text.trim()),
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: Colors.white60,
              ),
            ],
          ),
          TextField(
            controller: c,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            style:
                GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF141E31),
              errorText: isError ? 'Invalid value' : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionBoxesPainter extends CustomPainter {
  final List<Rect> boxes;
  const _PrescriptionBoxesPainter({required this.boxes});

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty) return;
    Rect bounds = boxes.first;
    for (final b in boxes.skip(1)) {
      bounds = bounds.expandToInclude(b);
    }
    final sx = size.width / bounds.width;
    final sy = size.height / bounds.height;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gold.withValues(alpha: 0.7);
    for (final b in boxes) {
      final r = Rect.fromLTRB(
        (b.left - bounds.left) * sx,
        (b.top - bounds.top) * sy,
        (b.right - bounds.left) * sx,
        (b.bottom - bounds.top) * sy,
      );
      canvas.drawRect(r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PrescriptionBoxesPainter oldDelegate) =>
      oldDelegate.boxes != boxes;
}

