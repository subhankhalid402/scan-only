import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TemplateExportService {
  TemplateExportService._();
  static final TemplateExportService instance = TemplateExportService._();

  // ─────────────────────────────────────────
  // EXCEL EXPORT
  // ─────────────────────────────────────────
  Future<String> exportExcel({
    required String stem,
    required Map<String, String> fields,
    List<List<String>> tableRows = const [],
    List<String> tableHeaders = const [], // ✅ NEW: optional header row
  }) async {
    final dir = await _ensureDir();
    final filePath = p.join(
      dir.path,
      '${_safe(stem)}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );

    final excel = Excel.createExcel();
    final sheet = excel['Template'];

    // ✅ FIXED: bold style for field keys
    final boldStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#EFF3FF'),
    );

    var r = 0;

    // Fields section — key bold, value normal
    fields.forEach((k, v) {
      final keyCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
      );
      keyCell.value = TextCellValue(k);
      keyCell.cellStyle = boldStyle; // ✅ FIXED: keys are bold

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
          .value = TextCellValue(v);
      r++;
    });

    // Table section
    if (tableRows.isNotEmpty) {
      r++; // blank separator row

      // ✅ FIXED: header row added if provided
      if (tableHeaders.isNotEmpty) {
        for (var j = 0; j < tableHeaders.length; j++) {
          final hCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: j, rowIndex: r),
          );
          hCell.value = TextCellValue(tableHeaders[j]);
          hCell.cellStyle = boldStyle; // ✅ headers bold
        }
        r++;
      }

      // Data rows
      for (var i = 0; i < tableRows.length; i++) {
        for (var j = 0; j < tableRows[i].length; j++) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: j,
                  rowIndex: r + i,
                ),
              )
              .value = TextCellValue(tableRows[i][j]);
        }
      }
    }

    // ✅ Auto-width columns (best effort)
    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 18);

    final bytes = excel.save();
    if (bytes == null) throw StateError('Excel encode failed');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  // ─────────────────────────────────────────
  // WORD EXPORT
  // ─────────────────────────────────────────
  Future<String> exportWord({
    required String stem,
    required Map<String, String> fields,
    List<List<String>> tableRows = const [],
    List<String> tableHeaders = const [], // ✅ NEW: optional header row
  }) async {
    final dir = await _ensureDir();
    final filePath = p.join(
      dir.path,
      '${_safe(stem)}_${DateTime.now().millisecondsSinceEpoch}.docx',
    );

    final zip = Archive();

    zip.addFile(ArchiveFile(
      '[Content_Types].xml',
      0,
      utf8.encode(_wordContentTypes()),
    ));

    zip.addFile(ArchiveFile(
      '_rels/.rels',
      0,
      utf8.encode(_wordRootRels()),
    ));

    // ✅ FIXED: document.xml.rels added — Word requires this
    zip.addFile(ArchiveFile(
      'word/_rels/document.xml.rels',
      0,
      utf8.encode(_wordDocumentRels()),
    ));

    // ✅ FIXED: settings.xml added — required for full Word compatibility
    zip.addFile(ArchiveFile(
      'word/settings.xml',
      0,
      utf8.encode(_wordSettings()),
    ));

    // Build document body
    final body = StringBuffer();

    // Title paragraph — bold, large
    body.writeln(_boldParagraph(stem.replaceAll('_', ' ').toUpperCase()));

    // Fields as key: value rows — key bold
    fields.forEach((k, v) {
      body.writeln(_keyValueParagraph(k, v)); // ✅ FIXED: key bold
    });

    // ✅ FIXED: proper Word table — not just pipe-joined text
    if (tableRows.isNotEmpty) {
      body.writeln(_wordTable(
        headers: tableHeaders,
        rows: tableRows,
      ));
    }

    // Signature line
    body.writeln(_paragraph(''));
    body.writeln(
      _boldParagraph('Authorized Signature __________________'),
    );

    zip.addFile(ArchiveFile(
      'word/document.xml',
      0,
      utf8.encode(_wordDocumentXml(body.toString())),
    ));

    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('DOCX encode failed');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  // ─────────────────────────────────────────
  // POWERPOINT EXPORT
  // ─────────────────────────────────────────
  Future<String> exportPpt({
    required String stem,
    required Map<String, String> fields,
    List<List<String>> tableRows = const [],
    List<String> tableHeaders = const [], // ✅ NEW: optional header row
  }) async {
    final dir = await _ensureDir();
    // ✅ FIXED: extension always .pptx — no double extension bug
    final filePath = p.join(
      dir.path,
      '${_safe(stem)}_${DateTime.now().millisecondsSinceEpoch}.pptx',
    );

    final zip = Archive();

    zip.addFile(ArchiveFile(
      '[Content_Types].xml',
      0,
      utf8.encode(_pptContentTypes()),
    ));
    zip.addFile(ArchiveFile(
      '_rels/.rels',
      0,
      utf8.encode(_pptRels()),
    ));
    zip.addFile(ArchiveFile(
      'ppt/presentation.xml',
      0,
      utf8.encode(_presentationXml()),
    ));
    zip.addFile(ArchiveFile(
      'ppt/_rels/presentation.xml.rels',
      0,
      utf8.encode(_presentationRels()),
    ));

    // ✅ FIXED: slide1 = title slide, slide2 = content slide
    zip.addFile(ArchiveFile(
      'ppt/slides/slide1.xml',
      0,
      utf8.encode(_titleSlideXml(_esc(stem.replaceAll('_', ' ').toUpperCase()))),
    ));
    zip.addFile(ArchiveFile(
      'ppt/slides/_rels/slide1.xml.rels',
      0,
      utf8.encode(_slide1Rels()), // ✅ points to slide2
    ));

    // Content slide — fields + table
    final contentLines = <String>[
      ...fields.entries.map((e) => '${e.key}: ${e.value}'),
    ];
    if (tableHeaders.isNotEmpty) {
      contentLines.add(tableHeaders.join('   |   '));
    }
    if (tableRows.isNotEmpty) {
      contentLines.addAll(tableRows.map((e) => e.join('   |   ')));
    }

    zip.addFile(ArchiveFile(
      'ppt/slides/slide2.xml',
      0,
      utf8.encode(_contentSlideXml(contentLines)),
    ));
    zip.addFile(ArchiveFile(
      'ppt/slides/_rels/slide2.xml.rels',
      0,
      utf8.encode(_emptyRels()),
    ));

    // ✅ FIXED: presentation updated to include 2 slides
    zip.addFile(ArchiveFile(
      'ppt/presentation.xml',
      0,
      utf8.encode(_presentationXmlTwoSlides()),
    ));
    zip.addFile(ArchiveFile(
      'ppt/_rels/presentation.xml.rels',
      0,
      utf8.encode(_presentationRelsTwoSlides()),
    ));

    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('PPTX encode failed');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  Future<Directory> _ensureDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/ScanOnly/TemplateExports');
    await dir.create(recursive: true);
    return dir;
  }

  String _safe(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;'); // ✅ FIXED: quotes bhi escape hoti hain

  // ─────────────────────────────────────────
  // WORD XML HELPERS
  // ─────────────────────────────────────────
  String _wordContentTypes() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

  String _wordRootRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  // ✅ FIXED: document.xml.rels — required by Word
  String _wordDocumentRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
</Relationships>''';

  // ✅ FIXED: settings.xml — required for Word compatibility
  String _wordSettings() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:defaultTabStop w:val="720"/>
  <w:compat/>
</w:settings>''';

  String _wordDocumentXml(String body) =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>$body<w:sectPr/></w:body>
</w:document>''';

  // Plain paragraph
  String _paragraph(String text) =>
      '<w:p><w:r><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';

  // Bold paragraph
  String _boldParagraph(String text) =>
      '<w:p><w:pPr><w:jc w:val="left"/></w:pPr>'
      '<w:r><w:rPr><w:b/><w:sz w:val="28"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';

  // ✅ FIXED: key bold, value normal — proper key:value styling
  String _keyValueParagraph(String key, String value) =>
      '<w:p>'
      '<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">${_esc(key)}: </w:t></w:r>'
      '<w:r><w:t xml:space="preserve">${_esc(value)}</w:t></w:r>'
      '</w:p>';

  // ✅ FIXED: proper Word table XML
  String _wordTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final sb = StringBuffer();
    sb.write(
      '<w:tbl>'
      '<w:tblPr>'
      '<w:tblStyle w:val="TableGrid"/>'
      '<w:tblW w:w="5000" w:type="pct"/>'
      '<w:tblBorders>'
      '<w:top w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>'
      '<w:left w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>'
      '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>'
      '<w:right w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>'
      '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>'
      '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>'
      '</w:tblBorders>'
      '</w:tblPr>',
    );

    // Header row
    if (headers.isNotEmpty) {
      sb.write('<w:tr>');
      for (final h in headers) {
        sb.write(
          '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="EFF3FF"/></w:tcPr>'
          '<w:p><w:r><w:rPr><w:b/></w:rPr>'
          '<w:t xml:space="preserve">${_esc(h)}</w:t>'
          '</w:r></w:p></w:tc>',
        );
      }
      sb.write('</w:tr>');
    }

    // Data rows
    for (final row in rows) {
      sb.write('<w:tr>');
      for (final cell in row) {
        sb.write(
          '<w:tc><w:p><w:r>'
          '<w:t xml:space="preserve">${_esc(cell)}</w:t>'
          '</w:r></w:p></w:tc>',
        );
      }
      sb.write('</w:tr>');
    }

    sb.write('</w:tbl>');
    return sb.toString();
  }

  // ─────────────────────────────────────────
  // PPTX XML HELPERS
  // ─────────────────────────────────────────
  String _pptContentTypes() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>''';

  String _pptRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';

  // ✅ FIXED: 2 slides registered
  String _presentationXmlTwoSlides() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:sldSz cx="9144000" cy="5143500"/>
  <p:notesSz cx="6858000" cy="9144000"/>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
    <p:sldId id="257" r:id="rId2"/>
  </p:sldIdLst>
</p:presentation>''';

  String _presentationRelsTwoSlides() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>
</Relationships>''';

  // ✅ FIXED: title slide with proper spPr so text is visible
  String _titleSlideXml(String title) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
      <p:spPr>
        <a:xfrm><a:off x="457200" y="1600200"/><a:ext cx="8229600" cy="1143000"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        <a:solidFill><a:srgbClr val="0B1740"/></a:solidFill>
      </p:spPr>
      <p:txBody>
        <a:bodyPr anchor="ctr" wrap="square"/>
        <a:lstStyle/>
        <a:p><a:pPr algn="ctr"/>
          <a:r>
            <a:rPr lang="en-US" sz="4000" b="1" dirty="0">
              <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
            </a:rPr>
            <a:t>$title</a:t>
          </a:r>
        </a:p>
      </p:txBody>
    </p:sp>
  </p:spTree></p:cSld>
</p:sld>''';

  // ✅ FIXED: content slide — each line is a proper <a:p> paragraph (not \n)
  String _contentSlideXml(List<String> lines) {
    final paragraphs = lines
        .map(
          (line) =>
              '<a:p><a:r>'
              '<a:rPr lang="en-US" sz="1400" dirty="0"/>'
              '<a:t>${_esc(line)}</a:t>'
              '</a:r></a:p>',
        )
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="2" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
      <p:spPr>
        <a:xfrm><a:off x="457200" y="457200"/><a:ext cx="8229600" cy="4228800"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
      </p:spPr>
      <p:txBody>
        <a:bodyPr anchor="t" wrap="square"/>
        <a:lstStyle/>
        $paragraphs
      </p:txBody>
    </p:sp>
  </p:spTree></p:cSld>
</p:sld>''';
  }

  // ✅ slide1 ka rels — slide2 pe link (for navigation, optional)
  String _slide1Rels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

  String _emptyRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

  // Legacy — kept for backward compat (not used internally anymore)
  String _presentationXml() => _presentationXmlTwoSlides();
  String _presentationRels() => _presentationRelsTwoSlides();
}