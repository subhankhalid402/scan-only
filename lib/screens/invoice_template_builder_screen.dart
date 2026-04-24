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

class InvoiceTemplateBuilderScreen extends StatefulWidget {
  const InvoiceTemplateBuilderScreen({super.key});

  @override
  State<InvoiceTemplateBuilderScreen> createState() =>
      _InvoiceTemplateBuilderScreenState();
}

class _InvoiceTemplateBuilderScreenState
    extends State<InvoiceTemplateBuilderScreen>
    with SingleTickerProviderStateMixin {
  final _company = TextEditingController();
  final _client = TextEditingController();
  final _invoiceNo = TextEditingController();
  final _notes = TextEditingController();
  int _templateStyle = 0;
  late final TabController _tabController;

  late final TextEditingController _date;
  late final TextEditingController _dueDate;

  final List<_InvoiceItem> _items = [
    _InvoiceItem(
      name: TextEditingController(),
      qty: TextEditingController(),
      rate: TextEditingController(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    final due = now.add(const Duration(days: 7));
    _date = TextEditingController(text: now.toIso8601String().split('T').first);
    _dueDate = TextEditingController(text: due.toIso8601String().split('T').first);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _company.dispose();
    _client.dispose();
    _invoiceNo.dispose();
    _date.dispose();
    _dueDate.dispose();
    _notes.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.total);

  String get _styleName =>
      _templateStyle == 0 ? 'Classic' : (_templateStyle == 1 ? 'Modern' : 'Bold');

  String get _today => DateTime.now().toIso8601String().split('T').first;

  Color get _accentColor => _templateStyle == 0
      ? AppColors.navyDark
      : (_templateStyle == 1 ? AppColors.navyLight : const Color(0xFF6C3FC5));

  String _colorToHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  // ─── PDF Builder ──────────────────────────────────────────────────────────

  Future<Uint8List> _buildPdfBytes() async {
    if (_items.isEmpty) throw Exception('Invoice must have at least one item.');

    final pdf = pw.Document();
    final hc = PdfColor.fromHex(_colorToHex(_accentColor));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Letterhead ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: pw.BoxDecoration(
                color: hc.shade(0.12),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(children: [
                pw.Container(
                  width: 5,
                  height: 40,
                  decoration: pw.BoxDecoration(
                      color: hc, borderRadius: pw.BorderRadius.circular(3)),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SCANONLY',
                          style: pw.TextStyle(
                              color: hc, fontSize: 7, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                      pw.Text(_company.text,
                          style: pw.TextStyle(
                              color: hc, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            color: hc, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                    pw.Text(_invoiceNo.text.isEmpty ? 'INV-0001' : _invoiceNo.text,
                        style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ]),
            ),
            pw.SizedBox(height: 16),
            // ── Bill To / Invoice Info ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: hc.shade(0.07),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO',
                            style: pw.TextStyle(
                                color: hc, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                        pw.SizedBox(height: 4),
                        pw.Text(_client.text.isEmpty ? 'Client Name' : _client.text,
                            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: hc.shade(0.07),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoRow(hc, 'Issue Date', _date.text),
                        pw.SizedBox(height: 4),
                        _pdfInfoRow(hc, 'Due Date', _dueDate.text),
                        pw.SizedBox(height: 4),
                        _pdfInfoRow(hc, 'Style', _styleName),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            // ── Items table ──
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
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: hc),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellHeight: 28,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            ),
            pw.SizedBox(height: 10),
            // ── Totals ──
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    _pdfTotalRow(hc, 'Subtotal', _subtotal == 0 ? '0' : _subtotal.toStringAsFixed(0), false),
                    pw.SizedBox(height: 4),
                    _pdfTotalRow(hc, 'TOTAL DUE', _subtotal == 0 ? '0' : _subtotal.toStringAsFixed(0), true),
                  ],
                ),
              ),
            ),
            if (_notes.text.trim().isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    color: hc.shade(0.06), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text('Notes: ${_notes.text}',
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
            pw.Spacer(),
            pw.Divider(color: hc.shade(0.3), thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by ScanOnly',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text('Authorized Signature __________________',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  pw.Widget _pdfInfoRow(PdfColor hc, String label, String value) {
    return pw.Row(children: [
      pw.Text(label,
          style: const pw.TextStyle(
              color: PdfColors.grey600, fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.Text(':  ',
          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
      pw.Text(value.isEmpty ? '—' : value,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
    ]);
  }

  pw.Widget _pdfTotalRow(PdfColor hc, String label, String value, bool bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: bold ? hc.shade(0.15) : null,
        border: bold ? null : pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 11 : 10,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: bold ? PdfColors.white : PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 13 : 10,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: bold ? PdfColors.white : PdfColors.grey900)),
        ],
      ),
    );
  }

  // ─── Save / Export ────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one item before saving.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final bytes = await _buildPdfBytes();
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/ScanOnly/Invoices');
      await outDir.create(recursive: true);
      final fileName = 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invoice saved: ${p.basename(outPath)}'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _exportAs(String format) async {
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one item before exporting.'),
            backgroundColor: Colors.orange),
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
    final rows =
        _items.map((i) => [i.name.text, i.qty.text, i.rate.text, i.total.toStringAsFixed(0)]).toList();

    try {
      String outPath;
      switch (format) {
        case 'excel':
          outPath = await TemplateExportService.instance
              .exportExcel(stem: 'invoice', fields: fields, tableRows: rows);
          break;
        case 'word':
          outPath = await TemplateExportService.instance
              .exportWord(stem: 'invoice', fields: fields, tableRows: rows);
          break;
        case 'ppt':
          outPath = await TemplateExportService.instance
              .exportPpt(stem: 'invoice', fields: fields, tableRows: rows);
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
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Iconsax.receipt, color: AppColors.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Export Invoice',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.navyDark)),
                  Text('Choose your preferred format',
                      style: GoogleFonts.nunito(
                          color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const SizedBox(height: 16),
              _exportTile(Icons.picture_as_pdf, 'PDF Document',
                  const Color(0xFFE53935), _generatePdf),
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
      title: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Invoice Template',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
          Text('PROFESSIONAL INVOICE',
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
                Tab(icon: Icon(Icons.picture_as_pdf_rounded, size: 16), text: 'PDF Preview'),
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
        _sectionLabel('Invoice Style', Iconsax.paintbucket),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) {
            final selected = _templateStyle == i;
            final colors = [AppColors.navyDark, AppColors.navyLight, const Color(0xFF6C3FC5)];
            final names = ['Classic', 'Modern', 'Bold'];
            final c = colors[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 10),
                child: GestureDetector(
                  onTap: () => setState(() => _templateStyle = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? c.withOpacity(0.07) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected ? c : Colors.black12, width: selected ? 2 : 1),
                      boxShadow: selected
                          ? [BoxShadow(color: c.withOpacity(0.18), blurRadius: 10)]
                          : [],
                    ),
                    child: Column(children: [
                      _styleMiniDoc(c, i),
                      const SizedBox(height: 6),
                      Text(names[i],
                          style: GoogleFonts.nunito(
                              color: selected ? c : AppColors.textMuted,
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

        // Company / Client fields
        _sectionLabel('Invoice Details', Iconsax.receipt),
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
          child: Column(children: [
            _field('Company', _company, icon: Icons.business_rounded),
            _field('Client', _client, icon: Icons.person_rounded),
            Row(children: [
              Expanded(
                child: _field('Invoice #', _invoiceNo, icon: Icons.confirmation_number_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(child: _field('Date', _date, icon: Icons.date_range_rounded)),
            ]),
            _field('Due Date', _dueDate, icon: Icons.event_available_rounded),
          ]),
        ),
        const SizedBox(height: 20),

        // Items
        Row(children: [
          _sectionLabel('Line Items', Iconsax.shopping_cart),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('${_items.length} item${_items.length == 1 ? '' : 's'}',
                style: GoogleFonts.nunito(
                    color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        ..._items.map(_itemEditor),
        OutlinedButton.icon(
          onPressed: () => setState(() => _items.add(_InvoiceItem(
                name: TextEditingController(),
                qty: TextEditingController(),
                rate: TextEditingController(),
              ))),
          icon: Icon(Icons.add_rounded, color: accent, size: 18),
          label: Text('Add Item',
              style: GoogleFonts.nunito(
                  color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: accent.withOpacity(0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 12),
        // Subtotal chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Row(children: [
            Text('Subtotal',
                style: GoogleFonts.nunito(
                    color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
            const Spacer(),
            Text(_subtotal.toStringAsFixed(0),
                style: GoogleFonts.nunito(
                    color: accent, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),

        const SizedBox(height: 16),
        _field('Notes', _notes, maxLines: 2, icon: Icons.notes_rounded),
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
              Text('Invoice PDF Preview',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navyDark)),
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
            _company.text + _client.text + _invoiceNo.text + _date.text + _dueDate.text +
                _items.map((i) => i.name.text + i.qty.text + i.rate.text).join('|') +
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

  Widget _styleMiniDoc(Color c, int i) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
          color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: i == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (i == 2)
            Row(children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Expanded(
                  child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: c.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3)))),
            ])
          else
            Container(
              height: 6,
              width: i == 1 ? 55 : double.infinity,
              decoration: BoxDecoration(
                  color: c.withOpacity(0.5), borderRadius: BorderRadius.circular(3)),
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

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, IconData? icon}) {
    final accent = _accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.nunito(
              fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          prefixIcon: icon != null ? Icon(icon, color: accent, size: 20) : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }

  Widget _itemEditor(_InvoiceItem item) {
    final accent = _accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(
              item.name.text.isNotEmpty ? item.name.text : 'New Item',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800, color: AppColors.navyDark, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(item.total.toStringAsFixed(0),
                style: GoogleFonts.nunito(
                    color: accent, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              if (_items.length == 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('At least one item is required.'),
                      backgroundColor: Colors.orange),
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
                Icons.delete_outline_rounded,
                color: _items.length == 1 ? Colors.grey.shade300 : Colors.redAccent,
                size: 20,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              flex: 3, child: _field('Item Name', item.name, icon: Icons.inventory_2_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _field('Qty', item.qty, icon: Icons.format_list_numbered_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _field('Rate', item.rate, icon: Icons.currency_rupee_rounded)),
        ]),
      ]),
    );
  }
}

class _InvoiceItem {
  final TextEditingController name, qty, rate;

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
