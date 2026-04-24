import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
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
    extends State<DocumentTemplateBuilderScreen>
    with SingleTickerProviderStateMixin {
  final _fields = <String, TextEditingController>{};
  final _listRows = <_RowModel>[];
  int _templateStyle = 0;
  late final TabController _tabController;

  String get _styleName =>
      _templateStyle == 0 ? 'Classic' : (_templateStyle == 1 ? 'Modern' : 'Bold');

  String get _today => DateTime.now().toIso8601String().split('T').first;

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

  Color _accentColorForTemplate() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) return AppColors.navyDark;
    if (key.contains('certificate')) return const Color(0xFFD4AF37);
    if (key.contains('business')) return AppColors.navyLight;
    if (key.contains('receipt')) return const Color(0xFF4CAF50);
    if (key.contains('whiteboard')) return const Color(0xFF2196F3);
    if (key.contains('table')) return const Color(0xFFFF9800);
    if (key.contains('meeting')) return const Color(0xFF1565C0);
    if (key.contains('resume') || key.contains('cv')) return const Color(0xFF9C27B0);
    return AppColors.navyDark;
  }

  Color _styleAccent(Color base, int style) {
    if (style == 1) return AppColors.navyLight;
    if (style == 2) return const Color(0xFF6C3FC5);
    return base;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTemplate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _fields.values) c.dispose();
    for (final r in _listRows) r.dispose();
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
    } else if (name == 'whiteboard' || name == 'whiteboard notes') {
      _addField('Meeting Title', 'Weekly Planning');
      _addField('Date', _today);
      _addField('Presenter', 'Team Lead');
      _addField('Main Notes', '1) Sprint goals\n2) Risks and blockers\n3) Action items');
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
      _addField('Title', widget.templateName.toUpperCase());
      _addField('Name', 'Your Name');
      _addField('Date', _today);
      _addField('Details', 'Add your details here');
    }
  }

  void _addField(String key, String initial) {
    _fields[key] = TextEditingController(text: initial);
  }

  String _colorToHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final accent = _accentColorForTemplate();
    final styleAccent = _styleAccent(accent, _templateStyle);
    final accentPdf = PdfColor.fromHex(_colorToHex(styleAccent));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header band ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: pw.BoxDecoration(
                color: accentPdf.shade(0.12),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 5,
                    height: 38,
                    decoration: pw.BoxDecoration(
                      color: accentPdf,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SCANONLY',
                            style: pw.TextStyle(
                              color: accentPdf,
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 2,
                            )),
                        pw.Text('$_styleName · $_docLabel',
                            style: pw.TextStyle(
                              color: accentPdf,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date', style: pw.TextStyle(color: accentPdf, fontSize: 7)),
                      pw.Text(_today,
                          style: pw.TextStyle(
                              color: accentPdf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            // ── Document Title ──
            pw.Row(
              children: [
                if (_templateStyle == 2)
                  pw.Container(
                    width: 5,
                    height: 32,
                    margin: const pw.EdgeInsets.only(right: 10),
                    decoration: pw.BoxDecoration(
                        color: accentPdf, borderRadius: pw.BorderRadius.circular(3)),
                  ),
                pw.Expanded(
                  child: pw.Text(
                    widget.templateName.toUpperCase(),
                    textAlign: _templateStyle == 1 ? pw.TextAlign.center : pw.TextAlign.left,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: accentPdf,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            // ── Fields block ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: accentPdf.shade(_templateStyle == 2 ? 0.16 : 0.06),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: accentPdf.shade(0.25), width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _fields.entries
                    .map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 110,
                                child: pw.Text(e.key,
                                    style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        color: accentPdf)),
                              ),
                              pw.Text(': ',
                                  style: pw.TextStyle(fontSize: 10, color: accentPdf)),
                              pw.Expanded(
                                  child: pw.Text(e.value.text,
                                      style: const pw.TextStyle(fontSize: 10))),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            // ── Table rows ──
            if (_listRows.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.TableHelper.fromTextArray(
                headers: _tableHeaders(),
                data: _listRows.map((r) => [r.a.text, r.b.text, r.c.text]).toList(),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: accentPdf),
                cellHeight: 26,
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.Spacer(),
            pw.Divider(color: accentPdf.shade(0.3), thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by ScanOnly',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text(_signatureLabel(),
                    style: pw.TextStyle(
                        fontSize: 9, color: accentPdf, fontWeight: pw.FontWeight.bold)),
              ],
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
      scanType: widget.scanType,
      pageCount: 1,
      fileSizeMB: bytes.length / (1024 * 1024),
      createdAt: DateTime.now(),
      tags: const [],
    );
    await DatabaseService.instance.insertDocument(doc);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Saved: ${p.basename(outPath)}'),
          backgroundColor: AppColors.green),
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
        scanType: widget.scanType,
        pageCount: 1,
        fileSizeMB: File(outPath).lengthSync() / (1024 * 1024),
        createdAt: DateTime.now(),
        tags: const [],
      );
      await DatabaseService.instance.insertDocument(doc);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Exported: ${p.basename(outPath)}'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.navyDark.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Iconsax.export, color: AppColors.navyDark, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Export Document',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.navyDark)),
                  Text('Choose your preferred format',
                      style: GoogleFonts.nunito(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
              const SizedBox(height: 16),
              _exportTile(Icons.picture_as_pdf, 'PDF Document', const Color(0xFFE53935), _savePdf),
              _exportTile(Icons.table_chart_rounded, 'Excel Spreadsheet (.xlsx)',
                  const Color(0xFF217346), () => _exportAs('excel')),
              _exportTile(Icons.description_rounded, 'Word Document (.docx)',
                  const Color(0xFF2B579A), () => _exportAs('word')),
              _exportTile(Icons.slideshow_rounded, 'PowerPoint (.pptx)',
                  const Color(0xFFD24726), () => _exportAs('ppt')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.textMuted),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  List<String> _tableHeaders() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('receipt')) return const ['Item', 'Qty', 'Amount'];
    if (key.contains('table')) {
      return [
        _fields['Column 1']?.text.isNotEmpty == true ? _fields['Column 1']!.text : 'Col 1',
        _fields['Column 2']?.text.isNotEmpty == true ? _fields['Column 2']!.text : 'Col 2',
        _fields['Column 3']?.text.isNotEmpty == true ? _fields['Column 3']!.text : 'Col 3',
      ];
    }
    if (key.contains('whiteboard')) return const ['Point', 'Owner', 'Status'];
    return const ['Field', 'Value', 'Note'];
  }

  String _signatureLabel() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) return 'Authorized Signatories __________________';
    if (key.contains('certificate')) return 'Authorized By __________________';
    if (key.contains('business')) return 'Approved By __________________';
    if (key.contains('receipt')) return 'Cashier Signature __________________';
    if (key.contains('whiteboard')) return 'Meeting Lead __________________';
    if (key.contains('table')) return 'Reviewed By __________________';
    if (key.contains('meeting')) return 'Facilitator __________________';
    if (key.contains('resume') || key.contains('cv'))
      return 'Applicant Signature __________________';
    return 'Authorized Signature __________________';
  }

  Widget _rowEditor(_RowModel r) {
    final accent = _accentColorForTemplate();
    final headers = _tableHeaders();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(child: _miniField(r.a, headers[0], accent)),
          const SizedBox(width: 8),
          Expanded(child: _miniField(r.b, headers[1], accent)),
          const SizedBox(width: 8),
          Expanded(child: _miniField(r.c, headers[2], accent)),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() {
              r.dispose();
              _listRows.remove(r);
            }),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController c, String label, Color accent) {
    return TextField(
      controller: c,
      style: GoogleFonts.nunito(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent, width: 1.5)),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = _accentColorForTemplate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.templateName} Template',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
          Text(_docLabel,
              style: GoogleFonts.nunito(
                  color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: _showExportSheet,
            icon: const Icon(Icons.download_rounded, color: AppColors.gold, size: 18),
            label: Text('Export',
                style: GoogleFonts.nunito(
                    color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AppColors.navyDark,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white54,
              indicatorColor: AppColors.gold,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle:
                  GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.edit_note_rounded, size: 16), text: 'Edit'),
                Tab(
                    icon: Icon(Icons.picture_as_pdf_rounded, size: 16),
                    text: 'PDF Preview'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFormTab(accent), _buildPdfTab()],
      ),
    );
  }

  // ─── TAB 1: Edit Form ────────────────────────────────────────────────────

  Widget _buildFormTab(Color accent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Style selector
        _sectionLabel('Choose Style', Iconsax.paintbucket),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) {
            final selected = _templateStyle == i;
            final sa = _styleAccent(accent, i);
            final names = ['Classic', 'Modern', 'Bold'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 10),
                child: GestureDetector(
                  onTap: () => setState(() => _templateStyle = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? sa.withOpacity(0.07) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected ? sa : Colors.black12,
                          width: selected ? 2 : 1),
                      boxShadow: selected
                          ? [BoxShadow(color: sa.withOpacity(0.18), blurRadius: 10)]
                          : [],
                    ),
                    child: Column(children: [
                      _styleMiniDoc(sa, i),
                      const SizedBox(height: 6),
                      Text(names[i],
                          style: GoogleFonts.nunito(
                              color: selected ? sa : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Fields card
        _sectionLabel('Document Details', Iconsax.edit),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: _fields.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: e.value,
                        maxLines: e.value.text.contains('\n') ? null : 1,
                        style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: e.key,
                          labelStyle: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600),
                          prefixIcon: Icon(Icons.edit_note_rounded, color: accent, size: 20),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: accent.withOpacity(0.2))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: accent.withOpacity(0.15))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: accent, width: 1.5)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ))
                .toList(),
          ),
        ),

        // Rows
        if (_listRows.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel('Table Rows', Icons.table_chart_rounded),
          const SizedBox(height: 10),
          ..._listRows.map((r) => _rowEditor(r)),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _listRows.add(_RowModel('Item', '1', '0'))),
          icon: Icon(Icons.add_rounded, color: accent, size: 18),
          label: Text('Add Row',
              style: GoogleFonts.nunito(
                  color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: accent.withOpacity(0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text('View PDF',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.navyDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showExportSheet,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('Export',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navyDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── TAB 2: Inline PDF Preview ──────────────────────────────────────────

  Widget _buildPdfTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.templateName} · PDF',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.navyDark)),
              Text('Updates automatically as you edit',
                  style: GoogleFonts.nunito(
                      color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: _showExportSheet,
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text('Export',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navyDark,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: PdfPreview(
          key: ValueKey(
            _fields.entries.map((e) => e.value.text).join('|') +
                _listRows.map((r) => r.a.text + r.b.text + r.c.text).join('|') +
                _templateStyle.toString(),
          ),
          build: (_) => _buildPdfBytes(),
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          useActions: true,
          initialPageFormat: PdfPageFormat.a4,
          pdfPreviewPageDecoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
        ),
      ),
    ]);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.navyDark),
      const SizedBox(width: 7),
      Expanded(child: Text(title,
          style: GoogleFonts.nunito(
              color: AppColors.navyDark, fontWeight: FontWeight.w900, fontSize: 15),
          overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _styleMiniDoc(Color sa, int i) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
          color: sa.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment:
            i == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (i == 2)
            Row(children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration:
                      BoxDecoration(color: sa, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Expanded(
                  child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: sa.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3)))),
            ])
          else
            Container(
              height: 6,
              width: i == 1 ? 55 : double.infinity,
              decoration: BoxDecoration(
                  color: sa.withOpacity(0.5), borderRadius: BorderRadius.circular(3)),
            ),
          const SizedBox(height: 4),
          Container(
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 3),
          Container(
              height: 4,
              width: 50,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(3))),
        ],
      ),
    );
  }
}

class _RowModel {
  final TextEditingController a, b, c;
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
