class TableCellData {
  final int row;
  final int col;
  final String text;
  final String alignment;
  final bool isMergedHint;
  final String dataType;

  const TableCellData({
    required this.row,
    required this.col,
    this.text = '',
    this.alignment = 'left',
    this.isMergedHint = false,
    this.dataType = 'text',
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'text': text,
        'alignment': alignment,
        'is_merged_hint': isMergedHint,
        'data_type': dataType,
      };
}

class TableScanData {
  final List<String> headers;
  final List<List<String>> rows;
  final List<TableCellData> cells;
  final int rowCount;
  final int columnCount;
  final bool headerDetected;
  final bool borderlessDetected;
  final bool nestedTableHint;
  final bool multiPage;
  final bool urduDetected;
  final bool pkrDetected;
  final String rawText;

  const TableScanData({
    this.headers = const [],
    this.rows = const [],
    this.cells = const [],
    this.rowCount = 0,
    this.columnCount = 0,
    this.headerDetected = false,
    this.borderlessDetected = false,
    this.nestedTableHint = false,
    this.multiPage = false,
    this.urduDetected = false,
    this.pkrDetected = false,
    this.rawText = '',
  });

  Map<String, dynamic> toJsonMap() => {
        'headers': headers,
        'rows': rows,
        'cells': cells.map((e) => e.toJson()).toList(),
        'row_count': rowCount,
        'column_count': columnCount,
        'header_detected': headerDetected,
        'borderless_detected': borderlessDetected,
        'nested_table_hint': nestedTableHint,
        'multi_page': multiPage,
        'urdu_detected': urduDetected,
        'pkr_detected': pkrDetected,
        'raw_text': rawText,
      };
}

