import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/academic_certificate_data.dart';
import '../models/document_model.dart';
import '../services/academic_certificate_ocr_service.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class AcademicCertificateResultScreen extends StatefulWidget {
  final List<String> imagePaths;

  const AcademicCertificateResultScreen({super.key, required this.imagePaths});

  @override
  State<AcademicCertificateResultScreen> createState() =>
      _AcademicCertificateResultScreenState();
}

class _AcademicCertificateResultScreenState
    extends State<AcademicCertificateResultScreen> {
  bool _loading = true;
  bool _busy = false;
  AcademicCertificateData _data = const AcademicCertificateData();

  final _holder = TextEditingController();
  final _father = TextEditingController();
  final _roll = TextEditingController();
  final _reg = TextEditingController();
  final _title = TextEditingController();
  final _major = TextEditingController();
  final _inst = TextEditingController();
  final _board = TextEditingController();
  final _level = TextEditingController();
  final _year = TextEditingController();
  final _grade = TextEditingController();
  final _issue = TextEditingController();
  final _sig = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    for (final c in [
      _holder,
      _father,
      _roll,
      _reg,
      _title,
      _major,
      _inst,
      _board,
      _level,
      _year,
      _grade,
      _issue,
      _sig,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final d = await AcademicCertificateOcrService.instance.extractFromPages(
        widget.imagePaths,
      );
      _data = d;
      _holder.text = d.holderName;
      _father.text = d.fatherName;
      _roll.text = d.rollNumber;
      _reg.text = d.registrationNumber;
      _title.text = d.degreeTitle;
      _major.text = d.fieldOfStudy;
      _inst.text = d.instituteName;
      _board.text = d.boardRecognition;
      _level.text = d.qualificationLevel;
      _year.text = d.yearOfPassing;
      _grade.text = d.gradeCgpaDivision;
      _issue.text = d.issueDate;
      _sig.text = d.signatureAreaHint;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AcademicCertificateData _current() => _data.copyWith(
        holderName: _holder.text.trim(),
        fatherName: _father.text.trim(),
        rollNumber: _roll.text.trim(),
        registrationNumber: _reg.text.trim(),
        degreeTitle: _title.text.trim(),
        fieldOfStudy: _major.text.trim(),
        instituteName: _inst.text.trim(),
        boardRecognition: _board.text.trim(),
        qualificationLevel: _level.text.trim(),
        yearOfPassing: _year.text.trim(),
        gradeCgpaDivision: _grade.text.trim(),
        issueDate: _issue.text.trim(),
        signatureAreaHint: _sig.text.trim(),
      );

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<String> _saveJson(AcademicCertificateData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Academic');
    await out.create(recursive: true);
    final file = File('${out.path}/academic_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return file.path;
  }

  Future<void> _exportShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = _current();
      final title = d.holderName.isEmpty ? 'Academic_Certificate' : d.holderName.replaceAll(' ', '_');
      final pdf = await PdfService.instance.createPdfFromImages(widget.imagePaths, title);
      final thumb = await PdfService.instance.generateThumbnail(widget.imagePaths.first);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$title.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'academic_certificate',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: d.rawText,
          tags: const ['Academic', 'Degree'],
        ),
      );
      final json = await _saveJson(d);
      if (!mounted) return;
      await Share.shareXFiles([XFile(pdf), XFile(json)], text: 'Academic portfolio');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported PDF + JSON', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.green,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _current();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Degree & Certificate', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _verificationCard(d),
                  const SizedBox(height: 10),
                  _preview(),
                  const SizedBox(height: 10),
                  _field('Holder Name', _holder),
                  _field('Father Name', _father),
                  _field('Roll Number', _roll),
                  _field('Registration Number', _reg),
                  _field('Degree/Certificate Title', _title),
                  _field('Field of Study / Major', _major),
                  _field('University/Institute', _inst),
                  _field('Board / HEC', _board),
                  _field('Qualification Level', _level),
                  _field('Year of Passing', _year),
                  _field('Grade / CGPA / Division', _grade),
                  _field('Date of Issue', _issue),
                  _field('Registrar Signature Area', _sig),
                  const SizedBox(height: 10),
                  _fakeFlagCard(d.fakeFlags),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _saveJson(_current()),
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
                          onPressed: _busy ? null : _exportShare,
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

  Widget _verificationCard(AcademicCertificateData d) {
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
          Text('Verification', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('HEC QR: ${d.hecQrDetected ? 'Detected' : 'Not found'}', style: GoogleFonts.nunito(color: d.hecQrDetected ? AppColors.green : Colors.orange)),
          Text('HEC Status: ${d.hecVerified ? 'Likely verified' : 'Needs manual check'}', style: GoogleFonts.nunito(color: d.hecVerified ? AppColors.green : Colors.orange)),
          Text('Watermark/Security: ${d.watermarkDetected ? 'Detected' : 'Not clear'}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Orientation: ${d.orientation}', style: GoogleFonts.nunito(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _preview() {
    return AspectRatio(
      aspectRatio: 1.45,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(widget.imagePaths.first), fit: BoxFit.cover),
      ),
    );
  }

  Widget _fakeFlagCard(List<String> flags) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF221617),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fake Degree Detection Flags', style: GoogleFonts.nunito(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (flags.isEmpty)
            Text('No obvious flags', style: GoogleFonts.nunito(color: Colors.white70))
          else
            ...flags.map((f) => Text('• $f', style: GoogleFonts.nunito(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: GoogleFonts.nunito(color: Colors.white70, fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: () => _copy(label, c.text.trim()),
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: Colors.white60,
              ),
            ],
          ),
          TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF141E31),
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

