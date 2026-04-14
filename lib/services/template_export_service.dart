import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TemplateExportService {
  TemplateExportService._();
  static final TemplateExportService instance = TemplateExportService._();

  Future<String> exportExcel({
    required String stem,
    required Map<String, String> fields,
    List<List<String>> tableRows = const [],
  }) async {
    final dir = await _ensureDir();
    final filePath = p.join(
      dir.path,
      '${_safe(stem)}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    final excel = Excel.createExcel();
    final sheet = excel['Template'];
    var r = 0;
    fields.forEach((k, v) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
          .value = TextCellValue(k);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
          .value = TextCellValue(v);
      r++;
    });
    if (tableRows.isNotEmpty) {
      r++;
      for (var i = 0; i < tableRows.length; i++) {
        for (var j = 0; j < tableRows[i].length; j++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: r + i))
              .value = TextCellValue(tableRows[i][j]);
        }
      }
    }
    final bytes = excel.save();
    if (bytes == null) throw StateError('Excel encode failed');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<String> exportWord({
    required String stem,
    required Map<String, String> fields,
    List<List<String>> tableRows = const [],
  }) async {
    final dir = await _ensureDir();
    final filePath = p.join(
      dir.path,
      '${_safe(stem)}_${DateTime.now().millisecondsSinceEpoch}.docx',
    );
    final zip = Archive();
    zip.addFile(ArchiveFile(
      '[_Content_Types].xml',
      0,
      utf8.encode('''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'''),
    ));
    zip.addFile(ArchiveFile(
      '_rels/.rels',
      0,
      utf8.encode('''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'''),
    ));
    final body = StringBuffer();
    body.writeln('<w:p><w:r><w:t>${_esc(stem)}</w:t></w:r></w:p>');
    fields.forEach((k, v) {
      body.writeln('<w:p><w:r><w:t>${_esc('$k: $v')}</w:t></w:r></w:p>');
    });
    if (tableRows.isNotEmpty) {
      for (final row in tableRows) {
        body.writeln(
            '<w:p><w:r><w:t>${_esc(row.join(' | '))}</w:t></w:r></w:p>');
      }
    }
    zip.addFile(ArchiveFile(
      'word/document.xml',
      0,
      utf8.encode('''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>
'''),
    ));
    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('DOCX encode failed');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<String> exportPpt({
    required String stem,
    required Map<String, String> fields,
    List<List<String>> tableRows = const [],
    bool slidesFriendlyName = false,
  }) async {
    final dir = await _ensureDir();
    final ext = slidesFriendlyName ? 'slides.pptx' : 'pptx';
    final filePath = p.join(
      dir.path,
      '${_safe(stem)}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    final textLines = <String>[
      stem,
      ...fields.entries.map((e) => '${e.key}: ${e.value}')
    ];
    if (tableRows.isNotEmpty) {
      textLines.addAll(tableRows.map((e) => e.join(' | ')));
    }
    final slideText = _esc(textLines.join('\n'));

    final zip = Archive();
    zip.addFile(
        ArchiveFile('[Content_Types].xml', 0, utf8.encode(_pptContentTypes())));
    zip.addFile(ArchiveFile('_rels/.rels', 0, utf8.encode(_pptRels())));
    zip.addFile(ArchiveFile(
        'ppt/presentation.xml', 0, utf8.encode(_presentationXml())));
    zip.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', 0,
        utf8.encode(_presentationRels())));
    zip.addFile(ArchiveFile(
        'ppt/slides/slide1.xml', 0, utf8.encode(_slideXml(slideText))));
    zip.addFile(ArchiveFile(
        'ppt/slides/_rels/slide1.xml.rels', 0, utf8.encode(_slideRels())));
    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('PPTX encode failed');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<Directory> _ensureDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/ScanOnly/TemplateExports');
    await dir.create(recursive: true);
    return dir;
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _pptContentTypes() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
 <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>
''';
  String _pptRels() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>
''';
  String _presentationXml() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
 <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
</p:presentation>
''';
  String _presentationRels() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>
''';
  String _slideXml(String text) => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
 <p:cSld><p:spTree><p:sp>
 <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
 <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:txBody>
 </p:sp></p:spTree></p:cSld>
</p:sld>
''';
  String _slideRels() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>
''';
}
