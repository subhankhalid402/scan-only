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

class InvoiceTemplateBuilderScreen extends StatefulWidget {
  const InvoiceTemplateBuilderScreen({super.key});

  @override
  State<InvoiceTemplateBuilderScreen> createState() =>
      _InvoiceTemplateBuilderScreenState();
}

class _InvoiceTemplateBuilderScreenState
    extends State<InvoiceTemplateBuilderScreen> {
  final _company = TextEditingController(text: 'ScanOnly Pvt Ltd');
  final _client = TextEditingController(text: 'Client Name');
  final _invoiceNo = TextEditingController(text: 'INV-1001');
  final _notes = TextEditingController(text: 'Thank you for your business.');
  int _templateStyle = 0;

  // ✅ FIXED: hardcoded strings ki jagah _today se initialize
  late final TextEditingController _date;
  late final TextEditingController _dueDate;

  final List<_InvoiceItem> _items = [
    _InvoiceItem(
      name: TextEditingController(text: 'Design Service'),
      qty: TextEditingController(text: '1'),
      rate: TextEditingController(text: '15000'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // ✅ FIXED: auto-date on first open
    final now = DateTime.now();
    final due = now.add(const Duration(days: 7));
    _date = TextEditingController(
      text: now.toIso8601String().split('T').first,
    );
    _dueDate = TextEditingController(
      text: due.toIso8601String().split('T').first,
    );
  }

  @override
  void dispose() {
    _company.dispose();
    _client.dispose();
    _invoiceNo.dispose();
    _date.dispose();
    _dueDate.dispose();
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.total);

  // ✅ Style name consistent — "Classic/Modern/Bold" (document builder se match)
  String get _styleName =>
      _templateStyle == 0 ? 'Classic' : (_templateStyle == 1 ? 'Modern' : 'Bold');

  String get _today => DateTime.now().toIso8601String().split('T').first;

  Color get _accentColor => _templateStyle == 0
      ? AppColors.navyDark
      : (_templateStyle == 1 ? AppColors.navyLight : AppColors.purple);

  // ✅ FIXED: .value.toRadixString() — safe across all Flutter versions
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Future<Uint8List> _buildPdfBytes() async {
    // ✅ FIXED: items empty guard — crash prevention
    if (_items.isEmpty) {
      throw Exception('Invoice must have at least one item.');
    }

    final pdf = pw.Document();
    final headerColor = PdfColor.fromHex(_colorToHex(_accentColor)); // ✅ FIXED

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Letterhead band
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: headerColor.shade(0.14),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 8,
                      height: 34,
                      decoration: pw.BoxDecoration(
                        color: headerColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Text(
                        'SCANONLY $_styleName INVOICE',
                        style: pw.TextStyle(
                          color: headerColor,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    pw.Text(
                      _today,
                      style: pw.TextStyle(
                        color: headerColor,
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
                      height: 34,
                      margin: const pw.EdgeInsets.only(right: 8),
                      decoration: pw.BoxDecoration(color: headerColor),
                    ),
                  pw.Expanded(
                    child: pw.Text(
                      'INVOICE',
                      textAlign: _templateStyle == 1
                          ? pw.TextAlign.center
                          : pw.TextAlign.left,
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: headerColor,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: headerColor.shade(0.15),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      _invoiceNo.text,
                      style: pw.TextStyle(
                        color: headerColor,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              // Info block
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: headerColor.shade(_templateStyle == 2 ? 0.18 : 0.08),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Company: ${_company.text}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Client: ${_client.text}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Invoice #: ${_invoiceNo.text}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Date: ${_date.text}   Due: ${_dueDate.text}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              // Items table — 4 columns with proper headers
              pw.TableHelper.fromTextArray(
                headers: const ['Item', 'Qty', 'Rate', 'Amount'],
                data: _items
                    .map((i) => [
                          i.name.text,
                          i.qty.text,
                          i.rate.text,
                          i.total.toStringAsFixed(0),
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(
                  color: headerColor,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: headerColor.shade(0.15),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 28,
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 10),
              // Subtotal row
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: headerColor.shade(0.35)),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Subtotal',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: headerColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      _subtotal.toStringAsFixed(0),
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: headerColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              // Total block
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color: headerColor.shade(0.12),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Total: ${_subtotal.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              // Notes
              if (_notes.text.trim().isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: headerColor.shade(0.07),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Notes ($_styleName): ${_notes.text}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              pw.Spacer(),
              pw.Divider(color: headerColor.shade(0.35)),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Authorized Signature __________________',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: headerColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  Future<void> _generatePdf() async {
    // ✅ FIXED: empty items guard with user-friendly message
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final bytes = await _buildPdfBytes();
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/ScanOnly/Invoices');
      await outDir.create(recursive: true);
      final fileName =
          'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outPath = p.join(outDir.path, fileName);
      await File(outPath).writeAsBytes(bytes);

      final doc = DocumentModel(
        name: fileName,
        filePath: outPath,
        fileType: 'pdf',
        scanType: 'document',
        pageCount: 1,
        fileSizeMB: bytes.length / (1024 * 1024),
        createdAt: DateTime.now(),
        tags: const [],
      );
      await DatabaseService.instance.insertDocument(doc);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice saved: ${p.basename(outPath)}'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _exportAs(String format) async {
    // ✅ FIXED: empty items guard
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item before exporting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fields = {
      'Company': _company.text,
      'Client': _client.text,
      'Invoice #': _invoiceNo.text,
      'Date': _date.text,
      'Due Date': _dueDate.text,
      'Notes': _notes.text,
      'Total': _subtotal.toStringAsFixed(0),
    };

    // ✅ FIXED: 4-column rows — Item, Qty, Rate, Amount (consistent with PDF table)
    final rows = _items
        .map((i) => [
              i.name.text,
              i.qty.text,
              i.rate.text,
              i.total.toStringAsFixed(0),
            ])
        .toList();

    try {
      String outPath;
      switch (format) {
        case 'excel':
          outPath = await TemplateExportService.instance.exportExcel(
            stem: 'invoice',
            fields: fields,
            tableRows: rows,
          );
          break;
        case 'word':
          outPath = await TemplateExportService.instance.exportWord(
            stem: 'invoice',
            fields: fields,
            tableRows: rows,
          );
          break;
        case 'ppt':
          outPath = await TemplateExportService.instance.exportPpt(
            stem: 'invoice',
            fields: fields,
            tableRows: rows,
          );
          break;
        default:
          return;
      }

      final ext = outPath.split('.').last.toLowerCase();
      final doc = DocumentModel(
        name: p.basename(outPath),
        filePath: outPath,
        fileType: ext,
        scanType: 'document',
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
                'Export Invoice As',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _exportTile(
                Icons.picture_as_pdf,
                'PDF',
                AppColors.navyDark,
                _generatePdf,
              ),
              _exportTile(
                Icons.table_chart_rounded,
                'Excel (.xlsx)',
                const Color(0xFF217346),
                () => _exportAs('excel'),
              ),
              _exportTile(
                Icons.description_rounded,
                'Word (.docx)',
                const Color(0xFF2B579A),
                () => _exportAs('word'),
              ),
              _exportTile(
                Icons.slideshow_rounded,
                'PowerPoint (.pptx)',
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
    // ✅ FIXED: empty items guard before preview
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to preview.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.navyDark,
            foregroundColor: Colors.white, // ✅ FIXED: back button visible
            title: Text(
              'Invoice PDF Preview',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
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
    final accent = _accentColor;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invoice Template',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white, // ✅ FIXED: back button white
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Style selector
          Text(
            'Choose Style',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: AppColors.navyDark,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final selected = _templateStyle == i;
              final color = i == 0
                  ? AppColors.navyDark
                  : (i == 1 ? AppColors.navyLight : AppColors.purple);
              // ✅ FIXED: "Classic/Modern/Bold" — document builder se consistent
              final styleName =
                  i == 0 ? 'Classic' : (i == 1 ? 'Modern' : 'Bold');
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _templateStyle = i),
                    child: AnimatedContainer( // ✅ smooth selection
                      duration: const Duration(milliseconds: 200),
                      height: 106,
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
                                  color: AppColors.gold.withOpacity(0.25), // ✅ FIXED
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.16), // ✅ FIXED
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.08), // ✅ FIXED
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.08), // ✅ FIXED
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              styleName, // ✅ FIXED: "Classic/Modern/Bold"
                              style: GoogleFonts.nunito(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
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
          const SizedBox(height: 14),
          // Fields card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.24)), // ✅ FIXED
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05), // ✅ FIXED
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _field('Company', _company, icon: Icons.business_rounded),
                _field('Client', _client, icon: Icons.person_rounded),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        'Invoice #',
                        _invoiceNo,
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        'Date',
                        _date,
                        icon: Icons.date_range_rounded,
                      ),
                    ),
                  ],
                ),
                _field(
                  'Due Date',
                  _dueDate,
                  icon: Icons.event_available,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Items section
          Row(
            children: [
              Text(
                'Items',
                style: GoogleFonts.nunito(
                  color: AppColors.navyDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // ✅ item count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_items.length} item${_items.length == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._items.map(_itemEditor),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _items.add(
                  _InvoiceItem(
                    name: TextEditingController(text: 'Service'),
                    qty: TextEditingController(text: '1'),
                    rate: TextEditingController(text: '0'),
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 12),
          _field('Notes', _notes, maxLines: 2, icon: Icons.notes_rounded),
          const SizedBox(height: 10),
          // Live preview
          _previewCard(),
          const SizedBox(height: 14),
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

  Widget _field(
    String label,
    TextEditingController c, {
    int maxLines = 1,
    IconData? icon,
  }) {
    final accent = _accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: accent) : null,
          // ✅ FIXED: styled borders — document builder se consistent
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accent.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accent.withOpacity(0.25)),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _itemEditor(_InvoiceItem item) {
    final accent = _accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ FIXED: delete button moved to top-right corner — less cramped
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name.text.isNotEmpty ? item.name.text : 'New Item',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyDark,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  // ✅ prevent deleting last item
                  if (_items.length == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('At least one item is required.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    item.dispose();
                    _items.remove(item);
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    color: _items.length == 1
                        ? Colors.grey.shade300
                        : Colors.redAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _field('Item Name', item.name, icon: Icons.inventory_2_outlined),
          Row(
            children: [
              Expanded(
                child: _field(
                  'Qty',
                  item.qty,
                  icon: Icons.format_list_numbered_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field('Rate', item.rate, icon: Icons.currency_rupee),
              ),
              const SizedBox(width: 8),
              // ✅ live amount preview per item
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.total.toStringAsFixed(0),
                  style: GoogleFonts.nunito(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final color = _accentColor;
    final previewBg = _templateStyle == 1
        ? const Color(0xFFF7FAFF)
        : (_templateStyle == 2 ? const Color(0xFFF9F4FF) : Colors.white);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.26)), // ✅ FIXED
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // ✅ FIXED
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14), // ✅ FIXED
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Professional Invoice Layout',
                    style: GoogleFonts.nunito(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  _today,
                  style: GoogleFonts.nunito(
                    color: color.withOpacity(0.85), // ✅ FIXED
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // INVOICE title
          Row(
            children: [
              if (_templateStyle == 2)
                Container(
                  width: 6,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              Expanded(
                child: Text(
                  '$_styleName INVOICE',
                  textAlign: _templateStyle == 1
                      ? TextAlign.center
                      : TextAlign.start,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12), // ✅ FIXED
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _invoiceNo.text,
                  style: GoogleFonts.nunito(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Info block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(_templateStyle == 2 ? 0.12 : 0.06), // ✅ FIXED
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _company.text,
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                ),
                Text('Bill to: ${_client.text}'),
                Text('Date: ${_date.text}   Due: ${_dueDate.text}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity( // ✅ FIXED
                  _templateStyle == 1 ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Qty',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                Text(
                  'Rate',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                // ✅ FIXED: Amount column bhi dikhta hai preview mein
                Text(
                  'Amount',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Item rows
          ..._items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.name.text,
                      style: GoogleFonts.nunito(fontSize: 12),
                    ),
                  ),
                  Text(
                    e.qty.text,
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    e.rate.text,
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    e.total.toStringAsFixed(0),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 18, thickness: 1.1),
          // Subtotal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.35)), // ✅ FIXED
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  'Subtotal',
                  style: GoogleFonts.nunito(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _subtotal.toStringAsFixed(0),
                  style: GoogleFonts.nunito(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Total
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${_subtotal.toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
          // Notes
          if (_notes.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '[$_styleName] ${_notes.text.trim()}',
              style: GoogleFonts.nunito(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Divider(color: color.withOpacity(0.25)), // ✅ FIXED
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Authorized Signature __________________',
              style: GoogleFonts.nunito(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceItem {
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController rate;

  _InvoiceItem({required this.name, required this.qty, required this.rate});

  double get total {
    final q = double.tryParse(qty.text.trim()) ?? 0;
    final r = double.tryParse(rate.text.trim()) ?? 0;
    return q * r;
  }

  void dispose() {
    name.dispose();
    qty.dispose();
    rate.dispose();
  }
}