import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_model.dart';
import '../models/whiteboard_scan_data.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/whiteboard_scan_service.dart';
import '../theme.dart';

class WhiteboardResultScreen extends StatefulWidget {
  final List<String> imagePaths;
  const WhiteboardResultScreen({super.key, required this.imagePaths});

  @override
  State<WhiteboardResultScreen> createState() => _WhiteboardResultScreenState();
}

class _WhiteboardResultScreenState extends State<WhiteboardResultScreen> {
  bool _loading = true;
  bool _busy = false;
  WhiteboardScanData _data = const WhiteboardScanData();
  String _activeImage = '';
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => _loading = true);
    try {
      final d = await WhiteboardScanService.instance.process(widget.imagePaths);
      if (!mounted) return;
      _data = d;
      _activeImage = d.cleanedImagePath.isEmpty ? widget.imagePaths.first : d.cleanedImagePath;
      _textCtrl.text = [d.text, d.handwritingText, d.urduText]
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join('\n');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _eraseColor(String color) async {
    if (_activeImage.isEmpty) return;
    final out = await WhiteboardScanService.instance.selectiveEraseColor(
      _activeImage,
      color,
    );
    if (!mounted) return;
    setState(() => _activeImage = out);
  }

  Future<void> _copyLatex() async {
    final text = _data.latexEquations.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LaTeX copied')),
    );
  }

  Future<String> _saveJson() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Whiteboard');
    await out.create(recursive: true);
    final file = File('${out.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(_data.toJsonMap()));
    return file.path;
  }

  Future<String> _saveDocx() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Whiteboard');
    await out.create(recursive: true);
    final path = '${out.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.docx';
    final zip = Archive();
    zip.addFile(ArchiveFile('[_Content_Types].xml', 0, utf8.encode(_contentTypes())));
    zip.addFile(ArchiveFile('_rels/.rels', 0, utf8.encode(_rels())));
    zip.addFile(ArchiveFile('word/document.xml', 0, utf8.encode(_docXml(_textCtrl.text))));
    final bytes = ZipEncoder().encode(zip);
    if (bytes == null) throw StateError('DOCX encode failed');
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<void> _exportAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pdf = await PdfService.instance.createSearchablePdf(
        [_activeImage],
        [_textCtrl.text],
        'Whiteboard',
      );
      final json = await _saveJson();
      final docx = await _saveDocx();
      final jpgOut = await _saveImageCopy('.jpg');
      final pngOut = await _saveImageCopy('.png');

      final thumb = await PdfService.instance.generateThumbnail(_activeImage);
      final size = await PdfService.instance.getFileSizeMB(pdf);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: 'Whiteboard.pdf',
          filePath: pdf,
          fileType: 'pdf',
          scanType: 'whiteboard',
          pageCount: widget.imagePaths.length,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: _textCtrl.text,
          tags: const ['Whiteboard', 'Notes'],
        ),
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(pdf), XFile(jpgOut), XFile(pngOut), XFile(docx), XFile(json)],
        text: 'Whiteboard scan export',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported PDF/JPG/PNG/DOCX/JSON')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _saveImageCopy(String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Whiteboard');
    await out.create(recursive: true);
    final file = File('${out.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}$ext');
    final bytes = await File(_activeImage).readAsBytes();
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Whiteboard Scan', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
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
                  _imagePreview(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip('Erase Red', () => _eraseColor('red')),
                      _chip('Erase Blue', () => _eraseColor('blue')),
                      _chip('Erase Green', () => _eraseColor('green')),
                      _chip('Erase Black', () => _eraseColor('black')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _zonesCard(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textCtrl,
                    maxLines: 10,
                    style: GoogleFonts.nunito(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Extracted content',
                      labelStyle: GoogleFonts.nunito(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF141E31),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_data.latexEquations.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101826),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('LaTeX Equations',
                                    style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                              TextButton(onPressed: _copyLatex, child: const Text('Copy')),
                            ],
                          ),
                          Text(_data.latexEquations.join('\n'),
                              style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navyDark,
                    ),
                    onPressed: _busy ? null : _exportAll,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Export & Share'),
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
          Text('Smart Whiteboard Processing',
              style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Glare removed: ${_data.glareReduced ? 'Yes' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Background whitened: ${_data.backgroundWhitened ? 'Yes' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Perspective corrected: ${_data.perspectiveCorrected ? 'Yes' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Multi-shot stitched: ${_data.stitchedMultiShot ? 'Yes' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Flowchart: ${_data.hasFlowchart ? 'Detected' : 'No'} | Table: ${_data.hasDrawnTable ? 'Detected' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('Equation: ${_data.hasEquation ? 'Detected' : 'No'} | Arrows: ${_data.hasArrows ? 'Detected' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
          Text('RTL: ${_data.rtlDetected ? 'Yes' : 'No'} | Mixed Urdu+English: ${_data.mixedLanguage ? 'Yes' : 'No'}',
              style: GoogleFonts.nunito(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(_activeImage), fit: BoxFit.cover),
      ),
    );
  }

  Widget _zonesCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content Zones',
              style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ..._data.zones.take(10).map(
                (z) => Text(
                  '• ${z.type}: ${z.snippet}',
                  style: GoogleFonts.nunito(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: _busy ? null : onTap,
    );
  }

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

  String _docXml(String text) {
    final lines = text
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => '<w:p><w:r><w:t>${_esc(e)}</w:t></w:r></w:p>')
        .join('\n');
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  $lines
 </w:body>
</w:document>
''';
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

