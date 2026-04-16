import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import '../services/file_manager_service.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';

class ImportDocumentsScreen extends StatefulWidget {
  const ImportDocumentsScreen({super.key});

  @override
  State<ImportDocumentsScreen> createState() => _ImportDocumentsScreenState();
}

class _ImportDocumentsScreenState extends State<ImportDocumentsScreen> {
  List<FileSystemEntity> _deviceFiles = [];
  bool _isLoading = false;
  bool _isImporting = false;
  final _fileManager = FileManagerService.instance;

  @override
  void initState() {
    super.initState();
    _loadDeviceDocuments();
  }

  Future<void> _loadDeviceDocuments() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final files = await _fileManager.getAllDocumentsFromDevice();
      if (mounted) {
        setState(() {
          _deviceFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load documents: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importDocument(FileSystemEntity file) async {
    if (!mounted) return;

    setState(() => _isImporting = true);

    try {
      final filePath = file.path;
      final fileName = _fileManager.getFileName(filePath);
      final fileSize = await _fileManager.getFileSizeMB(filePath);
      final extension = _fileManager.getFileExtension(filePath);

      // Generate thumbnail if it's an image
      String? thumbPath;
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
        thumbPath = filePath;
      }

      // Create document model
      final doc = DocumentModel(
        name: fileName,
        filePath: filePath,
        fileType: extension,
        scanType: 'imported',
        pageCount: 1,
        fileSizeMB: fileSize,
        createdAt: DateTime.now(),
        thumbnailPath: thumbPath,
      );

      // Save to database
      await DatabaseService.instance.insertDocument(doc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName imported successfully!'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _importMultipleDocuments() async {
    if (!mounted) return;

    setState(() => _isImporting = true);

    try {
      final selectedFiles = await _fileManager.pickMultipleDocuments();

      if (selectedFiles.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      int imported = 0;
      for (final filePath in selectedFiles) {
        final fileName = _fileManager.getFileName(filePath);
        final fileSize = await _fileManager.getFileSizeMB(filePath);
        final extension = _fileManager.getFileExtension(filePath);

        String? thumbPath;
        if (['jpg', 'jpeg', 'png'].contains(extension)) {
          thumbPath = filePath;
        }

        final doc = DocumentModel(
          name: fileName,
          filePath: filePath,
          fileType: extension,
          scanType: 'imported',
          pageCount: 1,
          fileSizeMB: fileSize,
          createdAt: DateTime.now(),
          thumbnailPath: thumbPath,
        );

        await DatabaseService.instance.insertDocument(doc);
        imported++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported == 1
                ? '1 document imported!'
                : '$imported documents imported!'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadDeviceDocuments();
      }
    } catch (e) {
      _showError('Batch import failed: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // FIX: New method — uses image_picker for reliable multi-image select on Android/iOS
  Future<void> _importMultipleImages() async {
    if (!mounted) return;

    setState(() => _isImporting = true);

    try {
      final images = await _fileManager.pickMultipleImages();

      if (images.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      int imported = 0;
      for (final imagePath in images) {
        final fileName = _fileManager.getFileName(imagePath);
        final fileSize = await _fileManager.getFileSizeMB(imagePath);
        final extension = _fileManager.getFileExtension(imagePath);

        final doc = DocumentModel(
          name: fileName,
          filePath: imagePath,
          fileType: extension,
          scanType: 'imported',
          pageCount: 1,
          fileSizeMB: fileSize,
          createdAt: DateTime.now(),
          thumbnailPath: imagePath,
        );

        await DatabaseService.instance.insertDocument(doc);
        imported++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported == 1
                ? '1 photo imported!'
                : '$imported photos imported!'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadDeviceDocuments();
      }
    } catch (e) {
      _showError('Photo import failed: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text(
          'Import Documents',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isImporting)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadDeviceDocuments,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text(
                    'Loading documents...',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // FIX: Pick any files (FileType.any allows multi-select on Android)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isImporting ? null : _importMultipleDocuments,
                              icon: const Icon(Iconsax.document, color: Colors.white, size: 18),
                              label: Text(
                                'Pick Documents',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                disabledBackgroundColor: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // FIX: Separate image picker using image_picker (more reliable on Android)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isImporting ? null : _importMultipleImages,
                              icon: const Icon(Iconsax.image, color: Colors.white, size: 18),
                              label: Text(
                                'Pick Photos',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                disabledBackgroundColor: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isImporting ? null : _loadDeviceDocuments,
                          icon: const Icon(Iconsax.refresh, color: Colors.white, size: 18),
                          label: Text(
                            'Scan Device Storage',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navyMid,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Documents List
                Expanded(
                  child: _deviceFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.document,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No documents found',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Pick Files" to import documents',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _deviceFiles.length,
                          itemBuilder: (_, i) {
                            final file = _deviceFiles[i];
                            final fileName = _fileManager.getFileName(file.path);
                            final extension = _fileManager.getFileExtension(file.path);

                            return GestureDetector(
                              onTap: _isImporting ? null : () => _importDocument(file),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: _getFileColor(extension).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _getFileIcon(extension),
                                          color: _getFileColor(extension),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            style: GoogleFonts.nunito(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            extension.toUpperCase(),
                                            style: GoogleFonts.nunito(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Iconsax.arrow_right,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Iconsax.document;
      case 'doc':
      case 'docx':
        return Iconsax.document_text;
      case 'xls':
      case 'xlsx':
        return Iconsax.document;
      case 'ppt':
      case 'pptx':
        return Iconsax.document;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Iconsax.image;
      case 'txt':
        return Iconsax.document_text;
      default:
        return Iconsax.document;
    }
  }

  Color _getFileColor(String extension) {
    switch (extension) {
      case 'pdf':
        return AppColors.red;
      case 'doc':
      case 'docx':
        return AppColors.blue;
      case 'xls':
      case 'xlsx':
        return AppColors.green;
      case 'ppt':
      case 'pptx':
        return AppColors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return AppColors.purple;
      case 'txt':
        return AppColors.navyMid;
      default:
        return AppColors.gold;
    }
  }
}
