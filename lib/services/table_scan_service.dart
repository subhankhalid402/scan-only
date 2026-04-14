import '../models/table_scan_data.dart';
import 'ocr_service.dart';

class TableScanService {
  TableScanService._();
  static final TableScanService instance = TableScanService._();

  Future<TableScanData> extractFromPages(List<String> imagePaths) async {
    final allRows = <List<String>>[];
    final allCells = <TableCellData>[];
    final rawParts = <String>[];

    var maxCols = 0;
    var globalRow = 0;
    var urduDetected = false;
    var pkrDetected = false;
    var nestedHint = false;

    for (final p in imagePaths) {
      final lines = await OcrService.instance.extractTextLines(p);
      final urdu = await OcrService.instance.extractUrduText(p);
      final raw = await OcrService.instance.extractText(p);
      rawParts.add(raw);
      if (_hasUrdu(urdu) || _hasUrdu(raw)) urduDetected = true;
      if (_hasPkr(raw) || _hasPkr(urdu)) pkrDetected = true;

      final grouped = _groupLinesByRow(lines);
      for (final rowLines in grouped) {
        final rowVals = _rowToColumns(rowLines);
        if (rowVals.isEmpty) continue;
        if (rowVals.length > maxCols) maxCols = rowVals.length;
        allRows.add(rowVals);
        for (var c = 0; c < rowVals.length; c++) {
          final t = rowVals[c];
          allCells.add(
            TableCellData(
              row: globalRow,
              col: c,
              text: t,
              alignment: _alignmentFromText(t, rowLines),
              isMergedHint: _isMergedHint(t, rowVals),
              dataType: _detectType(t),
            ),
          );
        }
        if (_hasNestedPattern(rowVals)) nestedHint = true;
        globalRow++;
      }
    }

    for (var i = 0; i < allRows.length; i++) {
      allRows[i] = _normalizeRow(allRows[i], maxCols);
    }

    final headers = allRows.isNotEmpty ? List<String>.from(allRows.first) : <String>[];
    final rows = allRows.length > 1 ? allRows.sublist(1) : <List<String>>[];
    final headerDetected = _headerDetected(headers);
    final borderless = _likelyBorderless(rawParts.join('\n'));

    return TableScanData(
      headers: headers,
      rows: rows,
      cells: allCells,
      rowCount: rows.length,
      columnCount: maxCols,
      headerDetected: headerDetected,
      borderlessDetected: borderless,
      nestedTableHint: nestedHint,
      multiPage: imagePaths.length > 1,
      urduDetected: urduDetected,
      pkrDetected: pkrDetected,
      rawText: rawParts.join('\n\n'),
    );
  }

  List<List<OcrTextLine>> _groupLinesByRow(List<OcrTextLine> lines) {
    final sorted = List<OcrTextLine>.from(lines)
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    final groups = <List<OcrTextLine>>[];
    const threshold = 14.0;
    for (final l in sorted) {
      if (groups.isEmpty) {
        groups.add([l]);
        continue;
      }
      final last = groups.last;
      final avgTop = last.map((e) => e.boundingBox.top).reduce((a, b) => a + b) / last.length;
      if ((l.boundingBox.top - avgTop).abs() <= threshold) {
        last.add(l);
      } else {
        groups.add([l]);
      }
    }
    for (final g in groups) {
      g.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    }
    return groups.where((g) => g.isNotEmpty).toList();
  }

  List<String> _rowToColumns(List<OcrTextLine> rowLines) {
    if (rowLines.isEmpty) return const [];
    final merged = rowLines.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
    if (merged.isEmpty) return const [];

    // Try split by explicit separators first for borderless/partial borders.
    final candidate = merged.join(' | ');
    final byPipe = candidate
        .split(RegExp(r'\s*\|\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (byPipe.length > 1) return byPipe;

    final bySpace = candidate
        .split(RegExp(r'\s{2,}|\t+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (bySpace.length > 1) return bySpace;

    return merged;
  }

  List<String> _normalizeRow(List<String> row, int cols) {
    final out = List<String>.from(row);
    while (out.length < cols) {
      out.add('');
    }
    if (out.length > cols) return out.sublist(0, cols);
    return out;
  }

  bool _headerDetected(List<String> headers) {
    if (headers.isEmpty) return false;
    final joined = headers.join(' ').toLowerCase();
    return joined.contains('name') ||
        joined.contains('date') ||
        joined.contains('amount') ||
        joined.contains('total') ||
        joined.contains('description') ||
        joined.contains('تفصیل') ||
        joined.contains('رقم') ||
        joined.contains('تاریخ');
  }

  bool _hasUrdu(String text) {
    for (final r in text.runes) {
      if (r >= 0x0600 && r <= 0x06FF) return true;
    }
    return false;
  }

  bool _hasPkr(String text) {
    final t = text.toLowerCase();
    return t.contains('pkr') || t.contains('rs') || t.contains('روپے');
  }

  String _alignmentFromText(String cellText, List<OcrTextLine> rowLines) {
    final t = cellText.trim();
    if (t.isEmpty) return 'left';
    if (_detectType(t) != 'text') return 'right';
    if (_hasUrdu(t)) return 'right';
    if (rowLines.length > 3) return 'center';
    return 'left';
  }

  String _detectType(String value) {
    final t = value.trim();
    if (t.isEmpty) return 'empty';
    if (RegExp(r'^\s*=?\s*[A-Z]+\d+([:+\-*/][A-Z]+\d+)+\s*$', caseSensitive: false)
        .hasMatch(t)) {
      return 'formula';
    }
    if (RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b').hasMatch(t)) return 'date';
    if (RegExp(r'\b(PKR|RS\.?|USD|EUR)\b', caseSensitive: false).hasMatch(t)) {
      return 'currency';
    }
    if (RegExp(r'^-?\d+(?:[.,]\d+)?$').hasMatch(t)) return 'number';
    return 'text';
  }

  bool _isMergedHint(String text, List<String> row) {
    if (text.trim().isEmpty) return false;
    final nonEmpty = row.where((e) => e.trim().isNotEmpty).length;
    return nonEmpty <= 2 && text.trim().length > 18;
  }

  bool _likelyBorderless(String raw) {
    final t = raw.toLowerCase();
    return !t.contains('|') && !t.contains('----') && t.contains('  ');
  }

  bool _hasNestedPattern(List<String> row) {
    final joined = row.join(' ').toLowerCase();
    return joined.contains('sub total') ||
        joined.contains('subtotal') ||
        joined.contains('sub-item') ||
        joined.contains('nested');
  }
}

