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
  final _date = TextEditingController(text: '2026-04-14');
  final _dueDate = TextEditingController(text: '2026-04-21');
  final _notes = TextEditingController(text: 'Thank you for your business.');
  int _templateStyle = 0;

  final List<_InvoiceItem> _items = [
    _InvoiceItem(
      name: TextEditingController(text: 'Design Service'),
      qty: TextEditingController(text: '1'),
      rate: TextEditingController(text: '15000'),
    ),
  ];

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

  double get _total => _items.fold(0, (sum, i) => sum + i.total);
  String get _styleName => _templateStyle == 0
      ? 'Classic'
      : (_templateStyle == 1 ? 'Modern' : 'Bold');
  String get _today => DateTime.now().toIso8601String().split('T').first;

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final headerColorHex = _templateStyle == 0
        ? '#0B1740'
        : (_templateStyle == 1 ? '#1E3A8A' : '#4A148C');
    final headerColor = PdfColor.fromHex(headerColorHex);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Professional letterhead
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        horizontal: 10, vertical: 4),
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
                    pw.Text('Company: ${_company.text}'),
                    pw.Text('Client: ${_client.text}'),
                    pw.Text('Invoice #: ${_invoiceNo.text}'),
                    pw.Text('Date: ${_date.text}   Due: ${_dueDate.text}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
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
                ),
                headerDecoration: pw.BoxDecoration(
                  color: headerColor.shade(0.15),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      _total.toStringAsFixed(0),
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
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: pw.BoxDecoration(
                    color: headerColor.shade(0.12),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Total: ${_total.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: headerColor.shade(0.07),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('Notes ($_styleName): ${_notes.text}'),
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
    final bytes = await _buildPdfBytes();
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/Invoices');
    await outDir.create(recursive: true);
    final outPath = p.join(
      outDir.path,
      'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(outPath).writeAsBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice saved: ${p.basename(outPath)}'),
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
              'Invoice PDF Preview',
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
    final accent = _templateStyle == 0
        ? AppColors.navyDark
        : (_templateStyle == 1 ? AppColors.navyLight : AppColors.purple);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invoice Templates',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.navyDark,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'Canva-style real templates',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final selected = _templateStyle == i;
              final color = i == 0
                  ? AppColors.navyDark
                  : (i == 1 ? AppColors.navyLight : AppColors.purple);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _templateStyle = i),
                    child: Container(
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
                                  color: AppColors.gold.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Template ${i + 1}',
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                _field('Due Date', _dueDate, icon: Icons.event_available),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Items',
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ..._items.map(_itemEditor),
          const SizedBox(height: 8),
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
          ),
          _field('Notes', _notes, maxLines: 2, icon: Icons.notes_rounded),
          const SizedBox(height: 10),
          _previewCard(),
          const SizedBox(height: 14),
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
                  onPressed: _generatePdf,
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

  Widget _field(
    String label,
    TextEditingController c, {
    int maxLines = 1,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _itemEditor(_InvoiceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          _field('Item name', item.name, icon: Icons.inventory_2_outlined),
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
              IconButton(
                onPressed: () {
                  setState(() {
                    item.dispose();
                    _items.remove(item);
                  });
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final color = _templateStyle == 0
        ? AppColors.navyDark
        : (_templateStyle == 1 ? AppColors.navyLight : AppColors.purple);
    final previewBg = _templateStyle == 1
        ? const Color(0xFFF7FAFF)
        : (_templateStyle == 2 ? const Color(0xFFF9F4FF) : Colors.white);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (_templateStyle == 2 ? AppColors.purple : AppColors.navyDark)
              .withValues(alpha: 0.26),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
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
                    color: color.withValues(alpha: 0.85),
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
                  'INVOICE',
                  textAlign:
                      _templateStyle == 1 ? TextAlign.center : TextAlign.start,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (_templateStyle != 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: _templateStyle == 2 ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_company.text,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                Text('Bill to: ${_client.text}'),
                Text('Date: ${_date.text}   Due: ${_dueDate.text}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: _templateStyle == 1 ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text('Item',
                        style:
                            GoogleFonts.nunito(fontWeight: FontWeight.w800))),
                Text('Amount',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ..._items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.name.text)),
                    Text(
                        '${e.qty.text} x ${e.rate.text} = ${e.total.toStringAsFixed(0)}'),
                  ],
                ),
              )),
          const Divider(height: 18, thickness: 1.1),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.35)),
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
                  _total.toStringAsFixed(0),
                  style: GoogleFonts.nunito(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${_total.toStringAsFixed(0)}',
              style:
                  GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          if (_notes.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '[$_styleName] ${_notes.text.trim()}',
              style: GoogleFonts.nunito(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Divider(color: color.withValues(alpha: 0.25)),
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
