import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';
import '../models/table_scan_data.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_service.dart';
import '../services/share_file_service.dart';
import '../services/table_scan_service.dart';
import '../theme.dart';

class TableResultScreen extends StatefulWidget {
  final List<String> imagePaths;
  const TableResultScreen({super.key, required this.imagePaths});

  @override
  State<TableResultScreen> createState() => _TableResultScreenState();
}

class _TableResultScreenState extends State<TableResultScreen> {
  bool _loading = true;
  bool _busy = false;
  TableScanData _data = const TableScanData();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final d = await TableScanService.instance.extractFromPages(widget.imagePaths);
      if (!mounted) return;
      setState(() => _data = d);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _saveCsv() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Tables');
    await out.create(recursive: true);
    final file = File('${out.path}/table_${DateTime.now().millisecondsSinceEpoch}.csv');
    final rows = <String>[];
    if (_data.headers.isNotEmpty) rows.add(_csvRow(_data.headers));
    for (final r in _data.rows) {
      rows.add(_csvRow(r));
    }
    await file.writeAsString(rows.join('\n'));
    return file.path;
  }

  Future<String> _saveJson() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Tables');
    await out.create(recursive: true);
    final file = File('${out.path}/table_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(_data.toJsonMap()));
    return file.path;
  }

  Future<String> _saveHtml() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Tables');
    await out.create(recursive: true);
    final file = File('${out.path}/table_${DateTime.now().millisecondsSinceEpoch}.html');
    final headers = _data.headers
        .map((h) => '<th>${_esc(h)}</th>')
        .join();
    final body = _data.rows
        .map((r) => '<tr>${r.map((c) => '<td>${_esc(c)}</td>').join()}</tr>')
        .join('\n');
    final html = '''
<table border="1" cellspacing="0" cellpadding="4">
  ${headers.isNotEmpty ? '<thead><tr>$headers</tr></thead>' : ''}
  <tbody>
    $body
  </tbody>
</table>
''';
    await file.writeAsString(html);
    return file.path;
  }

  Future<void> _copyHtml() async {
    final htmlFile = await _saveHtml();
    final txt = await File(htmlFile).readAsString();
    await Clipboard.setData(ClipboardData(text: txt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HTML table copied')),
    );
  }

  Future<void> _exportAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pdf = await PdfService.instance.createSearchablePdf(
        widget.imagePaths,
        [for (final r in _data.rows) r.join(' | ')],
        'TableScan',
      );
      final csv = await _saveCsv();
      final json = await _saveJson();
      final html = await _saveHtml();
      final xlsx = await ExcelExportService.instance.exportTableToExcel(
        headers: _data.headers,
        rows: _data.rows,
      );

      final thumb = await PdfService.instance.generateThumbnail(widget.imagePaths.first);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: 'TableScan.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'table',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: _data.rawText,
          tags: const ['Table', 'OCR'],
        ),
      );

      if (!mounted) return;
      await ShareFileService.sharePaths(
        [xlsx, csv, pdf, json, html],
        text: 'Table exports (Google Sheets ready)',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported XLSX/CSV/PDF/JSON/HTML')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Table Scanner', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _stats(),
                  const SizedBox(height: 10),
                  _tablePreview(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _copyHtml,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy HTML'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _saveCsv,
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _saveJson,
                        icon: const Icon(Icons.data_object_rounded),
                        label: const Text('JSON'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.navyDark,
                        ),
                        onPressed: _busy ? null : _exportAll,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Export All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ScanResultFormStyle.insightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Structure Detection', style: ScanResultFormStyle.cardTitle()),
          const SizedBox(height: 8),
          Text('Rows: ${_data.rowCount} | Columns: ${_data.columnCount}', style: ScanResultFormStyle.muted()),
          Text('Header row: ${_data.headerDetected ? 'Detected' : 'Not sure'}', style: ScanResultFormStyle.muted()),
          Text('Borderless: ${_data.borderlessDetected ? 'Likely' : 'No'}', style: ScanResultFormStyle.muted()),
          Text('Nested table: ${_data.nestedTableHint ? 'Possible' : 'No'}', style: ScanResultFormStyle.muted()),
          Text('Urdu: ${_data.urduDetected ? 'Yes' : 'No'} | PKR: ${_data.pkrDetected ? 'Yes' : 'No'}', style: ScanResultFormStyle.muted()),
          Text('Multi-page: ${_data.multiPage ? 'Yes' : 'No'}', style: ScanResultFormStyle.muted()),
        ],
      ),
    );
  }

  Widget _tablePreview() {
    final headers = _data.headers;
    final rows = _data.rows;
    if (headers.isEmpty && rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: ScanResultFormStyle.insightCardDecoration(),
        child: Text('No table cells detected', style: ScanResultFormStyle.muted()),
      );
    }
    final all = <List<String>>[
      if (headers.isNotEmpty) headers,
      ...rows,
    ];
    return Container(
      decoration: ScanResultFormStyle.insightCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppColors.navyMid),
          dataRowMinHeight: 40,
          horizontalMargin: 12,
          dividerThickness: 0.6,
          border: TableBorder(
            horizontalInside: BorderSide(color: AppColors.navyDark.withValues(alpha: 0.08)),
          ),
          columns: List.generate(
            _data.columnCount,
            (i) => DataColumn(
              label: Text(
                headers.isNotEmpty && i < headers.length ? headers[i] : 'C${i + 1}',
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
          rows: [
            for (var r = headers.isNotEmpty ? 1 : 0; r < all.length; r++)
              DataRow(
                cells: [
                  for (var c = 0; c < _data.columnCount; c++)
                    DataCell(
                      Text(
                        c < all[r].length ? all[r][c] : '',
                        style: ScanResultFormStyle.muted(fontSize: 12),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _csvRow(List<String> row) =>
      row.map((e) => '"${e.replaceAll('"', '""')}"').join(',');

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

