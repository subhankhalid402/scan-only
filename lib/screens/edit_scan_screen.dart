import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/app_local_storage.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/image_enhancement_service.dart';
import 'text_extraction_screen.dart';
import 'manual_erase_screen.dart';
import '../services/smart_erase_service.dart';
import 'signature_pad_screen.dart';
import 'advanced_filters_screen.dart';
import 'annotation_screen.dart';
import '../services/watermark_service.dart';
import '../widgets/watermark_composer_sheet.dart';
import '../services/ocr_service.dart';
import 'document_viewer_screen.dart';
import 'advanced_sharing_screen.dart';

class EditScanScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String scanType;

  const EditScanScreen({
    super.key,
    required this.imagePaths,
    required this.scanType,
  });

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

class _EditScanScreenState extends State<EditScanScreen> {
  late List<String> _pages;
  late List<String> _originalPages;
  int _currentPage = 0;
  bool _isSaving = false;
  bool _isProcessing = false;
  bool _showTimestampOption = false;
  late TextEditingController _nameController;
  late PageController _pageController;
  /// Tags chosen in the save sheet (saved with the document).
  final List<String> _saveDraftTags = [];

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.imagePaths);
    _originalPages = List.from(widget.imagePaths);
    _pageController = PageController();
    _nameController = TextEditingController(text: _defaultNameForScanType());
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyLastSavedNameHint());
  }

  Future<void> _applyLastSavedNameHint() async {
    final last = AppLocalStorage.getStringOrNull('lastSavedDocName');
    if (!mounted || last == null || last.isEmpty) return;
    setState(() => _nameController.text = last);
  }

  Future<void> _enhanceAllPages() async {
    if (_pages.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final next = <String>[];
      for (final path in _pages) {
        final out = await ImageEnhancementService.instance
            .polishCaptureForScanMode(path, widget.scanType, filter: 'auto');
        next.add(out);
      }
      if (!mounted) return;
      for (var i = 0; i < _pages.length; i++) {
        try {
          FileImage(File(_pages[i])).evict();
        } catch (_) {}
      }
      setState(() {
        for (var i = 0; i < _pages.length; i++) {
          _pages[i] = next[i];
          _originalPages[i] = next[i];
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-fix applied to all ${_pages.length} page(s).',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _defaultNameForScanType() {
    final n = DateTime.now();
    final d = '${n.day}-${n.month}-${n.year}';
    switch (widget.scanType) {
      case 'document':
        return 'Document_$d';
      case 'receipt':
        return 'Receipt_$d';
      case 'id_card':
        return 'ID_$d';
      case 'passport':
        return 'Passport_$d';
      case 'book':
        return 'Book_$d';
      case 'table':
        return 'Table_$d';
      case 'whiteboard':
        return 'Whiteboard_$d';
      case 'photo':
        return 'Photo_$d';
      case 'gallery':
        return 'Import_$d';
      case 'merged':
        return 'Merged_$d';
      default:
        return 'Scan_$d';
    }
  }

  /// Index first pages for library search (background).
  void _scheduleOcrIndex(int documentId, List<String> imagePaths) {
    Future<void>(() async {
      try {
        final buf = StringBuffer();
        final maxPages = imagePaths.length < 5 ? imagePaths.length : 5;
        for (var i = 0; i < maxPages; i++) {
          final path = imagePaths[i];
          if (!File(path).existsSync()) continue;
          final t = await OcrService.instance.extractText(path);
          if (t.isNotEmpty) {
            if (buf.isNotEmpty) buf.writeln();
            buf.write(t);
          }
        }
        final combined = buf.toString().trim();
        if (combined.isNotEmpty) {
          await DatabaseService.instance.updateOcrText(documentId, combined);
        }
      } catch (_) {}
    });
  }

  Future<void> _showPostSaveSuccessSheet(DocumentModel saved) async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final handled = <bool>[false];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(sheetCtx).viewPadding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Iconsax.tick_circle,
                        color: AppColors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Saved successfully',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  saved.name,
                  style: GoogleFonts.nunito(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () {
                    handled[0] = true;
                    Navigator.pop(sheetCtx);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DocumentViewerScreen(document: saved),
                      ),
                    );
                  },
                  icon: const Icon(Iconsax.eye, color: AppColors.navyDark),
                  label: Text(
                    'Open document',
                    style: GoogleFonts.nunito(
                      color: AppColors.navyDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    handled[0] = true;
                    Navigator.pop(sheetCtx);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => AdvancedSharingScreen(
                          filePath: saved.filePath,
                          fileName: saved.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Iconsax.share, color: Colors.white),
                  label: Text(
                    'Share',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    handled[0] = true;
                    Navigator.pop(sheetCtx);
                    nav.pop();
                  },
                  child: Text(
                    'Back to scanner',
                    style: GoogleFonts.nunito(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted && !handled[0]) nav.pop();
    });
  }

  void _openReorderPages() {
    final order = List<String>.from(_pages);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewPadding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Reorder pages',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Long-press handle, then drag',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(
                  height: 360,
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: order.length,
                    onReorder: (oldI, newI) {
                      setSt(() {
                        final item = order.removeAt(oldI);
                        order.insert(newI > oldI ? newI - 1 : newI, item);
                      });
                    },
                    itemBuilder: (_, i) {
                      return ListTile(
                        key: ValueKey(order[i]),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(order[i]),
                            width: 44,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          'Page ${i + 1}',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.drag_handle_rounded),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _pages = List.from(order);
                              _originalPages = List.from(order);
                              _currentPage =
                                  _currentPage.clamp(0, _pages.length - 1);
                            });
                            _pageController.jumpToPage(_currentPage);
                          },
                          child: Text(
                            'Apply',
                            style: GoogleFonts.nunito(
                              color: AppColors.navyDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Crop ───────────────────────────────────────────────────────────────────

  /// UCrop on Android often cannot read camera/gallery paths; copy into app temp first.
  Future<String> _prepareSourcePathForCrop(String sourcePath) async {
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw Exception('Image file not found');
    }
    final dir = await getTemporaryDirectory();
    final base = p.basename(sourcePath);
    final safe =
        base.replaceAll(RegExp(r'[^\w.\-]'), '_').replaceAll(RegExp(r'_+'), '_');
    final dest = File(
      p.join(dir.path, 'crop_in_${DateTime.now().millisecondsSinceEpoch}_$safe'),
    );
    await src.copy(dest.path);
    return dest.path;
  }

  Future<void> _cropCurrentPage() async {
    if (!mounted) return;
    final pageIndex = _currentPage;

    setState(() => _isProcessing = true);
    ScaffoldMessenger.of(context).clearSnackBars();

    String? tempCropSource;
    CroppedFile? cropped;
    try {
      tempCropSource = await _prepareSourcePathForCrop(_pages[pageIndex]);
      cropped = await ImageCropper().cropImage(
        sourcePath: tempCropSource,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: const Color(0xFF0F1A2E),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.gold,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
            hideBottomControls: false,
            dimmedLayerColor: Colors.black54,
            showCropGrid: true,
            statusBarColor: Colors.black,
            backgroundColor: Colors.black,
          ),
          IOSUiSettings(
            title: 'Crop',
            minimumAspectRatio: 0.0,
            resetAspectRatioEnabled: true,
            aspectRatioLockEnabled: false,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
        ],
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
      );
    } on PlatformException catch (e) {
      debugPrint('Cropper PlatformException: $e');
      if (mounted) _showError('Crop failed (${e.code}). Please try again.');
      return;
    } catch (e) {
      debugPrint('Cropper error: $e');
      if (mounted) _showError('Crop error. Please try again.');
      return;
    } finally {
      if (tempCropSource != null) {
        try {
          final f = File(tempCropSource);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      if (mounted) setState(() => _isProcessing = false);
    }

    if (cropped == null || !mounted) return;

    final croppedFile = File(cropped.path);
    if (!croppedFile.existsSync()) {
      if (mounted) _showError('Cropped file not found. Try again.');
      return;
    }

    FileImage(File(_pages[pageIndex])).evict();
    setState(() {
      _pages[pageIndex] = cropped!.path;
      _originalPages[pageIndex] = cropped.path;
    });
  }

  // ── Advanced Filters (opens AdvancedFiltersScreen) ─────────────────────────

  Future<void> _openFilters() async {
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedFiltersScreen(
          imagePath: _originalPages[_currentPage],
        ),
      ),
    );
    if (result != null && mounted) {
      FileImage(File(_pages[_currentPage])).evict();
      setState(() => _pages[_currentPage] = result);
    }
  }

  // ── Document quick modes (CamScanner-style) ────────────────────────────────

  Future<void> _documentMagicColor() async {
    if (widget.scanType != 'document' || _isProcessing) return;
    final i = _currentPage;
    setState(() => _isProcessing = true);
    try {
      final out = await ImageEnhancementService.instance
          .magicColorDocument(_pages[i]);
      if (!mounted) return;
      FileImage(File(_pages[i])).evict();
      setState(() {
        _pages[i] = out;
        _originalPages[i] = out;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Magic color applied to page ${i + 1}',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _documentBlackAndWhite() async {
    if (widget.scanType != 'document' || _isProcessing) return;
    final i = _currentPage;
    setState(() => _isProcessing = true);
    try {
      final out = await ImageEnhancementService.instance
          .documentBlackAndWhite(_pages[i]);
      if (!mounted) return;
      FileImage(File(_pages[i])).evict();
      setState(() {
        _pages[i] = out;
        _originalPages[i] = out;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'B&W scan applied to page ${i + 1}',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Rotate ─────────────────────────────────────────────────────────────────

  Future<void> _rotateImage(int degrees) async {
    if (!mounted) return;
    final pageIndex = _currentPage;
    setState(() => _isProcessing = true);
    try {
      final rotatedPath =
          await ImageEnhancementService.instance.rotate(_pages[pageIndex], degrees);
      if (mounted) {
        FileImage(File(_pages[pageIndex])).evict();
        setState(() {
          _pages[pageIndex] = rotatedPath;
          _originalPages[pageIndex] = rotatedPath;
        });
      }
    } catch (e) {
      if (mounted) _showError('Rotate error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRotateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetTile(Icons.rotate_right_rounded, 'Clockwise 90°',
              () { Navigator.pop(context); _rotateImage(90); }),
          _sheetTile(Icons.rotate_left_rounded, 'Counter-clockwise 90°',
              () { Navigator.pop(context); _rotateImage(-90); }),
          _sheetTile(Icons.flip_rounded, 'Flip 180°',
              () { Navigator.pop(context); _rotateImage(180); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Page management ────────────────────────────────────────────────────────

  void _deletePage(int index) {
    HapticFeedback.mediumImpact();
    if (_pages.length == 1) { Navigator.pop(context); return; }
    setState(() {
      _pages.removeAt(index);
      _originalPages.removeAt(index);
      if (_currentPage >= _pages.length) _currentPage = _pages.length - 1;
    });
    _pageController.jumpToPage(_currentPage);
  }

  void _duplicatePage(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _pages.insert(index + 1, _pages[index]);
      _originalPages.insert(index + 1, _originalPages[index]);
    });
  }

  void _movePage(int from, int to) {
    setState(() {
      final page = _pages.removeAt(from);
      final orig = _originalPages.removeAt(from);
      _pages.insert(to, page);
      _originalPages.insert(to, orig);
      _currentPage = to;
    });
    _pageController.jumpToPage(to);
  }

  void _showPageOptions(int pageIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetTile(Icons.delete_rounded, 'Delete Page',
              () { Navigator.pop(context); _deletePage(pageIndex); },
              color: Colors.redAccent),
          _sheetTile(Icons.content_copy_rounded, 'Duplicate Page',
              () { Navigator.pop(context); _duplicatePage(pageIndex); }),
          if (pageIndex > 0)
            _sheetTile(Icons.arrow_upward_rounded, 'Move Up',
                () { Navigator.pop(context); _movePage(pageIndex, pageIndex - 1); }),
          if (pageIndex < _pages.length - 1)
            _sheetTile(Icons.arrow_downward_rounded, 'Move Down',
                () { Navigator.pop(context); _movePage(pageIndex, pageIndex + 1); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Timestamp ──────────────────────────────────────────────────────────────

  Future<void> _addTimestamp() async {
    if (!mounted) return;
    final pageIndex = _currentPage;
    setState(() => _isProcessing = true);
    try {
      final path = await ImageEnhancementService.instance.addTimestamp(
        _pages[pageIndex], format: 'dd/MM/yyyy HH:mm:ss',
      );
      if (mounted) {
        FileImage(File(_pages[pageIndex])).evict();
        setState(() {
          _pages[pageIndex] = path;
          _originalPages[pageIndex] = path;
        });
        _showSuccess('Timestamp added!');
      }
    } catch (e) {
      if (mounted) _showError('Timestamp error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Erase: manual region or OCR auto-detect ────────────────────────────────

  void _showEraseOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Remove content',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Choose how to erase — draw a box, or let the app find text.',
              style: GoogleFonts.nunito(
                color: Colors.white54,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          _sheetTile(
            Icons.crop_free_rounded,
            'Select area',
            () {
              Navigator.pop(sheetContext);
              _openManualErase();
            },
          ),
          _sheetTile(
            Icons.auto_fix_high_rounded,
            'Auto-detect text',
            () {
              Navigator.pop(sheetContext);
              _autoEraseDetectedText();
            },
            color: AppColors.gold,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _openManualErase() async {
    if (!mounted) return;
    final newPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualEraseScreen(imagePath: _pages[_currentPage]),
      ),
    );
    if (newPath != null && mounted) {
      FileImage(File(_pages[_currentPage])).evict();
      setState(() {
        _pages[_currentPage] = newPath;
        _originalPages[_currentPage] = newPath;
      });
      _showSuccess('Selected area removed!');
    }
  }

  Future<void> _autoEraseDetectedText() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final result =
          await SmartEraseService.instance.smartErase(_pages[_currentPage]);
      if (!mounted) return;
      if (!result.applied) {
        _showError(
          'No safe text regions found. Try better lighting or use Select area.',
        );
        return;
      }
      FileImage(File(_pages[_currentPage])).evict();
      setState(() {
        _pages[_currentPage] = result.imagePath;
        _originalPages[_currentPage] = result.imagePath;
      });
      _showSuccess('Text regions removed!');
    } catch (e) {
      if (mounted) _showError('Auto erase error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Extract / Signature ────────────────────────────────────────────────────

  void _extractText() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TextExtractionScreen(imagePath: _pages[_currentPage]),
    ),
  );

  void _addSignature() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SignaturePadScreen(
        imagePath: _pages[_currentPage],
        onSignatureAdded: (signedPath) {
          if (mounted) {
            FileImage(File(_pages[_currentPage])).evict();
            setState(() => _pages[_currentPage] = signedPath);
          }
        },
      ),
    ),
  );

  Future<void> _openAnnotate() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnotationScreen(imagePath: _pages[_currentPage]),
      ),
    );
    if (path != null && mounted) {
      FileImage(File(_pages[_currentPage])).evict();
      setState(() {
        _pages[_currentPage] = path;
        _originalPages[_currentPage] = path;
      });
    }
  }

  Future<void> _addWatermarkText() async {
    final config = await showWatermarkComposerSheet(
      context,
      imagePath: _pages[_currentPage],
      initialText: 'CONFIDENTIAL',
    );
    if (config == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final out = await WatermarkService.instance.addTextWatermark(
        _pages[_currentPage],
        text: config.text,
        red: config.r,
        green: config.g,
        blue: config.b,
        opacity: config.a,
      );
      if (mounted) {
        FileImage(File(_pages[_currentPage])).evict();
        setState(() {
          _pages[_currentPage] = out;
          _originalPages[_currentPage] = out;
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveDocument(String saveType, {bool compressedPdf = false}) async {
    if (_isSaving || !mounted) return;

    final docName = _nameController.text.trim().isEmpty
        ? 'Scan_${DateTime.now().millisecondsSinceEpoch}'
        : _nameController.text.trim();

    if (mounted) setState(() => _isSaving = true);

    try {
      List<String> pagesToSave = _pages;
      if (_showTimestampOption) {
        pagesToSave = [];
        for (final page in _pages) {
          pagesToSave.add(await ImageEnhancementService.instance.addTimestamp(
            page, format: 'dd/MM/yyyy HH:mm:ss',
          ));
        }
      }

      String filePath;
      String fileType;
      if (saveType == 'pdf') {
        filePath = compressedPdf
            ? await PdfService.instance
                .createCompressedPdfFromImages(pagesToSave, docName)
            : await PdfService.instance.createPdfFromImages(pagesToSave, docName);
        fileType = 'pdf';
      } else {
        filePath = pagesToSave[0];
        fileType = 'jpg';
      }

      final thumbPath = await PdfService.instance.generateThumbnail(pagesToSave[0]);
      final fileSizeMB = await PdfService.instance.getFileSizeMB(filePath);

      final doc = DocumentModel(
        name: docName,
        filePath: filePath,
        fileType: fileType,
        scanType: widget.scanType,
        pageCount: pagesToSave.length,
        fileSizeMB: fileSizeMB,
        createdAt: DateTime.now(),
        thumbnailPath: thumbPath,
        tags: List<String>.from(_saveDraftTags),
      );

      final id = await DatabaseService.instance.insertDocument(doc);
      await AppLocalStorage.setString('lastSavedDocName', docName);
      final saved = doc.copyWith(id: id);
      _scheduleOcrIndex(id, pagesToSave);
      if (mounted) {
        await _showPostSaveSuccessSheet(saved);
      }
    } catch (e) {
      if (mounted) _showError('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveOptions() {
    _saveDraftTags.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 20, 24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Document Name',
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Enter document name',
                  hintStyle: GoogleFonts.nunito(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (_pages.length > 1) ...[
                const SizedBox(height: 10),
                Text(
                  '${_pages.length} pages → one PDF bundles every page (recommended for school & work).',
                  style: GoogleFonts.nunito(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Tags (optional)',
                style: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in [
                    'Work',
                    'Personal',
                    'Receipt',
                    'School',
                    'Medical',
                    'Tax',
                  ])
                    FilterChip(
                      label: Text(
                        t,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      selected: _saveDraftTags.contains(t),
                      onSelected: (sel) {
                        setSheetState(() {
                          if (sel) {
                            if (!_saveDraftTags.contains(t)) {
                              _saveDraftTags.add(t);
                            }
                          } else {
                            _saveDraftTags.remove(t);
                          }
                        });
                      },
                      selectedColor: AppColors.gold.withValues(alpha: 0.35),
                      checkmarkColor: AppColors.navyDark,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  final val = !_showTimestampOption;
                  setSheetState(() => _showTimestampOption = val);
                  if (mounted) setState(() => _showTimestampOption = val);
                },
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _showTimestampOption ? AppColors.gold : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _showTimestampOption ? AppColors.gold : Colors.white30,
                        ),
                      ),
                      child: _showTimestampOption
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text('Add timestamp to all pages',
                        style: GoogleFonts.nunito(
                          color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Save document',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pages.length > 1
                    ? '${_pages.length} pages — one PDF file keeps every page together.'
                    : 'Save as a PDF file, or as a single image (JPG).',
                style: GoogleFonts.nunito(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              // Primary: PDF (prominent action)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _saveDocument('pdf');
                  },
                  icon: const Icon(Iconsax.document_text, color: Colors.white, size: 22),
                  label: Text(
                    _pages.length > 1
                        ? 'Save as PDF (all pages)'
                        : 'Save as PDF',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _saveDocument('jpg');
                  },
                  icon: const Icon(Iconsax.image, color: Color(0xFF64B5F6), size: 20),
                  label: Text(
                    _pages.length > 1
                        ? 'Save as image (first page only)'
                        : 'Save as image (JPG)',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _saveDocument('pdf', compressedPdf: true);
                  },
                  icon: const Icon(Iconsax.document_cloud, color: AppColors.gold, size: 20),
                  label: Text(
                    'Compressed PDF (smaller file)',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _sheetHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Center(child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
    )),
  );

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white70}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: GoogleFonts.nunito(
        color: color == Colors.white70 ? Colors.white : color,
        fontWeight: FontWeight.w600,
      )),
      onTap: onTap,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.92),
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
        leadingWidth: 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.95)),
                onPressed: () => Navigator.pop(context, List<String>.from(_pages)),
              ),
              GestureDetector(
                onTap: () async {
                  // Go back to camera to add more pages
                  Navigator.pop(context, List<String>.from(_pages));
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(Icons.add_rounded, color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          'Adjust',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          if (_pages.length > 1 && !_isSaving && !_isProcessing)
            TextButton.icon(
              onPressed: _enhanceAllPages,
              icon: Icon(Iconsax.magic_star,
                  color: AppColors.gold.withValues(alpha: 0.95), size: 18),
              label: Text(
                'Fix all',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 6, bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showSaveOptions,
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE082), AppColors.gold],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.42),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      child: Text(
                        'Save',
                        style: GoogleFonts.nunito(
                          color: AppColors.navyDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Image preview ──
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(child: _FilteredImage(path: _pages[i])),
                  ),
                ),

                // Bottom vignette — blends preview into tool dock (pro scanner look).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 96,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Processing overlay
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: AppColors.gold),
                          const SizedBox(height: 14),
                          Text('Processing…',
                              style: GoogleFonts.nunito(
                                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                // Page counter
                if (_pages.length > 1)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              '${_currentPage + 1} / ${_pages.length}',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Edit tools (premium dock) ──
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.editorBarTop,
                  AppColors.editorBarBottom,
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _editTool(Iconsax.crop,        'Crop',      _cropCurrentPage),
                  _editTool(Iconsax.rotate_left, 'Rotate',    _showRotateOptions),
                  // ← Filters button: opens AdvancedFiltersScreen
                  _editTool(Iconsax.filter,      'Filters',   _openFilters,
                      color: AppColors.gold),
                  if (widget.scanType == 'document') ...[
                    _editTool(
                      Iconsax.magic_star,
                      'Magic',
                      _documentMagicColor,
                      color: const Color(0xFF22C55E),
                    ),
                    _editTool(
                      Iconsax.document_text,
                      'B & W',
                      _documentBlackAndWhite,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                  _editTool(Iconsax.clock,       'Timestamp', _addTimestamp),
                  _editTool(Iconsax.text,        'Extract',   _extractText),
                  _editTool(Iconsax.eraser,      'Erase',     _showEraseOptions),
                  _editTool(Iconsax.pen_add,     'Sign',      _addSignature),
                  _editTool(Iconsax.note_text,   'Annotate',  _openAnnotate,
                      color: AppColors.orange),
                  _editTool(Iconsax.shield_tick, 'Watermark', _addWatermarkText,
                      color: AppColors.blue),
                  if (_pages.length > 1)
                    _editTool(Iconsax.sort, 'Reorder', _openReorderPages,
                        color: AppColors.green),
                  _editTool(Iconsax.trash,       'Delete',
                      () => _deletePage(_currentPage),
                      color: Colors.redAccent),
                ],
              ),
            ),
          ),

          // ── Thumbnail strip ──
          if (_pages.length > 1)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.editorBarBottom,
                    Color(0xFF080808),
                  ],
                ),
              ),
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final isSelected = _currentPage == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentPage = i);
                      _pageController.animateToPage(i,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic);
                    },
                    onLongPress: () => _showPageOptions(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 64,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.14),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _FilteredImage(path: _pages[i], fit: BoxFit.cover),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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

  Widget _editTool(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white}) {
    final accent = color == Colors.white ? Colors.white : color;
    final labelColor =
        color == Colors.white ? Colors.white.withValues(alpha: 0.62) : accent;
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Opacity(
        opacity: _isProcessing ? 0.45 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.editorIconBg,
                  border: Border.all(
                    color: color == Colors.white
                        ? AppColors.editorIconBorder
                        : accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 68,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    color: labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cached image widget ────────────────────────────────────────────────────────

class _FilteredImage extends StatefulWidget {
  final String path;
  final BoxFit fit;
  const _FilteredImage({required this.path, this.fit = BoxFit.contain});

  @override
  State<_FilteredImage> createState() => _FilteredImageState();
}

class _FilteredImageState extends State<_FilteredImage> {
  late FileImage _fileImage;

  @override
  void initState() {
    super.initState();
    _fileImage = FileImage(File(widget.path));
  }

  @override
  void didUpdateWidget(_FilteredImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      FileImage(File(old.path)).evict();
      _fileImage = FileImage(File(widget.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _fileImage,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64),
      ),
    );
  }
}