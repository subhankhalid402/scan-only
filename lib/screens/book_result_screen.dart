import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/book_scan_data.dart';
import '../models/document_model.dart';
import '../services/book_export_service.dart';
import '../services/book_scan_service.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/translation_service.dart';
import '../theme.dart';

class BookResultScreen extends StatefulWidget {
  final List<String> imagePaths;
  const BookResultScreen({super.key, required this.imagePaths});

  @override
  State<BookResultScreen> createState() => _BookResultScreenState();
}

class _BookResultScreenState extends State<BookResultScreen> {
  bool _loading = true;
  bool _busy = false;
  BookScanData _data = const BookScanData();
  String _search = '';
  String _translated = '';
  final Set<int> _bookmarks = {};

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final prepared = await BookScanService.instance.preprocessBookPages(
        widget.imagePaths,
      );
      final d = await BookScanService.instance.extractFromPages(prepared);
      if (!mounted) return;
      setState(() => _data = d);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _translate(String target) async {
    if (_data.rawText.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final out = await TranslationService.instance.translateToNamedLanguage(
        _data.rawText,
        target,
      );
      if (!mounted) return;
      setState(() => _translated = out);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translated to $target')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation failed')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final stem =
          (_data.title.isEmpty ? 'BookScan' : _data.title).replaceAll(' ', '_');
      final pdf = await PdfService.instance.createSearchablePdf(
        widget.imagePaths,
        _data.pages.map((e) => e.text).toList(),
        stem,
      );
      final txt = await BookExportService.instance.exportTxt(_data, stem: stem);
      final docx = await BookExportService.instance.exportDocx(_data, stem: stem);
      final epub = await BookExportService.instance.exportEpub(_data, stem: stem);
      final json = await BookExportService.instance.exportJson(_data, stem: stem);

      final thumb = await PdfService.instance.generateThumbnail(widget.imagePaths.first);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$stem.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'book',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: _data.rawText,
          tags: const ['Book', 'OCR'],
        ),
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(pdf), XFile(docx), XFile(txt), XFile(epub), XFile(json)],
        text: 'Book scan exports',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported searchable PDF, DOCX, TXT, EPUB')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _data.pages;
    final filtered = _search.trim().isEmpty
        ? pages
        : pages.where((p) => p.text.toLowerCase().contains(_search.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Book Scanner', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 10),
                  _searchBox(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _translate('Urdu'),
                          icon: const Icon(Icons.translate_rounded),
                          label: const Text('EN -> Urdu'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _translate('English'),
                          icon: const Icon(Icons.translate_rounded),
                          label: const Text('Urdu -> EN'),
                        ),
                      ),
                    ],
                  ),
                  if (_translated.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _translatedCard(),
                  ],
                  const SizedBox(height: 10),
                  ...filtered.map(_pageTile),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navyDark,
                    ),
                    onPressed: _busy ? null : _exportAll,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Export Portfolio'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
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
          Text(
            _data.title.isEmpty ? 'Book scan summary' : _data.title,
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Language: ${_data.languageHint}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Pages: ${_data.pages.length}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Curvature correction: ${_data.curvatureCorrected ? 'Applied' : 'No'}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Finger edge removal: ${_data.fingerRemovalApplied ? 'Applied' : 'No'}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Two-page spread: ${_data.twoPageSpreadDetected ? 'Detected' : 'Not detected'}', style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Auto page-turn: ${_data.autoPageTurnDetected ? 'Detected' : 'No'}', style: GoogleFonts.nunito(color: Colors.white70)),
          if (_data.tableOfContents.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('TOC', style: GoogleFonts.nunito(color: AppColors.gold, fontWeight: FontWeight.w800)),
            Text(_data.tableOfContents, style: GoogleFonts.nunito(color: Colors.white60)),
          ],
          const SizedBox(height: 6),
          Text('TTS: Ready for integration (platform speech engine)', style: GoogleFonts.nunito(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (v) => setState(() => _search = v),
      style: GoogleFonts.nunito(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search within scanned book',
        hintStyle: GoogleFonts.nunito(color: Colors.white38),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF141E31),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _translatedCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF17233A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        _translated.length > 1200 ? '${_translated.substring(0, 1200)}...' : _translated,
        style: GoogleFonts.nunito(color: Colors.white70),
      ),
    );
  }

  Widget _pageTile(BookPageData p) {
    final bookmarked = _bookmarks.contains(p.pageIndex);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 52,
          child: Image.file(File(widget.imagePaths[p.pageIndex]), fit: BoxFit.cover),
        ),
        title: Text(
          'Page ${p.pageIndex + 1} ${p.pageNumber.isNotEmpty ? "(#${p.pageNumber})" : ""}',
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${p.heading.isEmpty ? 'No heading' : p.heading}\nLayout: ${p.columnLayout} | Eq:${p.hasEquation ? "Y" : "N"} | Tbl:${p.hasTable ? "Y" : "N"}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(color: Colors.white60, fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: () {
            setState(() {
              if (bookmarked) {
                _bookmarks.remove(p.pageIndex);
              } else {
                _bookmarks.add(p.pageIndex);
              }
            });
          },
          icon: Icon(
            bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: bookmarked ? AppColors.gold : Colors.white54,
          ),
        ),
        onTap: () => _showPageDetails(p),
      ),
    );
  }

  Future<void> _showPageDetails(BookPageData p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1422),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Text(
              p.text,
              style: GoogleFonts.nunito(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

