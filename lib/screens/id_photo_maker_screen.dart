import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../services/image_enhancement_service.dart';
import '../services/pdf_service.dart';

class IdPhotoMakerScreen extends StatefulWidget {
  const IdPhotoMakerScreen({super.key});

  @override
  State<IdPhotoMakerScreen> createState() => _IdPhotoMakerScreenState();
}

class _IdPhotoMakerScreenState extends State<IdPhotoMakerScreen> {
  String? _imagePath;
  String _selectedSize = '4x6';
  String _selectedBackground = 'white';
  bool _isProcessing = false;
  String? _generatedPath;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _photoSizes = [
    {'id': '2x2', 'label': '2x2 inch', 'width': 2.0, 'height': 2.0},
    {'id': '1x1', 'label': '1x1 inch', 'width': 1.0, 'height': 1.0},
    {'id': '4x6', 'label': '4x6 inch', 'width': 4.0, 'height': 6.0},
    {'id': 'passport', 'label': 'Passport', 'width': 1.5, 'height': 2.0},
    {'id': 'visa', 'label': 'Visa', 'width': 2.0, 'height': 2.0},
  ];

  final List<Map<String, dynamic>> _backgrounds = [
    {'id': 'white', 'label': 'White', 'color': Colors.white},
    {'id': 'blue', 'label': 'Blue', 'color': Color(0xFF1e3a5f)},
    {'id': 'red', 'label': 'Red', 'color': Color(0xFFc41e3a)},
    {'id': 'gray', 'label': 'Gray', 'color': Color(0xFF808080)},
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
        _generatedPath = null;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
        _generatedPath = null;
      });
    }
  }

  Future<void> _generateIdPhoto() async {
    if (_imagePath == null) {
      _showError('Please select or capture a photo first');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Get selected size
      final sizeData = _photoSizes.firstWhere((s) => s['id'] == _selectedSize);
      final width = sizeData['width'] as double;
      final height = sizeData['height'] as double;

      // Get background color
      final bgData =
          _backgrounds.firstWhere((b) => b['id'] == _selectedBackground);
      final bgColor = bgData['color'] as Color;

      // Process image
      final processedPath =
          await ImageEnhancementService.instance.autoEnhance(_imagePath!);
      final out = await _composeIdPhoto(
        processedPath: processedPath,
        widthInch: width,
        heightInch: height,
        bgColor: bgColor,
      );
      if (mounted) {
        setState(() => _generatedPath = out);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID Photo generated: ${sizeData['label']}'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Error generating photo: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  Future<void> _saveGeneratedToApp() async {
    final path = _generatedPath;
    if (path == null || !File(path).existsSync()) {
      _showError('Please generate ID photo first');
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final size = await PdfService.instance.getFileSizeMB(path);
      final thumb = await PdfService.instance.generateThumbnail(path);
      final sizeLabel = _photoSizes
          .firstWhere((e) => e['id'] == _selectedSize)['label']
          .toString();
      final bgLabel = _backgrounds
          .firstWhere((e) => e['id'] == _selectedBackground)['label']
          .toString();
      final doc = DocumentModel(
        name: 'ID_Photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        filePath: path,
        fileType: 'jpg',
        scanType: 'id_maker',
        pageCount: 1,
        fileSizeMB: size,
        createdAt: DateTime.now(),
        thumbnailPath: thumb,
        tags: ['ID Maker', sizeLabel, 'BG:$bgLabel'],
      );
      await DatabaseService.instance.insertDocument(doc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved in app library'),
          backgroundColor: AppColors.green,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String> _composeIdPhoto({
    required String processedPath,
    required double widthInch,
    required double heightInch,
    required Color bgColor,
  }) async {
    final source = img.decodeImage(await File(processedPath).readAsBytes());
    if (source == null) return processedPath;
    const dpi = 300;
    final outW = (widthInch * dpi).round();
    final outH = (heightInch * dpi).round();

    final argb = bgColor.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;

    final canvas = img.Image(width: outW, height: outH);
    img.fill(canvas, color: img.ColorRgb8(r, g, b));

    final portraitW = (outW * 0.72).round();
    final resized = img.copyResize(source, width: portraitW);
    final x = ((outW - resized.width) / 2).round();
    final y = ((outH - resized.height) / 2).round().clamp(0, outH - 1);
    img.compositeImage(canvas, resized, dstX: x, dstY: y);

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/IDMaker');
    await outDir.create(recursive: true);
    final path = p.join(
      outDir.path,
      'id_maker_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(path).writeAsBytes(img.encodeJpg(canvas, quality: 94));
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text(
          'ID Photo Maker',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Preview
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.navyDark.withValues(alpha: 0.14)),
                ),
                child: _imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_generatedPath ?? _imagePath!),
                          fit: BoxFit.cover,
                          cacheWidth: 1080,
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) {
                              return child;
                            }
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.image, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No photo selected',
                              style: GoogleFonts.nunito(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _capturePhoto,
                      icon: const Icon(Iconsax.camera, color: Colors.white),
                      label: Text(
                        'Capture',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Iconsax.gallery, color: Colors.white),
                      label: Text(
                        'Gallery',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Photo Size Selection
              Text(
                'Photo Size',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _photoSizes.map((size) {
                  final isSelected = _selectedSize == size['id'];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedSize = size['id'];
                      _generatedPath = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.gold : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.gold : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        size['label'],
                        style: GoogleFonts.nunito(
                          color: isSelected ? AppColors.navyDark : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Background Color Selection
              Text(
                'Background Color',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _backgrounds.map((bg) {
                  final isSelected = _selectedBackground == bg['id'];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedBackground = bg['id'];
                      _generatedPath = null;
                    }),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: bg['color'],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.gold
                                  : Colors.grey[300]!,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bg['label'],
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Generate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _generateIdPhoto,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Iconsax.export, color: Colors.white),
                  label: Text(
                    _isProcessing ? 'Generating...' : 'Generate ID Photo',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveGeneratedToApp,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Iconsax.folder_open),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save in App',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
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
