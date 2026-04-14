import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme.dart';

class DocumentTemplateBuilderScreen extends StatefulWidget {
  final String templateName;
  const DocumentTemplateBuilderScreen({super.key, required this.templateName});

  @override
  State<DocumentTemplateBuilderScreen> createState() =>
      _DocumentTemplateBuilderScreenState();
}

class _DocumentTemplateBuilderScreenState
    extends State<DocumentTemplateBuilderScreen> {
  final _fields = <String, TextEditingController>{};
  final _listRows = <_RowModel>[];
  int _templateStyle = 0;
  String get _styleName => _templateStyle == 0
      ? 'Classic'
      : (_templateStyle == 1 ? 'Modern' : 'Bold');
  String get _today => DateTime.now().toIso8601String().split('T').first;
  String get _docLabel {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) return 'LEGAL AGREEMENT';
    if (key.contains('business')) return 'BUSINESS IDENTITY';
    if (key.contains('receipt')) return 'PAYMENT RECORD';
    if (key.contains('whiteboard')) return 'MEETING NOTES';
    if (key.contains('table')) return 'STRUCTURED DATA SHEET';
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
      _addField('Start Date', '2026-04-14');
      _addField('End Date', '2026-12-31');
      _addField('Amount', '50000');
      _addField('Terms', 'Both parties agree to terms and conditions.');
    } else if (name == 'business card') {
      _addField('Full Name', 'John Doe');
      _addField('Designation', 'Sales Manager');
      _addField('Company', 'ScanOnly Pvt Ltd');
      _addField('Phone', '+92 300 0000000');
      _addField('Email', 'john@scanonly.com');
      _addField('Address', 'Karachi, Pakistan');
    } else if (name == 'receipt') {
      _addField('Store Name', 'ScanOnly Mart');
      _addField('Date', '2026-04-14');
      _addField('Receipt #', 'RCPT-2201');
      _addField('Cashier', 'Counter 02');
      _addField('Tax/GST', '120');
      _addField('Payment Method', 'Cash');
      _listRows.add(_RowModel('Item', '1', '500'));
    } else if (name == 'whiteboard notes') {
      _addField('Meeting Title', 'Weekly Planning');
      _addField('Date', '2026-04-14');
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
    }
  }

  void _addField(String key, String initial) {
    _fields[key] = TextEditingController(text: initial);
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final title = widget.templateName.toUpperCase();
    final accent = _styleAccent(_accentColorForTemplate(), _templateStyle);
    final accentHex =
        '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final accentPdf = PdfColor.fromHex(accentHex);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Professional header band
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        child: pw.Text('${e.key}: ${e.value.text}'),
                      ),
                    )
                    .toList(),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accentPdf.shade(0.35)),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Notes: $_docLabel | Generated from selected "$_styleName" style template.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            if (_listRows.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: _tableHeaders(),
                data: _listRows
                    .map((r) => [r.a.text, r.b.text, r.c.text])
                    .toList(),
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
    final outPath = p.join(
      outDir.path,
      '${widget.templateName.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(outPath).writeAsBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: ${p.basename(outPath)}'),
        backgroundColor: AppColors.green,
      ),
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
            title: Text(
              '${widget.templateName} PDF Preview',
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text(
          '${widget.templateName} Template',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'Choose style',
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final selected = _templateStyle == i;
              final styleAccent = _styleAccent(accent, i);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _templateStyle = i),
                    child: Container(
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.gold : Colors.black12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: styleAccent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 7,
                              width: i == 1 ? 70 : double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              i == 0 ? 'Classic' : (i == 1 ? 'Modern' : 'Bold'),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _styleAccent(accent, _templateStyle).withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _canvaPreviewBlock(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                          prefixIcon:
                              Icon(Icons.edit_note_rounded, color: accent),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_listRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Rows',
                style: GoogleFonts.nunito(
                    color: AppColors.navyDark, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ..._listRows.map((r) => _rowEditor(r)),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _listRows.add(_RowModel('Item', '1', '0')));
              },
              icon: const Icon(Icons.add),
              label: const Text('Add row'),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewPdf,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('Preview PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Save PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rowEditor(_RowModel r) {
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
            decoration: const InputDecoration(
              labelText: 'Col 1',
              prefixIcon: Icon(Icons.title_rounded),
            ),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
            controller: r.b,
            decoration: const InputDecoration(
              labelText: 'Col 2',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
            controller: r.c,
            decoration: const InputDecoration(
              labelText: 'Col 3',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            onChanged: (_) => setState(() {}),
          )),
          IconButton(
            onPressed: () => setState(() {
              r.dispose();
              _listRows.remove(r);
            }),
            icon: const Icon(Icons.delete_outline),
          )
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: styleAccent.withValues(alpha: 0.12),
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
                  color: styleAccent.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
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
                color: styleAccent.withValues(alpha: 0.14),
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_templateStyle == 1 ? 14 : 12),
          decoration: BoxDecoration(
            color: _templateStyle == 0
                ? previewBg
                : styleAccent.withValues(
                    alpha: _templateStyle == 2 ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: styleAccent.withValues(alpha: 0.22),
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
                  textAlign:
                      _templateStyle == 1 ? TextAlign.center : TextAlign.start,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (_listRows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: styleAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(_tableHeaders()[0],
                        style:
                            GoogleFonts.nunito(fontWeight: FontWeight.w800))),
                Expanded(
                    child: Text(_tableHeaders()[1],
                        style:
                            GoogleFonts.nunito(fontWeight: FontWeight.w800))),
                Expanded(
                    child: Text(_tableHeaders()[2],
                        style:
                            GoogleFonts.nunito(fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ..._listRows.take(4).map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.a.text)),
                      Expanded(child: Text(r.b.text)),
                      Expanded(child: Text(r.c.text)),
                    ],
                  ),
                ),
              ),
        ],
        const SizedBox(height: 10),
        Divider(color: styleAccent.withValues(alpha: 0.25)),
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
    if (key.contains('business')) return AppColors.purple;
    if (key.contains('receipt')) return AppColors.green;
    if (key.contains('whiteboard')) return AppColors.blue;
    if (key.contains('table')) return AppColors.gold;
    return AppColors.navyMid;
  }

  Color _styleAccent(Color base, int style) {
    if (style == 1) return AppColors.blue;
    if (style == 2) return AppColors.purple;
    return base;
  }

  List<String> _tableHeaders() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('receipt')) return const ['Item', 'Qty', 'Amount'];
    if (key.contains('table')) {
      return const ['Column A', 'Column B', 'Column C'];
    }
    if (key.contains('whiteboard')) return const ['Point', 'Owner', 'Status'];
    return const ['Field', 'Value', 'Note'];
  }

  String _signatureLabel() {
    final key = widget.templateName.toLowerCase();
    if (key.contains('contract')) {
      return 'Authorized Signatories __________________';
    }
    if (key.contains('business')) return 'Card Approved By __________________';
    if (key.contains('receipt')) return 'Cashier Signature __________________';
    if (key.contains('whiteboard')) {
      return 'Meeting Lead Signature __________________';
    }
    if (key.contains('table')) return 'Reviewed By __________________';
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
