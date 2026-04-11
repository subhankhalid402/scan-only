import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import 'edit_scan_screen.dart';

// ── Scan mode model ──────────────────────────────────────────────────────────

class _ScanMode {
  final String id;
  final IconData icon;
  final String label;
  final Color color;

  const _ScanMode({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
  });
}

const List<_ScanMode> _kScanModes = [
  _ScanMode(id: 'document',   icon: Iconsax.document_text, label: 'Document',   color: Color(0xFFD4A017)),
  _ScanMode(id: 'id_card',    icon: Iconsax.card,          label: 'ID Card',    color: Color(0xFF3B82F6)),
  _ScanMode(id: 'receipt',    icon: Iconsax.receipt,       label: 'Receipt',    color: Color(0xFF22C55E)),
  _ScanMode(id: 'qr',         icon: Iconsax.scan_barcode,  label: 'QR Code',    color: Color(0xFF6366F1)),
  _ScanMode(id: 'book',       icon: Iconsax.book,          label: 'Book',       color: Color(0xFFF97316)),
  _ScanMode(id: 'photo',      icon: Iconsax.camera,        label: 'Photo',      color: Color(0xFFA855F7)),
  _ScanMode(id: 'gallery',    icon: Iconsax.gallery,       label: 'Gallery',    color: Color(0xFFEF4444)),
  _ScanMode(id: 'whiteboard', icon: Iconsax.text_block,    label: 'Whiteboard', color: Color(0xFF06B6D4)),
  _ScanMode(id: 'table',      icon: Iconsax.element_3,     label: 'Table',      color: Color(0xFF84CC16)),
  _ScanMode(id: 'passport',   icon: Iconsax.personalcard,  label: 'Passport',   color: Color(0xFFF43F5E)),
];

// ── Frame type enum ──────────────────────────────────────────────────────────

enum _FrameType { document, card, qr }

_FrameType _frameTypeFor(String modeId) {
  if (modeId == 'qr') return _FrameType.qr;
  if (modeId == 'id_card' || modeId == 'passport') return _FrameType.card;
  return _FrameType.document;
}

// ────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  final String scanType;
  const ScanScreen({super.key, required this.scanType});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  int _currentCameraIndex = 0;

  // Pages
  final List<String> _capturedPages = [];

  // Mode
  late String _selectedMode;

  // Scan-line animation
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  // Mode scroll
  final ScrollController _modeScrollController = ScrollController();

  // Thumbnail scroll
  final ScrollController _thumbScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.scanType;

    // Scan-line animation
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scanLineAnim = CurvedAnimation(
      parent: _scanLineCtrl,
      curve: Curves.easeInOut,
    );

    _initCamera();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  // ── Camera ─────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showPermissionDialog();
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _setupCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Camera setup error: $e');
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedPages.add(image.path);
        _isCapturing = false;
      });
      // Auto-scroll thumbnail strip to end
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_thumbScrollController.hasClients) {
          _thumbScrollController.animateTo(
            _thumbScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Page ${_capturedPages.length} captured!',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _capturedPages.addAll(images.map((img) => img.path));
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isFlashOn = !_isFlashOn);
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.lightImpact();
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    setState(() => _isCameraReady = false);
    await _setupCamera(_cameras[_currentCameraIndex]);
  }

  void _proceedToEdit() {
    if (_capturedPages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditScanScreen(
          imagePaths: _capturedPages,
          scanType: _selectedMode,
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Camera Permission',
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Camera access is needed to scan documents.',
          style: GoogleFonts.nunito(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.nunito(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.nunito(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode scroll ────────────────────────────────────────────────────────────

  void _scrollToSelected() {
    final index = _kScanModes.indexWhere((m) => m.id == _selectedMode);
    if (index < 0 || !_modeScrollController.hasClients) return;
    const chipWidth = 90.0;
    final offset = (index * chipWidth) - (chipWidth / 2);
    _modeScrollController.animateTo(
      offset.clamp(0.0, _modeScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _selectMode(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMode = id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineCtrl.dispose();
    _modeScrollController.dispose();
    _thumbScrollController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera preview
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),

          // 2. Scan frame + scan-line
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, __) => CustomPaint(
                painter: _ScanFramePainter(
                  frameType: _frameTypeFor(_selectedMode),
                  frameColor: _kScanModes
                      .firstWhere(
                        (m) => m.id == _selectedMode,
                        orElse: () => _kScanModes.first,
                      )
                      .color,
                  scanLineProgress: _scanLineAnim.value,
                ),
              ),
            ),
          ),

          // 3. Top bar
          _buildTopBar(),

          // 4. Pages badge
          if (_capturedPages.isNotEmpty) _buildPagesBadge(),

          // 5. Bottom panel
          _buildBottomPanel(),
        ],
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 8,
          16,
          14,
        ),
        child: Row(
          children: [
            _iconBtn(
              Icons.arrow_back_ios_new_rounded,
              () => Navigator.pop(context),
            ),
            const Spacer(),
            Text(
              _scanTypeLabel(),
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            _iconBtn(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              _toggleFlash,
              color: _isFlashOn ? AppColors.gold : Colors.white,
              bgColor: _isFlashOn
                  ? AppColors.gold.withOpacity(0.2)
                  : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  // ── Pages Badge ────────────────────────────────────────────────────────────

  Widget _buildPagesBadge() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 68,
      right: 16,
      child: GestureDetector(
        onTap: _proceedToEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '${_capturedPages.length} page${_capturedPages.length > 1 ? 's' : ''} →',
            style: GoogleFonts.nunito(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.70),
              Colors.black.withOpacity(0.97),
            ],
            stops: const [0, 0.28, 1],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),

              // Thumbnail strip (visible only when pages > 0)
              if (_capturedPages.isNotEmpty) _buildThumbnailStrip(),

              const SizedBox(height: 4),

              // Mode selector
              _buildModeSelector(),

              const SizedBox(height: 20),

              // Shutter row
              _buildShutterRow(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Thumbnail Strip ────────────────────────────────────────────────────────

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        controller: _thumbScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _capturedPages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: _proceedToEdit,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.5,
                ),
                image: DecorationImage(
                  image: FileImage(File(_capturedPages[i])),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  // Page number badge
                  Positioned(
                    bottom: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
    );
  }

  // ── Mode Selector ──────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        controller: _modeScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kScanModes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final mode = _kScanModes[i];
          final isSelected = _selectedMode == mode.id;

          return GestureDetector(
            onTap: () => _selectMode(mode.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? mode.color.withOpacity(0.18)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? mode.color : Colors.white24,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mode.icon,
                    color: isSelected ? mode.color : Colors.white60,
                    size: 22,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    mode.label,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? mode.color : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Shutter Row ────────────────────────────────────────────────────────────

  Widget _buildShutterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery picker
          GestureDetector(
            onTap: _pickFromGallery,
            child: _sideBtn(const Icon(Iconsax.gallery, color: Colors.white, size: 26)),
          ),

          // Shutter
          GestureDetector(
            onTap: _captureImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: _isCapturing ? 74 : 80,
              height: _isCapturing ? 74 : 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? Colors.white60 : Colors.white,
                  ),
                  child: _isCapturing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.black45,
                            strokeWidth: 2.5,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Flip camera
          GestureDetector(
            onTap: _flipCamera,
            child: _sideBtn(const Icon(Icons.flip_camera_ios_rounded,
                color: Colors.white, size: 26)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sideBtn(Widget child) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      child: child,
    );
  }

  String _scanTypeLabel() {
    return _kScanModes
        .firstWhere(
          (m) => m.id == _selectedMode,
          orElse: () => const _ScanMode(
            id: 'document',
            icon: Iconsax.document_text,
            label: 'Scan',
            color: Colors.white,
          ),
        )
        .label;
  }

  Widget _iconBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white,
    Color bgColor = Colors.black45,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── Scan Frame Painter ────────────────────────────────────────────────────────

class _ScanFramePainter extends CustomPainter {
  final _FrameType frameType;
  final Color frameColor;
  final double scanLineProgress; // 0.0 → 1.0

  const _ScanFramePainter({
    required this.frameType,
    required this.frameColor,
    required this.scanLineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Frame rect ──
    double left, top, right, bottom;

    switch (frameType) {
      case _FrameType.qr:
        final side = size.width * 0.65;
        left = (size.width - side) / 2;
        right = left + side;
        top = size.height * 0.22;
        bottom = top + side;
        break;
      case _FrameType.card:
        final w = size.width * 0.84;
        final h = w * 0.63;
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.28;
        bottom = top + h;
        break;
      case _FrameType.document:
        final margin = size.width * 0.08;
        left = margin;
        right = size.width - margin;
        top = size.height * 0.17;
        bottom = size.height * 0.68;
        break;
    }

    // ── Dim overlay ──
    final dimPaint = Paint()
      ..color = Colors.black.withOpacity(0.48)
      ..style = PaintingStyle.fill;

    final framePath = Path()
      ..addRect(Rect.fromLTRB(left, top, right, bottom));
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final dimPath = Path.combine(PathOperation.difference, fullPath, framePath);
    canvas.drawPath(dimPath, dimPaint);

    // ── Corner brackets ──
    final bracketPaint = Paint()
      ..color = frameColor
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLen = frameType == _FrameType.qr ? 22.0 : 30.0;

    void drawCorner(Offset a, Offset corner, Offset b) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(b.dx, b.dy);
      canvas.drawPath(path, bracketPaint);
    }

    // Top-left
    drawCorner(
      Offset(left, top + cornerLen),
      Offset(left, top),
      Offset(left + cornerLen, top),
    );
    // Top-right
    drawCorner(
      Offset(right - cornerLen, top),
      Offset(right, top),
      Offset(right, top + cornerLen),
    );
    // Bottom-left
    drawCorner(
      Offset(left, bottom - cornerLen),
      Offset(left, bottom),
      Offset(left + cornerLen, bottom),
    );
    // Bottom-right
    drawCorner(
      Offset(right - cornerLen, bottom),
      Offset(right, bottom),
      Offset(right, bottom - cornerLen),
    );

    // ── Animated scan line ──
    final scanY = top + (bottom - top) * scanLineProgress;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          frameColor.withOpacity(0.6),
          frameColor.withOpacity(0.9),
          frameColor.withOpacity(0.6),
          Colors.transparent,
        ],
        stops: const [0, 0.2, 0.5, 0.8, 1],
      ).createShader(Rect.fromLTRB(left, scanY - 1, right, scanY + 1))
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(left + 4, scanY), Offset(right - 4, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) =>
      old.frameType != frameType ||
      old.frameColor != frameColor ||
      old.scanLineProgress != scanLineProgress;
}