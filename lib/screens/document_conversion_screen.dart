import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/document_conversion_service.dart';
import '../services/pdf_service.dart';
import 'document_viewer_screen.dart';

class DocumentConversionScreen extends StatefulWidget {
  final String? filePath;
  
  const DocumentConversionScreen({super.key, this.filePath});

  @override
  State<DocumentConversionScreen> createState() => _DocumentConversionScreenState();
}

class _DocumentConversionScreenState extends State<DocumentConversionScreen> {
  bool _isConverting = false;
  String? _selectedFile;
  String _conversionType = 'word_to_pdf';
  final TextEditingController _textController = TextEditingController();

  final _conversionService = DocumentConversionService.instance;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.filePath;
    if (_selectedFile != null) {
      _conversionType = _guessTypeFromPath(_selectedFile!);
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
    if (ext == '.txt') return 'text_to_pdf';
    return 'image_to_pdf';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _conversionType == 'word_to_pdf'
            ? ['doc', 'docx']
            : _conversionType == 'ppt_to_pdf'
                ? ['ppt', 'pptx']
                : _conversionType == 'text_to_pdf'
                    ? ['txt']
                    : ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedFile = result.files.first.path);
      }
    } catch (e) {
      _showError('File picker error: $e');
    }
  }

  Future<void> _convertFile() async {
    if (_conversionType == 'text_to_pdf') {
      if (_textController.text.trim().isEmpty) {
        _showError('Please enter text first');
        return;
      }
    } else if (_selectedFile == null) {
      _showError('Please select a file first');
      return;
    }

    setState(() => _isConverting = true);

    try {
      String outputPath;

      if (_conversionType == 'word_to_pdf') {
        outputPath = await _conversionService.convertWordToPdf(_selectedFile!);
      } else if (_conversionType == 'ppt_to_pdf') {
        outputPath = await _conversionService.convertPptToPdf(_selectedFile!);
      } else if (_conversionType == 'text_to_pdf') {
        outputPath = await _conversionService.convertTextToPdf(
          _textController.text,
          fileName: 'typed_text',
        );
      } else {
        outputPath = await _conversionService.convertImageToPdf(_selectedFile!);
      }

      if (mounted) {
        final size = await PdfService.instance.getFileSizeMB(outputPath);
        final newDoc = DocumentModel(
          name: p.basename(outputPath),
          filePath: outputPath,
          fileType: 'pdf',
          scanType: 'document',
          pageCount: 1,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          tags: const [],
        );
        final id = await DatabaseService.instance.insertDocument(newDoc);
        final saved = newDoc.copyWith(id: id);
        _showSuccess('Conversion successful!');
        setState(() => _selectedFile = null);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: saved)),
        );
      }
    } catch (e) {
      _showError('Conversion failed: $e');
    } finally {
      setState(() => _isConverting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Conversion', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conversion Type Selection
            Text(
              'Select Conversion Type',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            _conversionTypeCard(
              'Word to PDF',
              'Convert .docx files to PDF',
              Iconsax.document_text,
              'word_to_pdf',
              AppColors.blue,
            ),
            const SizedBox(height: 10),

            _conversionTypeCard(
              'PowerPoint to PDF',
              'Convert .pptx files to PDF',
              Iconsax.document,
              'ppt_to_pdf',
              AppColors.orange,
            ),
            const SizedBox(height: 10),

            _conversionTypeCard(
              'Image to PDF',
              'Convert images to PDF',
              Iconsax.image,
              'image_to_pdf',
              AppColors.purple,
            ),
            const SizedBox(height: 10),

            _conversionTypeCard(
              'Text to PDF',
              'Convert typed text to PDF',
              Iconsax.text,
              'text_to_pdf',
              AppColors.navyMid,
            ),

            const SizedBox(height: 30),

            // File Selection
            if (_conversionType != 'text_to_pdf') ...[
              Text(
                'Select File',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isConverting ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedFile != null ? AppColors.gold : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: _selectedFile != null ? AppColors.gold.withOpacity(0.05) : Colors.grey[50],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Iconsax.tick_circle : Iconsax.document_upload,
                        size: 40,
                        color: _selectedFile != null ? AppColors.gold : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFile != null ? 'File Selected' : 'Tap to Select File',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedFile != null ? AppColors.gold : AppColors.textDark,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Type Text',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Enter text to convert into PDF...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],

            const SizedBox(height: 30),

            // Convert Button
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Iconsax.convert),
                label: Text(
                  _isConverting ? 'Converting...' : 'Convert to PDF',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyMid,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supported Formats',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Word: .docx\n• PowerPoint: .pptx\n• Images: .jpg, .jpeg, .png',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
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

  Widget _conversionTypeCard(
    String title,
    String subtitle,
    IconData icon,
    String value,
    Color color,
  ) {
    final isSelected = _conversionType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _conversionType = value;
        _selectedFile = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
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
                color: color.withOpacity(0.2),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
              Icon(Iconsax.tick_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
