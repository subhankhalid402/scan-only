import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_local_storage.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../models/document_model.dart';
import '../theme.dart';
import 'document_viewer_screen.dart';
import 'edit_scan_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final String? initialSharedFile;
  final List<String>? initialSharedFiles;
  const SplashScreen({
    super.key,
    this.initialSharedFile,
    this.initialSharedFiles,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      final done = AppLocalStorage.getBool(OnboardingScreen.kOnboardingPrefsKey);
      if (!mounted) return;

      if (!done) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      // Handle multiple shared files
      final multiFiles = widget.initialSharedFiles;
      if (multiFiles != null && multiFiles.isNotEmpty) {
        await _handleMultipleFiles(multiFiles);
        return;
      }

      // Handle single shared file
      final shared = widget.initialSharedFile;
      if (shared != null && shared.isNotEmpty) {
        await _handleSingleFile(shared);
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  /// Handles any single file - images, PDFs, docs, etc.
  Future<void> _handleSingleFile(String filePath) async {
    if (!mounted) return;

    // Resolve content:// URI or file:// URI to actual path
    final resolvedPath = _resolveFilePath(filePath);
    final ext = _getExtension(resolvedPath);

    // Images → open in edit/scan editor
    if (_isImage(ext)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditScanScreen(
            imagePaths: [resolvedPath],
            scanType: 'document',
          ),
        ),
      );
      return;
    }

    // All other files → import into library and open viewer
    await _importAndOpenFile(resolvedPath);
  }

  /// Handles multiple shared files
  Future<void> _handleMultipleFiles(List<String> filePaths) async {
    if (!mounted) return;

    final resolvedPaths = filePaths.map(_resolveFilePath).toList();
    final allImages = resolvedPaths.every((p) => _isImage(_getExtension(p)));

    // All images → open in scan editor for multi-page PDF creation
    if (allImages) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditScanScreen(
            imagePaths: resolvedPaths,
            scanType: 'document',
          ),
        ),
      );
      return;
    }

    // Mixed or non-image files → import first one and open viewer
    if (resolvedPaths.isNotEmpty) {
      await _importAndOpenFile(resolvedPaths.first);
    }
  }

  /// Imports a file into the library and opens it in the document viewer.
  Future<void> _importAndOpenFile(String filePath) async {
    if (!mounted) return;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        _goHome();
        return;
      }

      final ext = _getExtension(filePath);
      final fileName = filePath.split('/').last;
      final sizeMB = file.lengthSync() / (1024 * 1024);

      // Generate thumbnail for PDFs
      String? thumbnailPath;
      if (ext == 'pdf') {
        try {
          thumbnailPath = await PdfService.instance.generateThumbnail(filePath);
        } catch (_) {}
      }

      final doc = DocumentModel(
        name: fileName,
        filePath: filePath,
        fileType: ext,
        scanType: _scanTypeForExt(ext),
        pageCount: 1,
        fileSizeMB: sizeMB,
        createdAt: DateTime.now(),
        thumbnailPath: thumbnailPath,
        tags: const [],
      );

      // Save to library
      final id = await DatabaseService.instance.insertDocument(doc);
      final savedDoc = doc.copyWith(id: id);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(document: savedDoc),
        ),
      );
    } catch (_) {
      _goHome();
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  String _resolveFilePath(String path) {
    // Strip file:// prefix if present
    if (path.startsWith('file://')) {
      return Uri.parse(path).toFilePath();
    }
    return path;
  }

  String _getExtension(String path) {
    final parts = path.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  bool _isImage(String ext) =>
      ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';

  String _scanTypeForExt(String ext) {
    switch (ext) {
      case 'pdf':
        return 'document';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return 'photo';
      case 'doc':
      case 'docx':
        return 'document';
      case 'xls':
      case 'xlsx':
        return 'table';
      case 'ppt':
      case 'pptx':
        return 'document';
      case 'txt':
      case 'csv':
        return 'document';
      default:
        return 'document';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navyDark,
              AppColors.navyMid,
              AppColors.navyLight,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.28),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.30),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/images/launcher_icon.png',
                        width: 108,
                        height: 108,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'ScanOnly',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Scan. Enhance. Share.',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
