import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bank_statement_data.dart';
import '../models/document_model.dart';
import '../services/bank_statement_ocr_service.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class BankStatementResultScreen extends StatefulWidget {
  final List<String> imagePaths;

  const BankStatementResultScreen({super.key, required this.imagePaths});

  @override
  State<BankStatementResultScreen> createState() =>
      _BankStatementResultScreenState();
}

class _BankStatementResultScreenState extends State<BankStatementResultScreen> {
  bool _loading = true;
  bool _busy = false;
  BankStatementData _data = const BankStatementData();
  List<BankTransaction> _txns = [];

  final _holder = TextEditingController();
  final _acc = TextEditingController();
  final _iban = TextEditingController();
  final _bank = TextEditingController();
  final _branch = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _open = TextEditingController();
  final _close = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    for (final c in [_holder, _acc, _iban, _bank, _branch, _from, _to, _open, _close]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final d = await BankStatementOcrService.instance.extractFromPages(widget.imagePaths);
      _data = d;
      _txns = List<BankTransaction>.from(d.transactions);
      _holder.text = d.accountHolderName;
      _acc.text = d.accountNumber;
      _iban.text = d.iban;
      _bank.text = d.bankName;
      _branch.text = d.branch;
      _from.text = d.statementFrom;
      _to.text = d.statementTo;
      _open.text = d.openingBalance;
      _close.text = d.closingBalance;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  BankStatementData _current() {
    return _data.copyWith(
      accountHolderName: _holder.text.trim(),
      accountNumber: _acc.text.trim(),
      iban: _iban.text.trim(),
      bankName: _bank.text.trim(),
      branch: _branch.text.trim(),
      statementFrom: _from.text.trim(),
      statementTo: _to.text.trim(),
      openingBalance: _open.text.trim(),
      closingBalance: _close.text.trim(),
      transactions: List<BankTransaction>.from(_txns),
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<String> _saveJson(BankStatementData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/BankStatements');
    await out.create(recursive: true);
    final file = File('${out.path}/bank_statement_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return file.path;
  }

  Future<String> _saveCsv(BankStatementData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/BankStatements');
    await out.create(recursive: true);
    final file = File('${out.path}/bank_statement_${DateTime.now().millisecondsSinceEpoch}.csv');
    final rows = <String>[
      'date,description,debit,credit,balance,reference,category',
      ...d.transactions.map((t) =>
          '"${t.date}","${t.description.replaceAll('"', '""')}","${t.debit}","${t.credit}","${t.balance}","${t.reference}","${t.category}"'),
    ];
    await file.writeAsString(rows.join('\n'));
    return file.path;
  }

  Future<void> _exportAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = _current();
      final title = d.bankName.isEmpty ? 'Bank_Statement' : '${d.bankName}_Statement';
      final pdf = await PdfService.instance.createPdfFromImages(widget.imagePaths, title);
      final thumb = await PdfService.instance.generateThumbnail(widget.imagePaths.first);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$title.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'bank_statement',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: d.rawText,
          tags: const ['Bank Statement'],
        ),
      );
      final json = await _saveJson(d);
      final csv = await _saveCsv(d);
      final xlsx = await ExcelExportService.instance.exportBankStatementToExcel(
        statement: {
          'bank_name': d.bankName,
          'account_holder': d.accountHolderName,
          'account_number': d.accountNumber,
          'iban': d.iban,
          'statement_from': d.statementFrom,
          'statement_to': d.statementTo,
          'opening_balance': d.openingBalance,
          'closing_balance': d.closingBalance,
          'total_credits': d.totalCredits,
          'total_debits': d.totalDebits,
          'average_monthly_balance': d.averageMonthlyBalance,
        },
        transactions: d.transactions.map((e) => e.toMap()).toList(),
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(pdf), XFile(json), XFile(csv), XFile(xlsx)],
          text: 'Bank statement summary');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported PDF/JSON/CSV/Excel',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
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
    final recurring = _recurringCount(d.transactions);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Bank Statement', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _analyticsCard(d, recurring),
                  const SizedBox(height: 10),
                  _field('Account Holder', _holder),
                  _field('Account Number', _acc),
                  _field('IBAN', _iban),
                  _field('Bank', _bank),
                  _field('Branch', _branch),
                  Row(children: [
                    Expanded(child: _field('From', _from)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('To', _to)),
                  ]),
                  Row(children: [
                    Expanded(child: _field('Opening', _open)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Closing', _close)),
                  ]),
                  const SizedBox(height: 10),
                  _txTable(),
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
                          onPressed: _busy ? null : _exportAll,
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

  Widget _analyticsCard(BankStatementData d, int recurring) {
    final cats = <String, double>{};
    for (final t in d.transactions) {
      final amt = _num(t.debit) + _num(t.credit);
      cats[t.category] = (cats[t.category] ?? 0) + amt;
    }
    final maxCat = cats.values.isEmpty ? 0.0 : cats.values.reduce((a, b) => a > b ? a : b);
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
          Text('Smart Analytics', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Total Credits: ${d.totalCredits.toStringAsFixed(2)}', style: GoogleFonts.nunito(color: Colors.greenAccent)),
          Text('Total Debits: ${d.totalDebits.toStringAsFixed(2)}', style: GoogleFonts.nunito(color: Colors.orangeAccent)),
          Text('Avg Balance: ${d.averageMonthlyBalance.toStringAsFixed(2)}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Recurring payments detected: $recurring', style: GoogleFonts.nunito(color: Colors.white70)),
          const SizedBox(height: 6),
          ...cats.entries.take(6).map((e) {
            final ratio = maxCat <= 0 ? 0.0 : (e.value / maxCat).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.key}: ${e.value.toStringAsFixed(2)}', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
                  LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white12, color: AppColors.gold),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _txTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: Text('Transactions', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800))),
                Text('${_txns.length}', style: GoogleFonts.nunito(color: Colors.white54)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ..._txns.take(20).map((t) => ListTile(
                dense: true,
                title: Text('${t.date} • ${t.description}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
                subtitle: Text('Dr ${t.debit} | Cr ${t.credit} | Bal ${t.balance}', style: GoogleFonts.nunito(color: Colors.white38, fontSize: 11)),
                trailing: Text(t.category, style: GoogleFonts.nunito(color: AppColors.gold, fontSize: 10)),
              )),
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
              IconButton(onPressed: () => _copy(label, c.text.trim()), icon: const Icon(Icons.copy_rounded, size: 16), color: Colors.white60),
            ],
          ),
          TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF141E31),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  double _num(String t) {
    final m = RegExp(r'(\d+(?:[.,]\d{1,2})?)')
        .firstMatch(t.replaceAll(',', ''));
    return m == null ? 0 : (double.tryParse(m.group(1) ?? '') ?? 0);
  }

  int _recurringCount(List<BankTransaction> tx) {
    final byDesc = <String, int>{};
    for (final t in tx) {
      final k = t.description.toLowerCase().trim();
      if (k.isEmpty) continue;
      byDesc[k] = (byDesc[k] ?? 0) + 1;
    }
    return byDesc.values.where((v) => v >= 2).length;
  }
}

