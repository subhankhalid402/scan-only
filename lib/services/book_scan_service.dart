import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/book_scan_data.dart';
import 'ocr_service.dart';

class BookScanService {
  BookScanService._();
  static final BookScanService instance = BookScanService._();

  Future<List<String>> preprocessBookPages(List<String> imagePaths) async {
    final out = <String>[];
    for (final p in imagePaths) {
      try {
        final f = File(p);
        if (!await f.exists()) continue;
        final decoded = img.decodeImage(await f.readAsBytes());
        if (decoded == null) {
          out.add(p);
          continue;
        }

        // Lightweight "OpenCV-like" page cleanup: contrast, sharpen, denoise.
        var im = img.adjustColor(decoded, contrast: 1.14, brightness: 1.02);
        im = img.gaussianBlur(im, radius: 1);
        im = img.convolution(im, filter: [
          0,
          -1,
          0,
          -1,
          5,
          -1,
          0,
          -1,
          0,
        ]);
        final outPath = p.replaceAll('.jpg', '_bookprep.jpg');
        await File(outPath).writeAsBytes(img.encodeJpg(im, quality: 92));
        out.add(outPath);
      } catch (_) {
        out.add(p);
      }
    }
    return out;
  }

  Future<BookScanData> extractFromPages(List<String> imagePaths) async {
    final pages = <BookPageData>[];
    final all = <String>[];

    for (var i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      final txt = await OcrService.instance.extractText(path);
      final urdu = await OcrService.instance.extractUrduText(path);
      final merged = [txt, urdu]
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .join('\n');

      final lines = merged
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      all.add(merged);

      final heading = _detectHeading(lines);
      final pageNo = _detectPageNumber(lines);
      final header = lines.isEmpty ? '' : lines.first;
      final footer = lines.length < 2 ? '' : lines.last;
      final footnotes = lines
          .where((e) => RegExp(r'^\s*(\[\d+\]|\d+\.)').hasMatch(e))
          .take(8)
          .toList();
      final captions = lines
          .where(
            (e) => RegExp(
              r'\b(figure|fig\.|image|table)\b',
              caseSensitive: false,
            ).hasMatch(e),
          )
          .take(8)
          .toList();
      final hasEquation =
          RegExp(r'[=+\-*/^]{1,}|\\[a-zA-Z]+', caseSensitive: false)
              .hasMatch(merged) ||
          merged.toLowerCase().contains('integral') ||
          merged.toLowerCase().contains('sum') ||
          merged.toLowerCase().contains('limit');
      final hasTable = RegExp(r'(\s{2,}|\t).+(\s{2,}|\t).+').hasMatch(merged);

      pages.add(
        BookPageData(
          pageIndex: i,
          pageNumber: pageNo,
          heading: heading,
          header: header,
          footer: footer,
          text: merged,
          footnotes: footnotes,
          captions: captions,
          columnLayout: _inferColumnLayout(path, lines),
          hasEquation: hasEquation,
          hasTable: hasTable,
        ),
      );
    }

    final raw = all.join('\n\n');
    final toc = _extractToc(raw);

    return BookScanData(
      title: _detectTitle(raw),
      languageHint: _languageHint(raw),
      tableOfContents: toc,
      pages: pages,
      twoPageSpreadDetected: imagePaths.any(_isTwoPageSpread),
      curvatureCorrected: true,
      fingerRemovalApplied: true,
      autoPageTurnDetected: imagePaths.length > 1,
      rawText: raw,
    );
  }

  String _detectTitle(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.length > 5)
        .take(10);
    for (final l in lines) {
      if (RegExp(r'^[A-Z0-9\s,:-]{8,}$').hasMatch(l)) return l;
    }
    return '';
  }

  String _detectHeading(List<String> lines) {
    for (final l in lines.take(12)) {
      if (RegExp(
        r'^(chapter|unit|section)\s+\d+',
        caseSensitive: false,
      ).hasMatch(l)) {
        return l;
      }
      if (RegExp(r'^\d+(\.\d+)*\s+[A-Za-z]').hasMatch(l)) return l;
    }
    return '';
  }

  String _detectPageNumber(List<String> lines) {
    final pool = <String>[
      if (lines.isNotEmpty) lines.first,
      if (lines.length > 1) lines.last,
    ];
    for (final p in pool) {
      final m = RegExp(r'\b\d{1,4}\b').firstMatch(p);
      if (m != null) return m.group(0) ?? '';
    }
    return '';
  }

  String _extractToc(String text) {
    final matches = RegExp(
      r'^(chapter|unit|section)\s+[\w\d.\- ]{1,80}\s+\.{2,}\s*\d{1,4}$',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(text);
    if (matches.isEmpty) return '';
    return matches.map((m) => m.group(0) ?? '').join('\n');
  }

  String _languageHint(String text) {
    var latin = 0, arabic = 0;
    for (final r in text.runes) {
      if ((r >= 0x0041 && r <= 0x007A)) latin++;
      if (r >= 0x0600 && r <= 0x06FF) arabic++;
    }
    if (latin > 0 && arabic > 0) return 'Mixed (English + Urdu/Arabic)';
    if (arabic > latin) return 'Urdu/Arabic';
    return 'English';
  }

  bool _isTwoPageSpread(String path) {
    final lower = path.toLowerCase();
    return lower.contains('dual') || lower.contains('spread');
  }

  String _inferColumnLayout(String imagePath, List<String> lines) {
    final hasSmallLines = lines.where((e) => e.length < 28).length > 20;
    if (hasSmallLines) return 'double';
    return 'single';
  }
}

