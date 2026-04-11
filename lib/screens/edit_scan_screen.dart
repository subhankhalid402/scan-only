import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/image_enhancement_service.dart';
import 'text_extraction_screen.dart';
import 'manual_erase_screen.dart';
import '../services/smart_erase_service.dart';
import 'signature_pad_screen.dart';
import 'advanced_filters_screen.dart'; // ← import

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

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.imagePaths);
    _originalPages = List.from(widget.imagePaths);
    _pageController = PageController();
    final now = DateTime.now();
    _nameController = TextEditingController(
      text: 'Scan_${now.day}-${now.month}-${now.year}',
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
              'Choose how to erase — like CamScanner: draw a box, or let the app find text.',
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

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveDocument(String saveType) async {
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
        filePath = await PdfService.instance.createPdfFromImages(pagesToSave, docName);
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
      );

      await DatabaseService.instance.insertDocument(doc);
      if (mounted) {
        _showSuccess('Saved as ${fileType.toUpperCase()}!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveOptions() {
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
              Text('Save as',
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _saveBtn(label: 'PDF', icon: Iconsax.document,
                      color: const Color(0xFFE53935),
                      onTap: () { Navigator.pop(sheetContext); _saveDocument('pdf'); })),
                  const SizedBox(width: 12),
                  Expanded(child: _saveBtn(label: 'Image', icon: Iconsax.image,
                      color: const Color(0xFF1E88E5),
                      onTap: () { Navigator.pop(sheetContext); _saveDocument('jpg'); })),
                ],
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

  Widget _saveBtn({required String label, required IconData icon,
      required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15,
            )),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Scan',
            style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _showSaveOptions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Save',
                      style: GoogleFonts.nunito(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      )),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
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
                    top: 12, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('${_currentPage + 1} / ${_pages.length}',
                            style: GoogleFonts.nunito(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Edit tools ──
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _editTool(Iconsax.crop,        'Crop',      _cropCurrentPage),
                  _editTool(Iconsax.rotate_left, 'Rotate',    _showRotateOptions),
                  // ← Filters button: opens AdvancedFiltersScreen
                  _editTool(Iconsax.filter,      'Filters',   _openFilters,
                      color: AppColors.gold),
                  _editTool(Iconsax.clock,       'Timestamp', _addTimestamp),
                  _editTool(Iconsax.text,        'Extract',   _extractText),
                  _editTool(Iconsax.eraser,      'Erase',     _showEraseOptions),
                  _editTool(Iconsax.pen_add,     'Sign',      _addSignature),
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
              color: const Color(0xFF111111),
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final isSelected = _currentPage == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentPage = i);
                      _pageController.animateToPage(i,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut);
                    },
                    onLongPress: () => _showPageOptions(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 68,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppColors.gold : Colors.white24,
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6.5),
                            child: _FilteredImage(path: _pages[i], fit: BoxFit.cover),
                          ),
                          Positioned(
                            bottom: 3, right: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text('${i + 1}',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
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
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Opacity(
        opacity: _isProcessing ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.nunito(
                    color: color == Colors.white ? Colors.white70 : color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
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