class BookPageData {
  final int pageIndex;
  final String pageNumber;
  final String heading;
  final String header;
  final String footer;
  final String text;
  final List<String> footnotes;
  final List<String> captions;
  final String columnLayout;
  final bool hasEquation;
  final bool hasTable;

  const BookPageData({
    required this.pageIndex,
    this.pageNumber = '',
    this.heading = '',
    this.header = '',
    this.footer = '',
    this.text = '',
    this.footnotes = const [],
    this.captions = const [],
    this.columnLayout = 'single',
    this.hasEquation = false,
    this.hasTable = false,
  });

  Map<String, dynamic> toJson() => {
        'page_index': pageIndex,
        'page_number': pageNumber,
        'heading': heading,
        'header': header,
        'footer': footer,
        'text': text,
        'footnotes': footnotes,
        'captions': captions,
        'column_layout': columnLayout,
        'has_equation': hasEquation,
        'has_table': hasTable,
      };
}

class BookScanData {
  final String title;
  final String languageHint;
  final String tableOfContents;
  final List<BookPageData> pages;
  final bool twoPageSpreadDetected;
  final bool curvatureCorrected;
  final bool fingerRemovalApplied;
  final bool autoPageTurnDetected;
  final String rawText;

  const BookScanData({
    this.title = '',
    this.languageHint = '',
    this.tableOfContents = '',
    this.pages = const [],
    this.twoPageSpreadDetected = false,
    this.curvatureCorrected = false,
    this.fingerRemovalApplied = false,
    this.autoPageTurnDetected = false,
    this.rawText = '',
  });

  BookScanData copyWith({
    String? title,
    String? languageHint,
    String? tableOfContents,
    List<BookPageData>? pages,
    bool? twoPageSpreadDetected,
    bool? curvatureCorrected,
    bool? fingerRemovalApplied,
    bool? autoPageTurnDetected,
    String? rawText,
  }) {
    return BookScanData(
      title: title ?? this.title,
      languageHint: languageHint ?? this.languageHint,
      tableOfContents: tableOfContents ?? this.tableOfContents,
      pages: pages ?? this.pages,
      twoPageSpreadDetected: twoPageSpreadDetected ?? this.twoPageSpreadDetected,
      curvatureCorrected: curvatureCorrected ?? this.curvatureCorrected,
      fingerRemovalApplied: fingerRemovalApplied ?? this.fingerRemovalApplied,
      autoPageTurnDetected: autoPageTurnDetected ?? this.autoPageTurnDetected,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toJsonMap() => {
        'title': title,
        'language_hint': languageHint,
        'table_of_contents': tableOfContents,
        'two_page_spread_detected': twoPageSpreadDetected,
        'curvature_corrected': curvatureCorrected,
        'finger_removal_applied': fingerRemovalApplied,
        'auto_page_turn_detected': autoPageTurnDetected,
        'pages': pages.map((e) => e.toJson()).toList(),
        'raw_text': rawText,
      };
}

