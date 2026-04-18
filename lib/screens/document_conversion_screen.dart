import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/document_conversion_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import 'document_viewer_screen.dart';

/// CamScanner-style tools: office, images, text files, data files, merge & multi-image PDF.
class DocumentConversionScreen extends StatefulWidget {
  final String? filePath;

  const DocumentConversionScreen({super.key, this.filePath});

  @override
  State<DocumentConversionScreen> createState() =>
      _DocumentConversionScreenState();
}

class _DocumentConversionScreenState extends State<DocumentConversionScreen> {
  bool _isConverting = false;
  String _conversionType = 'word_to_pdf';
  String? _selectedFile;
  final List<String> _pickedPaths = [];
  final TextEditingController _textController = TextEditingController();

  final _conversionService = DocumentConversionService.instance;

  bool get _isMultiPick =>
      _conversionType == 'images_to_pdf' || _conversionType == 'merge_pdf';

  bool get _isTypedTextOnly => _conversionType == 'text_to_pdf';

  @override
  void initState() {
    super.initState();
    final fp = widget.filePath;
    if (fp != null && File(fp).existsSync()) {
      if (p.extension(fp).toLowerCase() == '.pdf') {
        _conversionType = 'merge_pdf';
      } else {
        _selectedFile = fp;
        _conversionType = _guessTypeFromPath(fp);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _guessTypeFromPath(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.doc' || ext == '.docx') return 'word_to_pdf';
    if (ext == '.ppt' || ext == '.pptx') return 'ppt_to_pdf';
    if (ext == '.xlsx' || ext == '.xls') return 'excel_to_pdf';
    if (ext == '.txt') return 'txt_file_to_pdf';
    if (ext == '.csv') return 'csv_to_pdf';
    if (ext == '.json') return 'json_to_pdf';
    if (ext == '.html' || ext == '.htm') return 'html_to_pdf';
    if (ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        ext == '.webp') {
      return 'image_to_pdf';
    }
    return 'image_to_pdf';
  }

  void _clearSelection() {
    _selectedFile = null;
    _pickedPaths.clear();
  }

  void _setType(String type) {
    setState(() {
      _conversionType = type;
      _clearSelection();
    });
  }

  Future<void> _pickFiles() async {
    List<String> extensions;
    switch (_conversionType) {
      case 'word_to_pdf':
        extensions = ['doc', 'docx'];
        break;
      case 'ppt_to_pdf':
        extensions = ['ppt', 'pptx'];
        break;
      case 'excel_to_pdf':
        extensions = ['xlsx', 'xls'];
        break;
      case 'image_to_pdf':
        extensions = ['jpg', 'jpeg', 'png', 'webp'];
        break;
      case 'images_to_pdf':
        extensions = ['jpg', 'jpeg', 'png', 'webp'];
        break;
      case 'txt_file_to_pdf':
        extensions = ['txt'];
        break;
      case 'csv_to_pdf':
        extensions = ['csv'];
        break;
      case 'json_to_pdf':
        extensions = ['json'];
        break;
      case 'html_to_pdf':
        extensions = ['html', 'htm'];
        break;
      case 'merge_pdf':
        extensions = ['pdf'];
        break;
      default:
        extensions = ['jpg', 'jpeg', 'png'];
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: _isMultiPick,
      );
      if (result == null || !mounted) return;
      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .where((path) => File(path).existsSync())
          .toList();
      setState(() {
        if (_isMultiPick) {
          _pickedPaths
            ..clear()
            ..addAll(paths);
          _selectedFile = null;
        } else {
          _selectedFile = paths.isEmpty ? null : paths.first;
          _pickedPaths.clear();
        }
      });
    } catch (e) {
      _showError('File picker error: $e');
    }
  }

  Future<int> _pageCountForPdf(String pdfPath) async {
    try {
      final doc = await pdfx.PdfDocument.openFile(pdfPath);
      try {
        return doc.pagesCount;
      } finally {
        await doc.close();
      }
    } catch (_) {
      return 1;
    }
  }

  Future<void> _convertFile() async {
    if (_isTypedTextOnly) {
      if (_textController.text.trim().isEmpty) {
        _showError('Please enter text first');
        return;
      }
    } else if (_isMultiPick) {
      if (_conversionType == 'merge_pdf' && _pickedPaths.length < 2) {
        _showError('Select at least 2 PDF files to merge');
        return;
      }
      if (_conversionType == 'images_to_pdf' && _pickedPaths.isEmpty) {
        _showError('Select one or more images');
        return;
      }
    } else if (_selectedFile == null) {
      _showError('Please select a file first');
      return;
    }

    setState(() => _isConverting = true);

    try {
      late final String outputPath;

      switch (_conversionType) {
        case 'word_to_pdf':
          outputPath =
              await _conversionService.convertWordToPdf(_selectedFile!);
          break;
        case 'ppt_to_pdf':
          outputPath = await _conversionService.convertPptToPdf(_selectedFile!);
          break;
        case 'excel_to_pdf':
          outputPath =
              await _conversionService.convertExcelToPdf(_selectedFile!);
          break;
        case 'image_to_pdf':
          outputPath =
              await _conversionService.convertImageToPdf(_selectedFile!);
          break;
        case 'images_to_pdf':
          outputPath = await _conversionService.convertMultipleImagesToPdf(
            List<String>.from(_pickedPaths),
            'ScanOnly_album',
          );
          break;
        case 'txt_file_to_pdf':
          outputPath =
              await _conversionService.convertTxtFileToPdf(_selectedFile!);
          break;
        case 'text_to_pdf':
          outputPath = await _conversionService.convertTextToPdf(
            _textController.text,
            fileName: 'typed_text',
          );
          break;
        case 'html_to_pdf':
          outputPath =
              await _conversionService.convertHtmlFileToPdf(_selectedFile!);
          break;
        case 'csv_to_pdf':
          outputPath =
              await _conversionService.convertCsvFileToPdf(_selectedFile!);
          break;
        case 'json_to_pdf':
          outputPath =
              await _conversionService.convertJsonFileToPdf(_selectedFile!);
          break;
        case 'merge_pdf':
          outputPath = await _conversionService.mergePdfFilesToOne(
            List<String>.from(_pickedPaths),
            'ScanOnly_merged',
          );
          break;
        default:
          outputPath =
              await _conversionService.convertImageToPdf(_selectedFile!);
      }

      if (!mounted) return;

      final pages = await _pageCountForPdf(outputPath);
      final size = await PdfService.instance.getFileSizeMB(outputPath);
      final newDoc = DocumentModel(
        name: p.basename(outputPath),
        filePath: outputPath,
        fileType: 'pdf',
        scanType: 'document',
        pageCount: pages,
        fileSizeMB: size,
        createdAt: DateTime.now(),
        tags: const ['Converted'],
      );
      final id = await DatabaseService.instance.insertDocument(newDoc);
      final saved = newDoc.copyWith(id: id);
      _showSuccess('Saved to library');
      setState(() {
        _selectedFile = null;
        _pickedPaths.clear();
      });
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(document: saved),
        ),
      );
    } catch (e) {
      _showError('Conversion failed: $e');
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Convert to PDF',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tools',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            _conversionTypeCard(
              'Word → PDF',
              'DOC, DOCX',
              Iconsax.document_text,
              'word_to_pdf',
              AppColors.blue,
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'PowerPoint → PDF',
              'PPT, PPTX',
              Iconsax.document,
              'ppt_to_pdf',
              AppColors.orange,
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'Excel → PDF',
              'XLS, XLSX (first sheet)',
              Icons.table_chart_outlined,
              'excel_to_pdf',
              const Color(0xFF217346),
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'Image → PDF',
              'One JPG / PNG / WebP',
              Iconsax.image,
              'image_to_pdf',
              AppColors.purple,
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'Images → PDF',
              'Multiple photos, one PDF',
              Iconsax.gallery,
              'images_to_pdf',
              const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'Text file → PDF',
              'Open a .txt file',
              Iconsax.note_text,
              'txt_file_to_pdf',
              AppColors.navyMid,
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'Type text → PDF',
              'Paste or type content',
              Iconsax.text_block,
              'text_to_pdf',
              AppColors.navyDark,
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'HTML → PDF',
              'HTML / HTM (text extracted)',
              Iconsax.code,
              'html_to_pdf',
              const Color(0xFFE34F26),
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'CSV → PDF',
              'Spreadsheet as table',
              Iconsax.row_vertical,
              'csv_to_pdf',
              const Color(0xFF0F766E),
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'JSON → PDF',
              'Pretty-printed',
              Iconsax.data,
              'json_to_pdf',
              const Color(0xFFCA8A04),
            ),
            const SizedBox(height: 8),
            _conversionTypeCard(
              'Merge PDFs',
              'Pick 2+ PDFs, one file',
              Iconsax.document_copy,
              'merge_pdf',
              AppColors.red,
            ),

            const SizedBox(height: 24),

            if (_isTypedTextOnly) ...[
              Text(
                'Text',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: 'Type or paste text…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ] else ...[
              Text(
                _isMultiPick ? 'Select files' : 'Select file',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isConverting ? null : _pickFiles,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _hasSelection() ? AppColors.gold : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _hasSelection()
                        ? AppColors.gold.withValues(alpha: 0.06)
                        : Colors.grey[50],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _hasSelection()
                            ? Iconsax.tick_circle
                            : Iconsax.document_upload,
                        size: 40,
                        color:
                            _hasSelection() ? AppColors.gold : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _pickerHint(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _hasSelection()
                              ? AppColors.gold
                              : AppColors.textDark,
                        ),
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          p.basename(_selectedFile!),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_pickedPaths.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_pickedPaths.length} files selected',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyMid,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pickedPaths.take(4).map(p.basename).join('\n'),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConverting ? null : _convertFile,
                icon: _isConverting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Iconsax.tick_circle),
                label: Text(
                  _isConverting ? 'Working…' : 'Convert & save to library',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyMid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Word/PPT here make a simple PDF cover sheet with the file name (like CamScanner quick export). '
                    'For pixel-perfect Office layout, open the file on a computer. '
                    'Images, text, CSV, JSON, Excel tables, merge and multi-image are processed on-device.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasSelection() =>
      _selectedFile != null || _pickedPaths.isNotEmpty;

  String _pickerHint() {
    if (_isMultiPick) {
      return _conversionType == 'merge_pdf'
          ? 'Tap to pick 2 or more PDFs'
          : 'Tap to pick one or more images';
    }
    return _selectedFile != null ? 'File selected' : 'Tap to pick a file';
  }

  Widget _conversionTypeCard(
    String title,
    String subtitle,
    IconData icon,
    String value,
    Color color,
  ) {
    final isSelected = _conversionType == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setType(value),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Iconsax.tick_circle, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
