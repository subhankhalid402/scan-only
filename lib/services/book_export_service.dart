import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book_scan_data.dart';

class BookExportService {
  BookExportService._();
  static final BookExportService instance = BookExportService._();

  Future<String> exportTxt(BookScanData data, {String stem = 'BookScan'}) async {
    final dir = await _ensureDir();
    final path = '${dir.path}/${stem}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final b = StringBuffer();
    if (data.title.isNotEmpty) {
      b.writeln(data.title);
      b.writeln('=' * data.title.length);
      b.writeln();
    }
    for (final p in data.pages) {
      b.writeln('--- Page ${p.pageIndex + 1} ${p.pageNumber.isEmpty ? '' : '(No ${p.pageNumber})'} ---');
      if (p.heading.isNotEmpty) b.writeln(p.heading);
      b.writeln(p.text);
      b.writeln();
    }
    await File(path).writeAsString(b.toString());
    return path;
  }

  Future<String> exportDocx(BookScanData data, {String stem = 'BookScan'}) async {
    final dir = await _ensureDir();
    final path = '${dir.path}/${stem}_${DateTime.now().millisecondsSinceEpoch}.docx';
    final zip = Archive();
    zip.addFile(ArchiveFile('[_Content_Types].xml', 0, utf8.encode(_contentTypes())));
    zip.addFile(ArchiveFile('_rels/.rels', 0, utf8.encode(_rels())));
    zip.addFile(ArchiveFile('word/document.xml', 0, utf8.encode(_docXml(data))));
    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('DOCX encode failed');
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<String> exportEpub(BookScanData data, {String stem = 'BookScan'}) async {
    final dir = await _ensureDir();
    final path = '${dir.path}/${stem}_${DateTime.now().millisecondsSinceEpoch}.epub';
    final zip = Archive();
    zip.addFile(ArchiveFile('mimetype', 20, utf8.encode('application/epub+zip')));
    zip.addFile(ArchiveFile('META-INF/container.xml', 0, utf8.encode(_epubContainer())));
    zip.addFile(ArchiveFile('OEBPS/content.opf', 0, utf8.encode(_contentOpf(data))));
    zip.addFile(ArchiveFile('OEBPS/nav.xhtml', 0, utf8.encode(_navXhtml(data))));
    for (final p in data.pages) {
      zip.addFile(ArchiveFile(
        'OEBPS/page_${p.pageIndex + 1}.xhtml',
        0,
        utf8.encode(_pageXhtml(p)),
      ));
    }
    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('EPUB encode failed');
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<String> exportJson(BookScanData data, {String stem = 'BookScan'}) async {
    final dir = await _ensureDir();
    final path = '${dir.path}/${stem}_${DateTime.now().millisecondsSinceEpoch}.json';
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJsonMap()),
    );
    return path;
  }

  Future<Directory> _ensureDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/ScanOnly/Books');
    await dir.create(recursive: true);
    return dir;
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _contentTypes() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
''';

  String _rels() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
''';

  String _docXml(BookScanData data) {
    final body = StringBuffer();
    if (data.title.isNotEmpty) {
      body.writeln('<w:p><w:r><w:t>${_esc(data.title)}</w:t></w:r></w:p>');
    }
    for (final p in data.pages) {
      body.writeln('<w:p><w:r><w:t>Page ${p.pageIndex + 1}</w:t></w:r></w:p>');
      if (p.heading.isNotEmpty) {
        body.writeln('<w:p><w:r><w:t>${_esc(p.heading)}</w:t></w:r></w:p>');
      }
      for (final line in p.text.split('\n')) {
        if (line.trim().isEmpty) continue;
        body.writeln('<w:p><w:r><w:t>${_esc(line)}</w:t></w:r></w:p>');
      }
    }
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:w10="urn:schemas-microsoft-com:office:word"
 xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  $body
 </w:body>
</w:document>
''';
  }

  String _epubContainer() => '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

  String _contentOpf(BookScanData data) {
    final items = data.pages
        .map(
          (p) =>
              '<item id="p${p.pageIndex + 1}" href="page_${p.pageIndex + 1}.xhtml" media-type="application/xhtml+xml"/>',
        )
        .join('\n');
    final spine = data.pages
        .map((p) => '<itemref idref="p${p.pageIndex + 1}"/>')
        .join('\n');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="BookId">bookscan-${DateTime.now().millisecondsSinceEpoch}</dc:identifier>
    <dc:title>${_esc(data.title.isEmpty ? 'Scanned Book' : data.title)}</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    $items
  </manifest>
  <spine>
    $spine
  </spine>
</package>
''';
  }

  String _navXhtml(BookScanData data) {
    final li = data.pages
        .map(
          (p) => '<li><a href="page_${p.pageIndex + 1}.xhtml">Page ${p.pageIndex + 1}</a></li>',
        )
        .join('\n');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>TOC</title></head>
  <body>
    <nav epub:type="toc" id="toc">
      <h1>Table of Contents</h1>
      <ol>
        $li
      </ol>
    </nav>
  </body>
</html>
''';
  }

  String _pageXhtml(BookPageData page) {
    final lines = page.text
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => '<p>${_esc(e)}</p>')
        .join('\n');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Page ${page.pageIndex + 1}</title></head>
  <body>
    <h2>Page ${page.pageIndex + 1}</h2>
    ${page.heading.isNotEmpty ? '<h3>${_esc(page.heading)}</h3>' : ''}
    $lines
  </body>
</html>
''';
  }
}

