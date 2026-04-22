import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/template_export_service.dart';
import '../theme.dart';

class DocumentTemplateBuilderScreen extends StatefulWidget {
  final String templateName;
  final String scanType;

  const DocumentTemplateBuilderScreen({
    super.key,
    required this.templateName,
    this.scanType = 'document',
  });

  @override
  State<DocumentTemplateBuilderScreen> createState() =>
      _DocumentTemplateBuilderScreenState();
}

class _DocumentTemplateBuilderScreenState
    extends State<DocumentTemplateBuilderScreen> {
  final _fields = <String, TextEditingController>{};
  final _listRows = <_RowModel>[];
  int _templateStyle = 0;

  String get _styleName =>
      _templateStyle == 0 ? 'Classic' : (_templateStyle == 1 ? 'Modern' : 'Bold');

  String get _today =>
      DateTime.now().toIso8601String().split('T').first;

  String get _docLabel {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) return 'LEGAL AGREEMENT';
    if (key.contains('certificate')) return 'CERTIFICATE OF ACHIEVEMENT';
    if (key.contains('business')) return 'BUSINESS IDENTITY';
    if (key.contains('receipt')) return 'PAYMENT RECORD';
    if (key.contains('whiteboard')) return 'MEETING NOTES';
    if (key.contains('table')) return 'STRUCTURED DATA SHEET';
    if (key.contains('meeting')) return 'MEETING MINUTES';
    if (key.contains('resume') || key.contains('cv')) return 'CURRICULUM VITAE';
    return 'PROFESSIONAL DOCUMENT';
  }

  @override
  void initState() {
    super.initState();
    _initTemplate();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final r in _listRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _initTemplate() {
    final name = widget.templateName.toLowerCase();
    if (name == 'contract') {
      _addField('Title', 'SERVICE AGREEMENT');
      _addField('Party A', 'Company Name');
      _addField('Party B', 'Client Name');
      _addField('Start Date', _today);
      _addField('End Date', '2026-12-31');
      _addField('Amount', '50000');
      _addField('Terms', 'Both parties agree to terms and conditions.');
    } else if (name == 'certificate') {
      _addField('Certificate Title', 'CERTIFICATE OF ACHIEVEMENT');
      _addField('Awarded To', 'Recipient Name');
      _addField('Awarded By', 'Organization Name');
      _addField('Reason', 'Outstanding Performance in 2026');
      _addField('Date', _today);
      _addField('Authorized By', 'Director / Principal');
    } else if (name == 'business card') {
      _addField('Full Name', 'John Doe');
      _addField('Designation', 'Sales Manager');
      _addField('Company', 'ScanOnly Pvt Ltd');
      _addField('Phone', '+92 300 0000000');
      _addField('Email', 'john@scanonly.com');
      _addField('Address', 'Karachi, Pakistan');
    } else if (name == 'receipt') {
      _addField('Store Name', 'ScanOnly Mart');
      _addField('Date', _today);
      _addField('Receipt #', 'RCPT-2201');
      _addField('Cashier', 'Counter 02');
      _addField('Tax/GST', '120');
      _addField('Payment Method', 'Cash');
      _listRows.add(_RowModel('Item', '1', '500'));
    } else if (name == 'whiteboard notes') {
      _addField('Meeting Title', 'Weekly Planning');
      _addField('Date', _today);
      _addField('Presenter', 'Team Lead');
      _addField('Main Notes',
          '1) Sprint goals\n2) Risks and blockers\n3) Action items');
    } else if (name == 'table sheet') {
      _addField('Sheet Title', 'Attendance Table');
      _addField('Column 1', 'Name');
      _addField('Column 2', 'Status');
      _addField('Column 3', 'Remarks');
      _listRows.add(_RowModel('Ali', 'Present', '-'));
      _listRows.add(_RowModel('Sara', 'Absent', 'Sick leave'));
    } else if (name == 'meeting notes') {
      _addField('Meeting Title', 'Project Kickoff');
      _addField('Date', _today);
      _addField('Location', 'Conference Room A');
      _addField('Facilitator', 'Team Lead');
      _addField('Attendees', 'Ali, Sara, Ahmed, Fatima');
      _addField('Agenda', '1) Project overview\n2) Roles\n3) Timeline');
      _addField('Action Items', '1) Setup repo\n2) Share docs\n3) Next meeting');
    } else if (name == 'resume / cv') {
      _addField('Full Name', 'John Doe');
      _addField('Email', 'john@example.com');
      _addField('Phone', '+92 300 0000000');
      _addField('Address', 'Karachi, Pakistan');
      _addField('Objective', 'Motivated professional seeking growth opportunities.');
      _addField('Education', 'BS Computer Science - University of Karachi (2022)');
      _addField('Experience', 'Software Engineer - ScanOnly Pvt Ltd (2022-Present)');
      _addField('Skills', 'Flutter, Dart, Firebase, REST APIs, Git');
    } else {
      // Generic fallback
      _addField('Title', widget.templateName.toUpperCase());
      _addField('Name', 'Your Name');
      _addField('Date', _today);
      _addField('Details', 'Add your details here');
    }
  }

  void _addField(String key, String initial) {
    _fields[key] = TextEditingController(text: initial);
  }

  // ✅ FIXED: toARGB32() crash → .value use karo (stable across all Flutter versions)
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final title = widget.templateName.toUpperCase();
    final accent = _accentColorForTemplate();
    final styleAccent = _styleAccent(accent, _templateStyle);
    final accentPdf = PdfColor.fromHex(_colorToHex(styleAccent)); // ✅ FIXED

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header band
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: pw.BoxDecoration(
                color: accentPdf.shade(0.14),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 8,
                    height: 34,
                    decoration: pw.BoxDecoration(
                      color: accentPdf,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      'SCANONLY $_styleName $_docLabel',
                      style: pw.TextStyle(
                        color: accentPdf,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  pw.Text(
                    _today,
                    style: pw.TextStyle(
                      color: accentPdf,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            // Title row
            pw.Row(
              children: [
                if (_templateStyle == 2)
                  pw.Container(
                    width: 6,
                    height: 30,
                    margin: const pw.EdgeInsets.only(right: 8),
                    decoration: pw.BoxDecoration(color: accentPdf),
                  ),
                pw.Expanded(
                  child: pw.Text(
                    title,
                    textAlign: _templateStyle == 1
                        ? pw.TextAlign.center
                        : pw.TextAlign.left,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: accentPdf,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            // Fields block
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: accentPdf.shade(_templateStyle == 2 ? 0.16 : 0.08),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _fields.entries
                    .map(
                      (e) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          '${e.key}: ${e.value.text}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            pw.SizedBox(height: 8),
            // Notes bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accentPdf.shade(0.35)),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Notes: $_docLabel | Generated from "$_styleName" style template.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            // Table (if rows exist)
            if (_listRows.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: _tableHeaders(),
                data: _listRows
                    .map((r) => [r.a.text, r.b.text, r.c.text])
                    .toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: accentPdf,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: accentPdf.shade(0.12),
                ),
                cellHeight: 28,
              ),
            ],
            pw.Spacer(),
            pw.Divider(color: accentPdf.shade(0.35)),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                _signatureLabel(),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: accentPdf,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  Future<void> _savePdf() async {
    final bytes = await _buildPdfBytes();
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/Templates');
    await outDir.create(recursive: true);
    final fileName =
        '${widget.templateName.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outPath = p.join(outDir.path, fileName);
    await File(outPath).writeAsBytes(bytes);

    final doc = DocumentModel(
      name: fileName,
      filePath: outPath,
      fileType: 'pdf',
      scanType: widget.scanType, // ✅ FIXED: hardcoded 'document' ki jagah
      pageCount: 1,
      fileSizeMB: bytes.length / (1024 * 1024),
      createdAt: DateTime.now(),
      tags: const [],
    );
    await DatabaseService.instance.insertDocument(doc);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to library: ${p.basename(outPath)}'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Future<void> _exportAs(String format) async {
    final fields = _fields.map((k, v) => MapEntry(k, v.text));
    final rows = _listRows.map((r) => [r.a.text, r.b.text, r.c.text]).toList();
    final stem = widget.templateName.replaceAll(' ', '_').toLowerCase();

    try {
      String outPath;
      switch (format) {
        case 'excel':
          outPath = await TemplateExportService.instance
              .exportExcel(stem: stem, fields: fields, tableRows: rows);
          break;
        case 'word':
          outPath = await TemplateExportService.instance
              .exportWord(stem: stem, fields: fields, tableRows: rows);
          break;
        case 'ppt':
          outPath = await TemplateExportService.instance
              .exportPpt(stem: stem, fields: fields, tableRows: rows);
          break;
        default:
          return;
      }

      final ext = outPath.split('.').last.toLowerCase();
      final doc = DocumentModel(
        name: p.basename(outPath),
        filePath: outPath,
        fileType: ext,
        scanType: widget.scanType, // ✅ FIXED: hardcoded ki jagah dynamic
        pageCount: 1,
        fileSizeMB: File(outPath).lengthSync() / (1024 * 1024),
        createdAt: DateTime.now(),
        tags: const [],
      );
      await DatabaseService.instance.insertDocument(doc);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported as ${format.toUpperCase()}: ${p.basename(outPath)}',
          ),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export As',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _exportTile(
                Icons.picture_as_pdf,
                'PDF',
                'pdf',
                AppColors.navyDark,
                _savePdf,
              ),
              _exportTile(
                Icons.table_chart_rounded,
                'Excel (.xlsx)',
                'excel',
                const Color(0xFF217346),
                () => _exportAs('excel'),
              ),
              _exportTile(
                Icons.description_rounded,
                'Word (.docx)',
                'word',
                const Color(0xFF2B579A),
                () => _exportAs('word'),
              ),
              _exportTile(
                Icons.slideshow_rounded,
                'PowerPoint (.pptx)',
                'ppt',
                const Color(0xFFD24726),
                () => _exportAs('ppt'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportTile(
    IconData icon,
    String label,
    String format,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12), // ✅ FIXED
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _previewPdf() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.navyDark,
            foregroundColor: Colors.white,
            title: Text(
              '${widget.templateName} Preview',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
          body: PdfPreview(
            build: (_) => _buildPdfBytes(),
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColorForTemplate();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white, // ✅ back button bhi white hoga
        title: Text(
          '${widget.templateName} Template',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Style selector label
          Text(
            'Choose Style',
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          // Style cards row
          Row(
            children: List.generate(3, (i) {
              final selected = _templateStyle == i;
              final styleAccent = _styleAccent(accent, i);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _templateStyle = i),
                    child: AnimatedContainer( // ✅ smooth selection animation
                      duration: const Duration(milliseconds: 200),
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.gold : Colors.black12,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: styleAccent.withOpacity(0.16), // ✅ FIXED
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.08), // ✅ FIXED
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 7,
                              width: i == 1 ? 70 : double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.08), // ✅ FIXED
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              i == 0
                                  ? 'Classic'
                                  : (i == 1 ? 'Modern' : 'Bold'),
                              style: GoogleFonts.nunito(
                                color: styleAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Live preview card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _styleAccent(accent, _templateStyle).withOpacity(0.2), // ✅ FIXED
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08), // ✅ FIXED
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _canvaPreviewBlock(),
          ),
          const SizedBox(height: 12),
          // Fields editor card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withOpacity(0.22), // ✅ FIXED
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05), // ✅ FIXED
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _fields.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: e.key,
                          prefixIcon: Icon(
                            Icons.edit_note_rounded,
                            color: accent,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: accent.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: accent, width: 1.5),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Rows editor (receipt / table sheet)
          if (_listRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Rows',
              style: GoogleFonts.nunito(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            ..._listRows.map((r) => _rowEditor(r)),
          ],
          // Add row button (always shown so user can add rows)
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _listRows.add(_RowModel('Item', '1', '0')));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Row'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewPdf,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('Preview PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showExportSheet,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _rowEditor(_RowModel r) {
    final headers = _tableHeaders();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: r.a,
              decoration: InputDecoration(
                // ✅ Column headers se label aata hai
                labelText: headers[0],
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: r.b,
              decoration: InputDecoration(
                labelText: headers[1], // ✅
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: r.c,
              decoration: InputDecoration(
                labelText: headers[2], // ✅
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              r.dispose();
              _listRows.remove(r);
            }),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _canvaPreviewBlock() {
    final accent = _accentColorForTemplate();
    final styleAccent = _styleAccent(accent, _templateStyle);
    final previewBg = _templateStyle == 1
        ? const Color(0xFFF7FAFF)
        : (_templateStyle == 2 ? const Color(0xFFF9F4FF) : Colors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: styleAccent.withOpacity(0.12), // ✅ FIXED
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 26,
                decoration: BoxDecoration(
                  color: styleAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_docLabel Layout',
                  style: GoogleFonts.nunito(
                    color: styleAccent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                _today,
                style: GoogleFonts.nunito(
                  color: styleAccent.withOpacity(0.85), // ✅ FIXED
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Live preview label + template badge
        Row(
          children: [
            Text(
              'Live Preview',
              style: GoogleFonts.nunito(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: styleAccent.withOpacity(0.14), // ✅ FIXED
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.templateName,
                style: GoogleFonts.nunito(
                  color: styleAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Document title block
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_templateStyle == 1 ? 14 : 12),
          decoration: BoxDecoration(
            color: _templateStyle == 0
                ? previewBg
                : styleAccent.withOpacity(
                    _templateStyle == 2 ? 0.14 : 0.06, // ✅ FIXED
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: styleAccent.withOpacity(0.22), // ✅ FIXED
            ),
          ),
          child: Row(
            children: [
              if (_templateStyle == 2)
                Container(
                  width: 6,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: styleAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              Expanded(
                child: Text(
                  '$_styleName ${widget.templateName.toUpperCase()}',
                  textAlign: _templateStyle == 1
                      ? TextAlign.center
                      : TextAlign.start,
                  style: GoogleFonts.nunito(
                    color: styleAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Fields preview
        ..._fields.entries.take(6).map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _templateStyle == 1 ? 95 : 110,
                      child: Text(
                        e.key,
                        style: GoogleFonts.nunito(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.text,
                        textAlign: _templateStyle == 1
                            ? TextAlign.right
                            : TextAlign.left,
                        style: GoogleFonts.nunito(
                          fontWeight: _templateStyle == 2
                              ? FontWeight.w800
                              : FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        // Table preview (if rows)
        if (_listRows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: styleAccent.withOpacity(0.12), // ✅ FIXED
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: _tableHeaders()
                  .map(
                    (h) => Expanded(
                      child: Text(
                        h,
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          ..._listRows.take(4).map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.a.text,
                          style: GoogleFonts.nunito(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.b.text,
                          style: GoogleFonts.nunito(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.c.text,
                          style: GoogleFonts.nunito(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
        const SizedBox(height: 10),
        Divider(color: styleAccent.withOpacity(0.25)), // ✅ FIXED
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _signatureLabel(),
            style: GoogleFonts.nunito(
              color: styleAccent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Color _accentColorForTemplate() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) return AppColors.navyDark;
    if (key.contains('certificate')) return const Color(0xFFD4AF37);
    if (key.contains('business')) return AppColors.purple;
    if (key.contains('receipt')) return AppColors.green;
    if (key.contains('whiteboard')) return AppColors.blue;
    if (key.contains('table')) return AppColors.gold;
    if (key.contains('meeting')) return AppColors.navyMid;
    if (key.contains('resume') || key.contains('cv')) return AppColors.purple;
    return AppColors.navyMid;
  }

  Color _styleAccent(Color base, int style) {
    if (style == 1) return AppColors.blue;
    if (style == 2) return AppColors.purple;
    return base;
  }

  // ✅ FIXED: Table Sheet headers ab user ke fields se aate hain
  List<String> _tableHeaders() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('receipt')) return const ['Item', 'Qty', 'Amount'];
    if (key.contains('table')) {
      return [
        _fields['Column 1']?.text.isNotEmpty == true
            ? _fields['Column 1']!.text
            : 'Col 1',
        _fields['Column 2']?.text.isNotEmpty == true
            ? _fields['Column 2']!.text
            : 'Col 2',
        _fields['Column 3']?.text.isNotEmpty == true
            ? _fields['Column 3']!.text
            : 'Col 3',
      ];
    }
    if (key.contains('whiteboard')) return const ['Point', 'Owner', 'Status'];
    return const ['Field', 'Value', 'Note'];
  }

  String _signatureLabel() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) return 'Authorized Signatories __________________';
    if (key.contains('certificate')) return 'Authorized By __________________';
    if (key.contains('business')) return 'Card Approved By __________________';
    if (key.contains('receipt')) return 'Cashier Signature __________________';
    if (key.contains('whiteboard')) return 'Meeting Lead Signature __________________';
    if (key.contains('table')) return 'Reviewed By __________________';
    if (key.contains('meeting')) return 'Facilitator Signature __________________';
    if (key.contains('resume') || key.contains('cv')) return 'Applicant Signature __________________';
    return 'Authorized Signature __________________';
  }
}

class _RowModel {
  final TextEditingController a;
  final TextEditingController b;
  final TextEditingController c;

  _RowModel(String av, String bv, String cv)
      : a = TextEditingController(text: av),
        b = TextEditingController(text: bv),
        c = TextEditingController(text: cv);

  void dispose() {
    a.dispose();
    b.dispose();
    c.dispose();
  }
}