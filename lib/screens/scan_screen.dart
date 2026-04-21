import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document_model.dart';
import '../services/app_local_storage.dart';
import '../services/database_service.dart';
import '../services/image_enhancement_service.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import 'document_scan_editor_screen.dart';
import 'edit_scan_screen.dart';
import 'bank_statement_result_screen.dart';
import 'academic_certificate_result_screen.dart';
import 'book_result_screen.dart';
import 'driving_license_result_screen.dart';
import 'id_card_result_screen.dart';
import 'medical_prescription_result_screen.dart';
import 'passport_result_screen.dart';
import 'photo_enhancement_screen.dart';
import 'receipt_result_screen.dart';
import 'table_result_screen.dart';
import 'vehicle_rc_result_screen.dart';
import 'whiteboard_result_screen.dart';

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

/// Capture modes — order matches typical document-scanner apps (general → forms → media → codes).
const List<_ScanMode> _kScanModes = [
  _ScanMode(
      id: 'document',
      icon: Iconsax.document_text,
      label: 'Document',
      color: AppColors.gold),
  _ScanMode(
      id: 'receipt',
      icon: Iconsax.receipt,
      label: 'Receipt',
      color: AppColors.gold),
  _ScanMode(
      id: 'id_card',
      icon: Iconsax.card,
      label: 'ID card',
      color: AppColors.gold),
  _ScanMode(
      id: 'passport',
      icon: Iconsax.personalcard,
      label: 'Passport',
      color: AppColors.gold),
  _ScanMode(
      id: 'driving_license',
      icon: Iconsax.card_tick_1,
      label: 'License',
      color: AppColors.gold),
  _ScanMode(
      id: 'vehicle_rc',
      icon: Iconsax.car,
      label: 'Vehicle RC',
      color: AppColors.gold),
  _ScanMode(
      id: 'medical_prescription',
      icon: Iconsax.note_text,
      label: 'Prescription',
      color: AppColors.gold),
  _ScanMode(
      id: 'bank_statement',
      icon: Iconsax.bank,
      label: 'Bank stmt',
      color: AppColors.gold),
  _ScanMode(
      id: 'book', icon: Iconsax.book, label: 'Book', color: AppColors.gold),
  _ScanMode(
      id: 'whiteboard',
      icon: Iconsax.text_block,
      label: 'Whiteboard',
      color: AppColors.gold),
  _ScanMode(
      id: 'table',
      icon: Iconsax.element_3,
      label: 'Table',
      color: AppColors.gold),
  _ScanMode(
      id: 'academic_certificate',
      icon: Icons.school_rounded,
      label: 'Certificate',
      color: AppColors.gold),
  _ScanMode(
      id: 'photo', icon: Iconsax.camera, label: 'Photo', color: AppColors.gold),
  _ScanMode(
      id: 'qr',
      icon: Iconsax.scan_barcode,
      label: 'QR & barcode',
      color: AppColors.gold),
];

class _ModeContent {
  final String tip;
  final List<_ImportOption> importOptions;
  final List<_FeatureChip> featureChips;

  const _ModeContent({
    required this.tip,
    required this.importOptions,
    required this.featureChips,
  });
}

class _ImportOption {
  final IconData icon;
  final String label;
  final Color color;
  final String action; // 'gallery' | 'files' | 'camera' | 'cloud'
  const _ImportOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.action,
  });
}

class _FeatureChip {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});
}

/// Capture polish presets (maps to [ImageEnhancementService.polishCaptureForScanMode] filter ids).
class _FilterPreset {
  final String id;
  final String label;
  final IconData icon;
  const _FilterPreset({
    required this.id,
    required this.label,
    required this.icon,
  });
}

const List<_FilterPreset> _kFiltersOffice = [
  _FilterPreset(id: 'auto', label: 'Auto', icon: Iconsax.magicpen),
  _FilterPreset(id: 'enhanced', label: 'Clear', icon: Iconsax.sun_1),
  _FilterPreset(id: 'whitening', label: 'B&W', icon: Iconsax.document_text),
  _FilterPreset(id: 'flatten', label: 'Flat', icon: Iconsax.crop),
  _FilterPreset(id: 'vivid', label: 'Color', icon: Iconsax.colorfilter),
];

const List<_FilterPreset> _kFiltersIdentity = [
  _FilterPreset(id: 'auto', label: 'Auto', icon: Iconsax.magicpen),
  _FilterPreset(id: 'id_clear', label: 'Glare off', icon: Iconsax.sun_1),
  _FilterPreset(id: 'enhanced', label: 'Sharp', icon: Iconsax.star_1),
  _FilterPreset(id: 'whitening', label: 'B&W', icon: Iconsax.document_text),
];

const List<_FilterPreset> _kFiltersReceipt = [
  _FilterPreset(id: 'auto', label: 'Auto', icon: Iconsax.magicpen),
  _FilterPreset(id: 'enhanced', label: 'Contrast', icon: Iconsax.sun_1),
  _FilterPreset(id: 'whitening', label: 'B&W', icon: Iconsax.document_text),
  _FilterPreset(id: 'flatten', label: 'Flat', icon: Iconsax.crop),
];

const List<_FilterPreset> _kFiltersBoard = [
  _FilterPreset(id: 'auto', label: 'Auto', icon: Iconsax.magicpen),
  _FilterPreset(id: 'flatten', label: 'Board', icon: Iconsax.crop),
  _FilterPreset(id: 'enhanced', label: 'Text', icon: Iconsax.text),
  _FilterPreset(id: 'vivid', label: 'Color', icon: Iconsax.colorfilter),
];

List<_FilterPreset> _filterPresetsResolved(String modeId) {
  if (modeId == 'qr' || modeId == 'photo') return const [];
  const identity = {'id_card', 'passport', 'driving_license'};
  const receiptish = {'receipt'};
  const boardish = {'whiteboard', 'table', 'book'};
  if (identity.contains(modeId)) return _kFiltersIdentity;
  if (receiptish.contains(modeId)) return _kFiltersReceipt;
  if (boardish.contains(modeId)) return _kFiltersBoard;
  return _kFiltersOffice;
}

const Map<String, _ModeContent> _kModeContent = {
  'document': _ModeContent(
    tip: 'Place document on flat surface for best results',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.scissor, label: 'Auto-crop'),
      _FeatureChip(icon: Iconsax.sun_1, label: 'Shadow remove'),
      _FeatureChip(icon: Iconsax.document_text, label: 'Flatten page'),
      _FeatureChip(icon: Iconsax.text, label: 'OCR text'),
      _FeatureChip(icon: Iconsax.magicpen, label: 'Enhance text'),
      _FeatureChip(icon: Iconsax.crop, label: 'Perspective fix'),
      _FeatureChip(icon: Iconsax.document, label: 'CSV export'),
      _FeatureChip(icon: Iconsax.arrange_square, label: 'Reorder pages'),
    ],
  ),
  'id_card': _ModeContent(
    tip: 'Hold card steady — both sides will be captured',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Both sides',
          color: Color(0xFFEC4899),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.card, label: 'MRZ detect'),
      _FeatureChip(icon: Iconsax.sun_1, label: 'Glare fix'),
      _FeatureChip(icon: Iconsax.crop, label: 'Auto align'),
      _FeatureChip(icon: Iconsax.text, label: 'Extract text'),
    ],
  ),
  'driving_license': _ModeContent(
    tip: 'Capture front and back for complete license details',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Both sides',
          color: Color(0xFFEC4899),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.card_tick_1, label: 'DLIMS detect'),
      _FeatureChip(icon: Iconsax.sun_1, label: 'Glare fix'),
      _FeatureChip(icon: Iconsax.crop, label: 'Auto align'),
      _FeatureChip(icon: Iconsax.text, label: 'Extract text'),
    ],
  ),
  'vehicle_rc': _ModeContent(
    tip: 'Capture all RC pages clearly (book or card format)',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Multi-page',
          color: Color(0xFFEC4899),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.car, label: 'RC detect'),
      _FeatureChip(icon: Iconsax.document_text, label: 'OCR fields'),
      _FeatureChip(icon: Iconsax.shield_tick, label: 'Token tax check'),
      _FeatureChip(icon: Iconsax.text, label: 'Ownership history'),
    ],
  ),
  'medical_prescription': _ModeContent(
    tip: 'Capture full prescription clearly (doctor and medicine section)',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Multi-page',
          color: Color(0xFFEC4899),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.magic_star, label: 'Handwriting OCR'),
      _FeatureChip(icon: Iconsax.note_text, label: 'Medicine parse'),
      _FeatureChip(icon: Iconsax.warning_2, label: 'Drug interaction'),
      _FeatureChip(icon: Iconsax.notification, label: 'Set reminders'),
    ],
  ),
  'bank_statement': _ModeContent(
    tip: 'Capture all pages in sequence for accurate transaction extraction',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Multi-page',
          color: Color(0xFFEC4899),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.bank, label: 'Bank format detect'),
      _FeatureChip(icon: Iconsax.document_text, label: 'Transaction OCR'),
      _FeatureChip(icon: Iconsax.chart_2, label: 'Credit vs Debit'),
      _FeatureChip(icon: Iconsax.export_1, label: 'Excel export'),
    ],
  ),
  'academic_certificate': _ModeContent(
    tip: 'Capture full document including seal, signatures and QR',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Multi-page',
          color: Color(0xFFEC4899),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.scan, label: 'HEC QR detect'),
      _FeatureChip(icon: Iconsax.shield_tick, label: 'Security check'),
      _FeatureChip(icon: Iconsax.document_text, label: 'Academic profile'),
      _FeatureChip(icon: Iconsax.warning_2, label: 'Fake flags'),
    ],
  ),
  'passport': _ModeContent(
    tip: 'Open to photo page, lay flat under good light',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.personalcard,
          label: 'ID scan',
          color: Color(0xFFF43F5E),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.scan, label: 'MRZ extract'),
      _FeatureChip(icon: Iconsax.crop, label: 'Photo page'),
      _FeatureChip(icon: Iconsax.magicpen, label: 'Auto-align'),
      _FeatureChip(icon: Iconsax.text, label: 'Data extract'),
    ],
  ),
  'receipt': _ModeContent(
    tip: 'Flatten receipt fully — creases reduce OCR accuracy',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.receipt,
          label: 'Long doc',
          color: Color(0xFF22C55E),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.crop, label: 'Auto-straighten'),
      _FeatureChip(icon: Iconsax.sun_1, label: 'Fade fix'),
      _FeatureChip(icon: Iconsax.document, label: 'Long doc mode'),
      _FeatureChip(icon: Iconsax.text, label: 'Amount extract'),
    ],
  ),
  'book': _ModeContent(
    tip:
        'Capture full page/spread; curvature and finger edge cleanup are applied',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.book,
          label: 'Dual page',
          color: Color(0xFFF97316),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.scan,
          label: 'Batch scan',
          color: Color(0xFFEC4899),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.magicpen, label: 'Spine shadow'),
      _FeatureChip(icon: Iconsax.crop, label: 'Page flatten'),
      _FeatureChip(icon: Iconsax.element_3, label: 'Dual page split'),
      _FeatureChip(icon: Iconsax.text, label: 'EN+Urdu OCR'),
      _FeatureChip(icon: Iconsax.document_text, label: 'TOC + headings'),
      _FeatureChip(icon: Iconsax.export_1, label: 'PDF/DOCX/EPUB'),
    ],
  ),
  'table': _ModeContent(
    tip: 'Avoid glare — frame all borders for accurate detection',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.element_3,
          label: 'CSV export',
          color: Color(0xFF84CC16),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.element_3, label: 'Table detect'),
      _FeatureChip(icon: Iconsax.magicpen, label: 'Border enhance'),
      _FeatureChip(icon: Iconsax.text, label: 'OCR cells'),
      _FeatureChip(icon: Iconsax.document, label: 'CSV export'),
    ],
  ),
  'whiteboard': _ModeContent(
    tip: 'Fill frame with board — glare is auto-removed',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.text_block,
          label: 'Enhance',
          color: Color(0xFF06B6D4),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.sun_1, label: 'Glare remove'),
      _FeatureChip(icon: Iconsax.crop, label: 'Perspective fix'),
      _FeatureChip(icon: Iconsax.magicpen, label: 'Enhance text'),
      _FeatureChip(icon: Iconsax.text, label: 'OCR text'),
    ],
  ),
  'photo': _ModeContent(
    tip: 'Full resolution photo — no enhancement applied',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Gallery',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.sun_1, label: 'HDR mode'),
      _FeatureChip(icon: Iconsax.personalcard, label: 'Portrait'),
      _FeatureChip(icon: Iconsax.camera, label: 'Full res'),
      _FeatureChip(icon: Iconsax.magicpen, label: 'Vivid color'),
    ],
  ),
  'qr': _ModeContent(
    tip: 'Point camera — QR and barcodes auto-detected',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'From image',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.scan_barcode,
          label: 'Barcode',
          color: Color(0xFF6366F1),
          action: 'camera'),
      _ImportOption(
          icon: Iconsax.link,
          label: 'URL open',
          color: Color(0xFF22C55E),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.copy,
          label: 'Copy code',
          color: Color(0xFFF59E0B),
          action: 'gallery'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.scan_barcode, label: 'Auto detect'),
      _FeatureChip(icon: Iconsax.link, label: 'Open URL'),
      _FeatureChip(icon: Iconsax.copy, label: 'Copy code'),
      _FeatureChip(icon: Iconsax.share, label: 'Share'),
    ],
  ),
  'gallery': _ModeContent(
    tip: 'Select multiple images to combine into one PDF',
    importOptions: [
      _ImportOption(
          icon: Iconsax.gallery,
          label: 'Photos',
          color: Color(0xFF3B82F6),
          action: 'gallery'),
      _ImportOption(
          icon: Iconsax.folder_open,
          label: 'Files',
          color: Color(0xFFF59E0B),
          action: 'files'),
      _ImportOption(
          icon: Iconsax.camera,
          label: 'Camera',
          color: Color(0xFF22C55E),
          action: 'camera'),
    ],
    featureChips: [
      _FeatureChip(icon: Iconsax.gallery, label: 'Multi-import'),
      _FeatureChip(icon: Iconsax.document, label: 'PDF merge'),
      _FeatureChip(icon: Iconsax.magicpen, label: 'Batch enhance'),
      _FeatureChip(icon: Iconsax.arrange_square, label: 'Reorder pages'),
    ],
  ),
};

/// Live in-app [CameraPreview] for every mode except QR (CamScanner-style viewfinder).
bool _usesFlutterCameraPreview(String modeId) => modeId != 'qr';

/// Open CamScanner-style deskew after capture for document-like modes.
bool _useDeskewAfterCapture(String modeId) {
  const modes = {
    'document',
    'id_card',
    'driving_license',
    'vehicle_rc',
    'medical_prescription',
    'bank_statement',
    'academic_certificate',
    'passport',
    'receipt',
    'book',
    'table',
    'whiteboard',
  };
  return modes.contains(modeId);
}

// ── Frame type enum ──────────────────────────────────────────────────────────

enum _FrameType {
  document,
  idCard,
  passport,
  license,
  certificate,
  qr,
  book,
  whiteboard,
  receipt,
  table,
  photo,
}

_FrameType _frameTypeFor(String modeId) {
  switch (modeId) {
    case 'qr':
      return _FrameType.qr;
    case 'id_card':
      return _FrameType.idCard;
    case 'passport':
      return _FrameType.passport;
    case 'driving_license':
      return _FrameType.license;
    case 'academic_certificate':
      return _FrameType.certificate;
    case 'book':
      return _FrameType.book;
    case 'whiteboard':
      return _FrameType.whiteboard;
    case 'receipt':
      return _FrameType.receipt;
    case 'table':
      return _FrameType.table;
    case 'photo':
      return _FrameType.photo;
    default:
      return _FrameType.document;
  }
}

// ────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  final String scanType;

  /// When set (e.g. from Templates), shown under the scan title.
  final String? templateLabel;
  const ScanScreen({super.key, required this.scanType, this.templateLabel});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;

  /// 0 = off, 1 = auto, 2 = torch (cycle on same button).
  int _flashMode = 0;
  bool _isCapturing = false;
  int _currentCameraIndex = 0;

  final GlobalKey _previewKey = GlobalKey();
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _pinchStartZoom = 1.0;

  /// Double-tap preview: alignment grid (no extra toolbar buttons).
  bool _showAlignmentGrid = false;
  bool _idBackSide = false;

  bool _prefAutoEnhance = true;
  String _prefQuality = 'High';

  // Pages
  final List<String> _capturedPages = [];

  // Mode
  late String _selectedMode;
  String _selectedFilter = 'auto';

  // Scan-line animation
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  // Mode scroll
  final ScrollController _modeScrollController = ScrollController();

  MobileScannerController? _qrController;
  String? _lastBarcode;
  DateTime? _lastBarcodeAt;

  bool _isSavingScan = false;

  bool _showZoomHud = false;
  Timer? _zoomHudTimer;

  Offset? _focusPoint;
  bool _showFocusRing = false;
  Timer? _focusRingTimer;

  final bool _timerModeEnabled = false;
  int _timerCountdown = 0;
  Timer? _countdownTimer;
  String? _pendingFeatureAction;
  bool _longDocModeEnabled = false;
  String _qrResultAction = 'dialog';

  @override
  void initState() {
    super.initState();
    // Honor any mode that has capture UI + tips (includes gallery-only ids).
    _selectedMode = _kModeContent.containsKey(widget.scanType)
        ? widget.scanType
        : 'document';

    if (_selectedMode == 'qr') {
      _qrController = MobileScannerController();
    } else {
      _bootstrapCamera();
    }

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scanLineAnim = CurvedAnimation(
      parent: _scanLineCtrl,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  Future<void> _bootstrapCamera() async {
    if (!mounted) return;
    setState(() {
      _prefAutoEnhance =
          AppLocalStorage.getBool('autoEnhance', defaultValue: true);
      _prefQuality =
          AppLocalStorage.getString('defaultQuality', defaultValue: 'High');
    });
    await _initCamera();
  }

  ResolutionPreset _primaryResolutionPreset() {
    switch (_prefQuality) {
      case 'Ultra':
        return ResolutionPreset.ultraHigh;
      case 'High':
        return ResolutionPreset.veryHigh;
      case 'Medium':
        return ResolutionPreset.high;
      case 'Low':
        return ResolutionPreset.medium;
      default:
        return ResolutionPreset.veryHigh;
    }
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
    CameraController? controller;
    Future<bool> tryInit(ResolutionPreset preset) async {
      final c = CameraController(camera, preset, enableAudio: false);
      try {
        await c.initialize();
        controller = c;
        return true;
      } catch (e) {
        debugPrint('Camera preset $preset failed: $e');
        await c.dispose();
        return false;
      }
    }

    if (!await tryInit(_primaryResolutionPreset())) {
      if (!await tryInit(ResolutionPreset.high)) {
        await tryInit(ResolutionPreset.medium);
      }
    }
    if (controller == null) return;

    final c = controller!;
    try {
      await c.setFocusMode(FocusMode.auto);
      try {
        _minZoom = await c.getMinZoomLevel();
        _maxZoom = await c.getMaxZoomLevel();
        _currentZoom = _minZoom;
        await c.setZoomLevel(_currentZoom);
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _currentZoom = 1.0;
      }
      await _applyFlashMode(c);
    } catch (e) {
      debugPrint('Camera post-init: $e');
    }

    if (mounted) {
      setState(() {
        _cameraController = c;
        _isCameraReady = true;
      });
    }
  }

  Future<void> _applyFlashMode([CameraController? c]) async {
    final ctrl = c ?? _cameraController;
    if (ctrl == null) return;
    try {
      switch (_flashMode % 3) {
        case 0:
          await ctrl.setFlashMode(FlashMode.off);
          break;
        case 1:
          await ctrl.setFlashMode(FlashMode.auto);
          break;
        case 2:
          await ctrl.setFlashMode(FlashMode.torch);
          break;
      }
    } catch (e) {
      debugPrint('Flash mode: $e');
    }
  }

  Future<void> _cycleFlash() async {
    if (_selectedMode == 'qr') {
      HapticFeedback.lightImpact();
      try {
        await _qrController?.toggleTorch();
      } catch (_) {}
      return;
    }
    if (_cameraController == null) return;
    HapticFeedback.lightImpact();
    setState(() => _flashMode = (_flashMode + 1) % 3);
    await _applyFlashMode();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Standalone "Gallery" scan tab uses document-style processing (CamScanner-like).
  String get _pipelineModeId =>
      _selectedMode == 'gallery' ? 'document' : _selectedMode;

  double? _targetAspectRatioForPipeline() {
    final m = _pipelineModeId;
    if (m == 'id_card' || m == 'driving_license') return 85.6 / 54.0;
    if (m == 'passport') return 125.0 / 88.0;
    return null;
  }

  /// Auto-enhance / polish, then optional manual align sheet — same as after camera capture.
  Future<String> _polishDeskewStillPath(String rawPath) async {
    final mode = _pipelineModeId;
    var outPath = rawPath;
    final targetAspectRatio = _targetAspectRatioForPipeline();
    if (_prefAutoEnhance) {
      final processed = await ImageProcessingService.instance.processCapture(
        imagePath: outPath,
        modeId: mode,
        enhanceMode: _enhanceModeFromFilter(_selectedFilter),
        targetAspectRatio: targetAspectRatio,
      );
      outPath = processed.imagePath;
    } else {
      outPath =
          await ImageEnhancementService.instance.polishCaptureForScanMode(
        outPath,
        mode,
        filter: _selectedFilter,
      );
    }
    if (_useDeskewAfterCapture(mode) && mounted) {
      final deskewed = await Navigator.push<String?>(
        context,
        MaterialPageRoute<String?>(
          fullscreenDialog: true,
          builder: (_) => DocumentScanEditorScreen(
            imagePath: outPath,
            targetAspectRatio: targetAspectRatio,
          ),
        ),
      );
      if (deskewed != null) outPath = deskewed;
    }
    return outPath;
  }

  void _startTimerCapture() {
    if (_timerCountdown > 0) return;
    setState(() => _timerCountdown = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timerCountdown--);
      if (_timerCountdown <= 0) {
        t.cancel();
        _captureImage(fromTimerCapture: true);
      }
    });
  }

  Future<void> _captureImage({bool fromTimerCapture = false}) async {
    if (!fromTimerCapture &&
        _timerModeEnabled &&
        _timerCountdown == 0 &&
        _selectedMode != 'qr' &&
        _selectedMode != 'gallery') {
      _startTimerCapture();
      return;
    }
    if (_isCapturing) return;
    if (_selectedMode == 'qr') return;
    if (_selectedMode == 'gallery') {
      await _pickFromGallery();
      return;
    }
    if (_cameraController == null || !_isCameraReady) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    final sw = Stopwatch()..start();
    try {
      final image = await _cameraController!.takePicture();
      var outPath = await _polishDeskewStillPath(image.path);
      if (!mounted) return;
      var captured = <String>[outPath];
      if (_pendingFeatureAction == 'dual_page_split' ||
          _selectedMode == 'book') {
        captured = await _splitDualPages(outPath);
      }
      setState(() {
        _capturedPages.addAll(captured);
        _isCapturing = false;
      });
      PaintingBinding.instance.imageCache.clearLiveImages();
      final firstPath = captured.first;
      if (_pendingFeatureAction == 'ocr_text') {
        final text = await OcrService.instance.extractText(firstPath);
        await _showTextResultSheet(
            'OCR Text', text.isEmpty ? 'No text found.' : text);
      } else if (_pendingFeatureAction == 'mrz_extract') {
        final mrz = await _extractMrzText(firstPath);
        await _showTextResultSheet(
            'MRZ Extract', mrz.isEmpty ? 'No MRZ detected.' : mrz);
      } else if (_pendingFeatureAction == 'amount_extract') {
        final txt = await OcrService.instance.extractText(firstPath);
        final amounts = _extractAmounts(txt);
        await _showTextResultSheet(
          'Receipt Amounts',
          amounts.isEmpty ? 'No amounts detected.' : amounts.join('\n'),
        );
      } else if (_pendingFeatureAction == 'csv_export') {
        final txt = await OcrService.instance.extractText(firstPath);
        final csv = await _saveCsvFromText(txt);
        _showInfoSnack('CSV exported: ${p.basename(csv)}');
      }
      _pendingFeatureAction = null;
      if (_selectedMode == 'id_card' && mounted && !_longDocModeEnabled) {
        if (_capturedPages.length < 2) {
          _showInfoSnack('Front side captured. Now capture the back side.');
          _afterPagesAddedSnack(captured.length);
          return;
        }
        final front = _capturedPages[_capturedPages.length - 2];
        final back = _capturedPages.last;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IdCardResultScreen(
              frontImagePath: front,
              backImagePath: back,
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'driving_license' &&
          mounted &&
          !_longDocModeEnabled) {
        if (_capturedPages.length < 2) {
          _showInfoSnack('Front side captured. Now capture the back side.');
          _afterPagesAddedSnack(captured.length);
          return;
        }
        final front = _capturedPages[_capturedPages.length - 2];
        final back = _capturedPages.last;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DrivingLicenseResultScreen(
              frontImagePath: front,
              backImagePath: back,
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'vehicle_rc' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleRcResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'medical_prescription' &&
          mounted &&
          !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicalPrescriptionResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'bank_statement' &&
          mounted &&
          !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BankStatementResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'academic_certificate' &&
          mounted &&
          !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AcademicCertificateResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'book' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'table' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TableResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'whiteboard' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WhiteboardResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'photo' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoEnhancementScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'passport' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassportResultScreen(imagePath: firstPath),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      if (_selectedMode == 'receipt' && mounted && !_longDocModeEnabled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptResultScreen(
              imagePaths: List<String>.from(_capturedPages),
            ),
          ),
        );
        _afterPagesAddedSnack(captured.length);
        return;
      }
      // Auto-navigate to edit screen after capture (CamScanner style)
      if (mounted && !_longDocModeEnabled) {
        final result = await _pushWithCameraPause<List<String>>(
          MaterialPageRoute(
            builder: (_) => EditScanScreen(
              imagePaths: List<String>.from(_capturedPages),
              scanType: _selectedMode,
            ),
          ),
        );
        // If user added/removed pages in edit screen, sync back
        if (result != null && mounted) {
          setState(() {
            _capturedPages.clear();
            _capturedPages.addAll(result);
          });
        }
      }
      _afterPagesAddedSnack(captured.length);
      sw.stop();
      debugPrint('Scan post-processing took: ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      setState(() => _isCapturing = false);
      sw.stop();
      debugPrint(
          'Scan post-processing failed after: ${sw.elapsedMilliseconds}ms');
    }
  }

  Future<T?> _pushWithCameraPause<T>(Route<T> route) async {
    final shouldResume = _usesFlutterCameraPreview(_selectedMode);
    if (shouldResume && _cameraController != null) {
      await _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isCameraReady = false);
    }
    if (!mounted) return null;
    final result = await Navigator.push<T>(context, route);
    if (mounted && shouldResume) {
      await _bootstrapCamera();
    }
    return result;
  }

  CamScanEnhanceMode _enhanceModeFromFilter(String filterId) {
    switch (filterId) {
      case 'magic':
      case 'color':
        return CamScanEnhanceMode.magic;
      case 'bw':
        return CamScanEnhanceMode.blackWhite;
      case 'grayscale':
        return CamScanEnhanceMode.grayscale;
      case 'none':
        return CamScanEnhanceMode.original;
      case 'auto':
      default:
        return CamScanEnhanceMode.auto;
    }
  }

  void _afterPagesAddedSnack(int count) {
    if (!mounted) return;
    final total = _capturedPages.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 1
              ? 'Added $count page(s) — $total total'
              : 'Page $total captured!',
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

  Future<List<String>> _splitDualPages(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final src = img.decodeImage(bytes);
      if (src == null) return [imagePath];
      final halfW = src.width ~/ 2;
      final left =
          img.copyCrop(src, x: 0, y: 0, width: halfW, height: src.height);
      final right = img.copyCrop(
        src,
        x: halfW,
        y: 0,
        width: src.width - halfW,
        height: src.height,
      );
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final leftPath = p.join(dir.path, 'dual_left_$ts.jpg');
      final rightPath = p.join(dir.path, 'dual_right_$ts.jpg');
      await File(leftPath).writeAsBytes(img.encodeJpg(left, quality: 92));
      await File(rightPath).writeAsBytes(img.encodeJpg(right, quality: 92));
      return [leftPath, rightPath];
    } catch (_) {
      return [imagePath];
    }
  }

  Future<String> _extractMrzText(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final src = img.decodeImage(bytes);
      if (src == null) return '';
      final y = (src.height * 0.68).round().clamp(0, src.height - 1);
      final mrz = img.copyCrop(src,
          x: 0, y: y, width: src.width, height: src.height - y);
      final dir = await getTemporaryDirectory();
      final pathOut =
          p.join(dir.path, 'mrz_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(pathOut).writeAsBytes(img.encodeJpg(mrz, quality: 92));
      return OcrService.instance.extractText(pathOut);
    } catch (_) {
      return '';
    }
  }

  List<String> _extractAmounts(String text) {
    final exp = RegExp(
        r'(?<!\d)(?:\$|USD|EUR|PKR|Rs\.?)?\s?\d{1,3}(?:[,.\s]\d{3})*(?:[.,]\d{2})?(?!\d)');
    return exp
        .allMatches(text)
        .map((m) => m.group(0)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<String> _saveCsvFromText(String text) async {
    final dir = await getTemporaryDirectory();
    final filePath =
        p.join(dir.path, 'table_${DateTime.now().millisecondsSinceEpoch}.csv');
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => '"${e.replaceAll('"', '""')}"')
        .toList();
    await File(filePath).writeAsString('text\n${lines.join('\n')}');
    return filePath;
  }

  Future<void> _showTextResultSheet(String title, String text) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navyDark,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  )),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style:
                        GoogleFonts.nunito(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty || !mounted) return;
    setState(() => _isCapturing = true);
    try {
      final paths = <String>[];
      for (final xfile in images) {
        if (!mounted) break;
        var one = await _polishDeskewStillPath(xfile.path);
        if (_pendingFeatureAction == 'dual_page_split' ||
            _selectedMode == 'book') {
          paths.addAll(await _splitDualPages(one));
        } else {
          paths.add(one);
        }
      }
      if (mounted && paths.isNotEmpty) {
        setState(() => _capturedPages.addAll(paths));
        PaintingBinding.instance.imageCache.clearLiveImages();
        _afterPagesAddedSnack(paths.length);
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Options for the “+” sheet only (gallery side button handles plain gallery).
  List<_ImportOption> _sheetExtraImportOptions() {
    final raw = _kModeContent[_selectedMode]?.importOptions ?? const [];
    return raw.where((o) {
      if (o.label == 'Gallery' && o.action == 'gallery') return false;
      if (o.label == 'Photos' && o.action == 'gallery') return false;
      if (o.label == 'Files' && o.action == 'files') return false;
      if (o.label == 'Camera' && o.action == 'camera') return false;
      return true;
    }).toList();
  }

  String _importOptionSubtitle(_ImportOption opt) {
    final l = opt.label.toLowerCase();
    if (l.contains('both sides')) {
      return 'Pick front and back from gallery (two steps)';
    }
    if (opt.label == 'Long doc' ||
        l.contains('multi-page') ||
        l.contains('batch scan') ||
        opt.label == 'Dual page' ||
        opt.label == 'CSV export') {
      return 'Multi-page: use shutter, then tap Done';
    }
    switch (opt.action) {
      case 'gallery':
        return 'Add photos from gallery';
      case 'files':
        return 'Pick image files on this device';
      case 'camera':
        if (opt.label == 'Barcode') return 'Live camera scan';
        return 'Take one photo';
      case 'cloud':
        return 'Pick files on this device';
      default:
        return '';
    }
  }

  Future<void> _showImportSheet() async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImportSheet(
        modeTitle: _scanTypeLabel(),
        modeOptions: _sheetExtraImportOptions(),
        optionSubtitle: _importOptionSubtitle,
        onModeOptionTap: (opt) {
          Navigator.pop(ctx);
          _handleImportOption(opt);
        },
        onPickFiles: () {
          Navigator.pop(ctx);
          _pickFromFiles();
        },
        onPickCamera: () {
          Navigator.pop(ctx);
          _pickSingleWithCamera();
        },
        onSwitchCamera: () {
          Navigator.pop(ctx);
          _flipCamera();
        },
      ),
    );
  }

  Future<void> _pickSingleWithCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null || !mounted) return;
    setState(() => _isCapturing = true);
    try {
      var path = await _polishDeskewStillPath(image.path);
      final added = <String>[];
      if (_pendingFeatureAction == 'dual_page_split' ||
          _selectedMode == 'book') {
        added.addAll(await _splitDualPages(path));
      } else {
        added.add(path);
      }
      if (mounted && added.isNotEmpty) {
        setState(() => _capturedPages.addAll(added));
        PaintingBinding.instance.imageCache.clearLiveImages();
        _afterPagesAddedSnack(added.length);
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'heif',
          'dng',
          'raw'
        ],
      );
      if (result != null && mounted) {
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
        if (paths.isNotEmpty) {
          setState(() => _capturedPages.addAll(paths));
          _afterPagesAddedSnack(paths.length);
        }
      }
    } catch (e) {
      debugPrint('File picker: $e');
    }
  }

  Future<void> _handleImportOption(_ImportOption opt) async {
    if (_selectedMode == 'id_card' && opt.label == 'Both sides') {
      await _pickFromGallery();
      await _pickFromGallery();
      return;
    }
    if (_selectedMode == 'receipt' && opt.label == 'Long doc') {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack('Long doc mode enabled. Capture pages, then tap Done.');
      return;
    }
    if (_selectedMode == 'vehicle_rc' && opt.label == 'Multi-page') {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack(
          'Multi-page mode enabled. Capture all RC pages, then tap Done.');
      return;
    }
    if (_selectedMode == 'medical_prescription' && opt.label == 'Multi-page') {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack(
          'Multi-page mode enabled. Capture all prescription pages, then tap Done.');
      return;
    }
    if (_selectedMode == 'bank_statement' && opt.label == 'Multi-page') {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack(
          'Multi-page mode enabled. Capture all statement pages, then tap Done.');
      return;
    }
    if (_selectedMode == 'academic_certificate' && opt.label == 'Multi-page') {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack(
          'Multi-page mode enabled. Capture all academic pages, then tap Done.');
      return;
    }
    if (_selectedMode == 'book' &&
        (opt.label == 'Batch scan' || opt.label == 'Dual page')) {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack(
          'Book batch mode enabled. Capture pages/spreads, then tap Done.');
      return;
    }
    if (_selectedMode == 'table' && opt.label == 'CSV export') {
      setState(() => _longDocModeEnabled = true);
      _showInfoSnack(
          'Table batch mode enabled. Capture all pages, then tap Done.');
      return;
    }
    if (_selectedMode == 'table' && opt.label == 'CSV export') {
      setState(() => _pendingFeatureAction = 'csv_export');
      _showInfoSnack('CSV export will run after next capture.');
      return;
    }
    if (_selectedMode == 'qr' && opt.label == 'Barcode') {
      await _selectMode('qr');
      return;
    }
    if (_selectedMode == 'qr' && opt.label == 'URL open') {
      setState(() => _qrResultAction = 'open_url');
      await _selectMode('qr');
      _showInfoSnack('QR action: open URL');
      return;
    }
    if (_selectedMode == 'qr' && opt.label == 'Copy code') {
      setState(() => _qrResultAction = 'copy_code');
      await _selectMode('qr');
      _showInfoSnack('QR action: copy code');
      return;
    }
    switch (opt.action) {
      case 'gallery':
        await _pickFromGallery();
        break;
      case 'files':
        await _pickFromFiles();
        break;
      case 'camera':
        await _pickSingleWithCamera();
        break;
      case 'cloud':
        await _pickFromFiles();
        break;
    }
  }

  void _showInfoSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onPreviewTapUp(TapUpDetails d) async {
    final ctx = _previewKey.currentContext;
    if (ctx == null || _cameraController == null || !_isCameraReady) return;
    final rb = ctx.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final local = rb.globalToLocal(d.globalPosition);
    final size = rb.size;
    if (size.width <= 0 || size.height <= 0) return;
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    try {
      await _cameraController!.setFocusPoint(Offset(nx, ny));
      await _cameraController!.setExposurePoint(Offset(nx, ny));
      HapticFeedback.selectionClick();
      setState(() {
        _focusPoint = local;
        _showFocusRing = true;
      });
      _focusRingTimer?.cancel();
      _focusRingTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showFocusRing = false);
      });
    } catch (e) {
      debugPrint('Focus tap: $e');
    }
  }

  void _toggleAlignmentGrid() {
    HapticFeedback.lightImpact();
    setState(() => _showAlignmentGrid = !_showAlignmentGrid);
  }

  void _onPinchStart(ScaleStartDetails details) {
    _pinchStartZoom = _currentZoom;
  }

  Future<void> _onPinchUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null || !_isCameraReady) return;
    if (_maxZoom <= _minZoom) return;
    if (details.pointerCount < 2) return;
    final target = (_pinchStartZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((target - _currentZoom).abs() < 0.01) return;
    try {
      await _cameraController!.setZoomLevel(target);
      if (mounted) {
        setState(() {
          _currentZoom = target;
          _showZoomHud = true;
        });
        _zoomHudTimer?.cancel();
        _zoomHudTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showZoomHud = false);
        });
      }
    } catch (e) {
      debugPrint('Zoom: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_selectedMode == 'qr') {
      HapticFeedback.lightImpact();
      try {
        await _qrController?.switchCamera();
      } catch (_) {}
      return;
    }
    if (_cameras.length < 2) return;
    HapticFeedback.lightImpact();
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    setState(() => _isCameraReady = false);
    await _setupCamera(_cameras[_currentCameraIndex]);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    final now = DateTime.now();
    if (_lastBarcode == raw &&
        _lastBarcodeAt != null &&
        now.difference(_lastBarcodeAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastBarcode = raw;
    _lastBarcodeAt = now;
    HapticFeedback.heavyImpact();
    if (_qrResultAction == 'copy_code') {
      Clipboard.setData(ClipboardData(text: raw));
      _showInfoSnack('Copied to clipboard');
      return;
    }
    if (_qrResultAction == 'open_url') {
      final uri = Uri.tryParse(raw);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showInfoSnack('Scanned code is not a valid URL');
      }
      return;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Code scanned',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SelectableText(
          raw,
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.tryParse(raw);
              if (uri != null &&
                  (uri.scheme == 'http' || uri.scheme == 'https')) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showInfoSnack('Scanned code is not a valid URL');
              }
            },
            child: Text(
              'Open',
              style: GoogleFonts.nunito(color: AppColors.gold),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied to clipboard',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child:
                Text('Copy', style: GoogleFonts.nunito(color: AppColors.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.nunito(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _proceedToEdit() {
    if (_capturedPages.isEmpty) return;
    if (_selectedMode == 'book') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookResultScreen(
            imagePaths: List<String>.from(_capturedPages),
          ),
        ),
      );
      return;
    }
    if (_selectedMode == 'table') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TableResultScreen(
            imagePaths: List<String>.from(_capturedPages),
          ),
        ),
      );
      return;
    }
    if (_selectedMode == 'whiteboard') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WhiteboardResultScreen(
            imagePaths: List<String>.from(_capturedPages),
          ),
        ),
      );
      return;
    }
    if (_selectedMode == 'photo') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoEnhancementScreen(
            imagePaths: List<String>.from(_capturedPages),
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditScanScreen(
          imagePaths: List<String>.from(_capturedPages),
          scanType: _selectedMode,
        ),
      ),
    );
  }

  String _defaultQuickSaveName() {
    final n = DateTime.now();
    final d = '${n.day}-${n.month}-${n.year}';
    switch (_selectedMode) {
      case 'document':
        return 'Document_$d';
      case 'receipt':
        return 'Receipt_$d';
      case 'id_card':
        return 'ID_$d';
      case 'driving_license':
        return 'DL_$d';
      case 'vehicle_rc':
        return 'VehicleRC_$d';
      case 'medical_prescription':
        return 'Prescription_$d';
      case 'bank_statement':
        return 'BankStatement_$d';
      case 'academic_certificate':
        return 'Academic_$d';
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
      default:
        return 'Scan_$d';
    }
  }

  void _scheduleOcrIndexFromScan(int documentId, List<String> imagePaths) {
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

  void _previewCapturedPage(int index) {
    if (index < 0 || index >= _capturedPages.length) return;
    showDialog<void>(
      context: context,
      barrierColor: AppColors.navyDark.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(_capturedPages[index]),
                    fit: BoxFit.contain,
                    cacheWidth: 1080,
                    filterQuality: FilterQuality.medium,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded || frame != null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Page ${index + 1} of ${_capturedPages.length}',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickSaveSheet() async {
    if (_capturedPages.isEmpty || _isSavingScan) return;
    final nameCtrl = TextEditingController(text: _defaultQuickSaveName());
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
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
              const SizedBox(height: 18),
              Text(
                'Save to library',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PDF · ${_capturedPages.length} page(s)',
                style: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Document name',
                  hintStyle: GoogleFonts.nunito(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.nunito(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final t = nameCtrl.text.trim();
                        Navigator.pop(sheetCtx, t.isEmpty ? null : t);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navyDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    nameCtrl.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      await _performQuickSaveToLibrary(name);
    }
  }

  Future<void> _performQuickSaveToLibrary(String docName) async {
    if (_isSavingScan || _capturedPages.isEmpty) return;
    setState(() => _isSavingScan = true);
    try {
      final paths = List<String>.from(_capturedPages);
      final filePath =
          await PdfService.instance.createPdfFromImages(paths, docName);
      final thumbPath = await PdfService.instance.generateThumbnail(paths[0]);
      final fileSizeMB = await PdfService.instance.getFileSizeMB(filePath);
      final doc = DocumentModel(
        name: docName,
        filePath: filePath,
        fileType: 'pdf',
        scanType: _selectedMode,
        pageCount: paths.length,
        fileSizeMB: fileSizeMB,
        createdAt: DateTime.now(),
        thumbnailPath: thumbPath,
        tags: const [],
      );
      final id = await DatabaseService.instance.insertDocument(doc);
      await AppLocalStorage.setString('lastSavedDocName', docName);
      _scheduleOcrIndexFromScan(id, paths);
      if (!mounted) return;
      setState(() {
        _capturedPages.clear();
        _isSavingScan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved: $docName',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingScan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Save failed: $e',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Camera Permission',
          style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Camera access is needed to scan documents.',
          style: GoogleFonts.nunito(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_modeScrollController.hasClients) return;
      final maxScroll = _modeScrollController.position.maxScrollExtent;
      final totalItems = _kScanModes.length;
      if (totalItems == 0) return;
      final targetOffset = (maxScroll / (totalItems - 1)) * index;
      _modeScrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _selectMode(String id) async {
    if (id == _selectedMode) return;
    HapticFeedback.selectionClick();
    final wasQr = _selectedMode == 'qr';
    final willQr = id == 'qr';
    final wasCam = _usesFlutterCameraPreview(_selectedMode);
    final willCam = _usesFlutterCameraPreview(id);

    if (wasQr && !willQr) {
      await _qrController?.dispose();
      _qrController = null;
      await _bootstrapCamera();
    } else if (!wasQr && willQr) {
      await _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isCameraReady = false);
      _qrController = MobileScannerController();
    } else {
      if (wasCam && !willCam) {
        await _cameraController?.dispose();
        _cameraController = null;
        if (mounted) setState(() => _isCameraReady = false);
      } else if (!wasCam && willCam) {
        await _bootstrapCamera();
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedMode = id;
      _selectedFilter = 'auto';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _zoomHudTimer?.cancel();
    _focusRingTimer?.cancel();
    _countdownTimer?.cancel();
    _qrController?.dispose();
    _cameraController?.dispose();
    _scanLineCtrl.dispose();
    _modeScrollController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live QR scanner OR camera preview
          if (_selectedMode == 'qr')
            Positioned.fill(
              child: _qrController != null
                  ? MobileScanner(
                      controller: _qrController!,
                      fit: BoxFit.cover,
                      onDetect: _onBarcodeDetected,
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
            )
          else if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: GestureDetector(
                key: _previewKey,
                behavior: HitTestBehavior.opaque,
                onTapUp: _onPreviewTapUp,
                onDoubleTap: _toggleAlignmentGrid,
                onScaleStart: _onPinchStart,
                onScaleUpdate: _onPinchUpdate,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),

          // 2. Scan frame + scan-line (live camera + QR overlay)
          if (_selectedMode == 'qr')
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scanLineAnim,
                  builder: (_, __) => CustomPaint(
                    painter: _ScanFramePainter(
                      frameType: _FrameType.qr,
                      frameColor: _kScanModes
                          .firstWhere(
                            (m) => m.id == 'qr',
                            orElse: () => _kScanModes.first,
                          )
                          .color,
                      scanLineProgress: _scanLineAnim.value,
                      showAlignmentGrid: false,
                    ),
                  ),
                ),
              ),
            )
          else if (_usesFlutterCameraPreview(_selectedMode))
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
                    showAlignmentGrid: _showAlignmentGrid,
                  ),
                ),
              ),
            ),

          if (_showZoomHud && _selectedMode != 'qr')
            Positioned(
              bottom: 320,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showZoomHud ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentZoom.toStringAsFixed(1)}×',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_showFocusRing && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showFocusRing ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

          if (_timerCountdown > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '$_timerCountdown',
                    style: GoogleFonts.nunito(
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
            ),

          _buildModeHintOverlay(),

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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _scanTypeLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: _kScanModes
                            .firstWhere((m) => m.id == _selectedMode,
                                orElse: () => _kScanModes.first)
                            .color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (widget.templateLabel != null &&
                        widget.templateLabel!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Template: ${widget.templateLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_usesFlutterCameraPreview(_selectedMode) ||
                _selectedMode == 'qr') ...[
              _iconBtn(
                _flashIcon(),
                _cycleFlash,
                color: _flashMode == 0 ? Colors.white : AppColors.gold,
                bgColor: _flashMode == 0
                    ? Colors.black45
                    : AppColors.gold.withOpacity(0.2),
              ),
            ] else
              IgnorePointer(
                child: Opacity(
                  opacity: 0.22,
                  child: _iconBtn(
                    Icons.flash_off_rounded,
                    () {},
                    color: Colors.white54,
                    bgColor: Colors.black45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Pages Badge ────────────────────────────────────────────────────────────

  Widget _buildPagesBadge() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      right: 16,
      child: GestureDetector(
        onTap: _proceedToEdit,
        onLongPress: _showQuickSaveSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.navyDark.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${_capturedPages.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Edit →',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeFilterStrip() {
    final presets = _filterPresetsResolved(_selectedMode);
    if (presets.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'CAPTURE LOOK',
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              physics: const BouncingScrollPhysics(),
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = presets[i];
                final on = _selectedFilter == p.id;
                return Material(
                  color: on
                      ? AppColors.gold.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = p.id);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: on
                              ? AppColors.gold.withValues(alpha: 0.75)
                              : Colors.white.withValues(alpha: 0.12),
                          width: on ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            p.icon,
                            size: 15,
                            color: on
                                ? AppColors.gold
                                : Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.label,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: on
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildModeFeaturesPanel() {
    final content = _kModeContent[_selectedMode];
    if (content == null) return const SizedBox.shrink();

    const modeColor = AppColors.gold;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(_selectedMode),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Iconsax.info_circle,
                    size: 16, color: modeColor.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content.tip,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              Colors.transparent,
              _capturedPages.isEmpty
                  ? Colors.black.withOpacity(0.75)
                  : Colors.black.withOpacity(0.92),
              _capturedPages.isEmpty
                  ? Colors.black.withOpacity(0.90)
                  : Colors.black.withOpacity(0.98),
            ],
            stops: const [0, 0.10, 0.35, 1],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.62,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),

                  if (_longDocModeEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _capturedPages.isEmpty
                              ? null
                              : () {
                                  setState(() => _longDocModeEnabled = false);
                                  _proceedToEdit();
                                },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text(
                            'Done',
                            style:
                                GoogleFonts.nunito(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),

                  // Mode selector
                  _buildModeSelector(),

                  const SizedBox(height: 4),
                  _buildModeFeaturesPanel(),
                  _buildModeFilterStrip(),

                  // Shutter row
                  _buildShutterRow(),

                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom > 0 ? 8 : 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mode Selector ──────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B4B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'SCAN TYPE',
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.15,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          SizedBox(
            height: 72,
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.separated(
                controller: _modeScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: _kScanModes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final mode = _kScanModes[i];
                  final isSelected = _selectedMode == mode.id;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectMode(mode.id),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: 86,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF152a52)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.06),
                            width: isSelected ? 1.2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode.icon,
                              color: isSelected
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.72),
                              size: isSelected ? 18 : 16,
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                mode.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: isSelected ? 10.5 : 10,
                                  height: 1.05,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.gold
                                      : Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 2.5,
                              width: isSelected ? 28 : 0,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shutter Row ────────────────────────────────────────────────────────────

  Widget _buildShutterRow() {
    const ringColor = AppColors.gold;
    const ringW = 4.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _pickFromGallery,
                child: _galleryThumbBtn(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedMode == 'qr')
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2.5),
                        color: AppColors.gold.withOpacity(0.15),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'LIVE',
                          style: GoogleFonts.nunito(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _captureImage,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: _isCapturing ? 68 : 74,
                            height: _isCapturing ? 68 : 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: ringColor, width: ringW),
                            ),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isCapturing
                                      ? Colors.white60
                                      : Colors.white,
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
                          if (_capturedPages.isNotEmpty && !_isCapturing)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '${_capturedPages.length}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.navyDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: _selectedMode == 'qr'
                  ? GestureDetector(
                      onTap: _cycleFlash,
                      child: _sideBtn(
                        Icon(
                          _flashMode == 0
                              ? Icons.flashlight_off_rounded
                              : Icons.flashlight_on_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _showImportSheet,
                      child: _sideBtn(
                        const Icon(Iconsax.add_square,
                            color: Colors.white, size: 21),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sideBtn(Widget child) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _galleryThumbBtn() {
    if (_capturedPages.isNotEmpty) {
      final f = File(_capturedPages.last);
      if (f.existsSync()) {
        return GestureDetector(
          onTap: _pickFromGallery,
          onLongPress: () => _previewCapturedPage(_capturedPages.length - 1),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              f,
              fit: BoxFit.cover,
              cacheWidth: 256,
              filterQuality: FilterQuality.low,
            ),
          ),
        );
      }
    }
    return _sideBtn(const Icon(Iconsax.gallery, color: Colors.white, size: 22));
  }

  Widget _buildModeHintOverlay() {
    final hint = _modeHintText();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 204,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Column(
          key: ValueKey('${_selectedMode}_${_idBackSide ? 'b' : 'f'}'),
          children: [
            if (_selectedMode == 'id_card' ||
                _selectedMode == 'driving_license')
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sideToggleChip('Front', !_idBackSide,
                        () => setState(() => _idBackSide = false)),
                    const SizedBox(width: 6),
                    _sideToggleChip('Back', _idBackSide,
                        () => setState(() => _idBackSide = true)),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Text(
                hint,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideToggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            color: selected ? AppColors.navyDark : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  String _modeHintText() {
    switch (_selectedMode) {
      case 'document':
        return 'Align document within frame';
      case 'id_card':
        return _idBackSide
            ? 'Align ID card (Back side)'
            : 'Align ID card (Front side)';
      case 'passport':
        return 'Align passport photo page';
      case 'receipt':
        return 'Align receipt';
      case 'book':
        return 'Place book flat';
      case 'whiteboard':
        return 'Align whiteboard edges';
      case 'photo':
        return 'Take photo';
      case 'table':
        return 'Align table';
      case 'driving_license':
        return _idBackSide
            ? 'Align driving license (Back side)'
            : 'Align driving license (Front side)';
      case 'academic_certificate':
        return 'Align certificate';
      case 'qr':
        return 'Point at QR or Barcode';
      default:
        return 'Align inside frame';
    }
  }

  IconData _flashIcon() {
    switch (_flashMode % 3) {
      case 0:
        return Icons.flash_off_rounded;
      case 1:
        return Icons.flash_auto_rounded;
      case 2:
      default:
        return Icons.flash_on_rounded;
    }
  }

  String _scanTypeLabel() {
    return _kScanModes
        .firstWhere(
          (m) => m.id == _selectedMode,
          orElse: () => const _ScanMode(
            id: 'document',
            icon: Iconsax.document_text,
            label: 'Document',
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(13),
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
  final bool showAlignmentGrid;

  const _ScanFramePainter({
    required this.frameType,
    required this.frameColor,
    required this.scanLineProgress,
    this.showAlignmentGrid = false,
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
      case _FrameType.idCard:
        final w = size.width * 0.84;
        final h = w * 0.63;
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.28;
        bottom = top + h;
        break;
      case _FrameType.passport:
        final w = size.width * 0.84;
        final h = w * (88 / 125);
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.24;
        bottom = top + h;
        break;
      case _FrameType.license:
        final w = size.width * 0.84;
        final h = w * 0.63;
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.28;
        bottom = top + h;
        break;
      case _FrameType.certificate:
        final w = size.width * 0.78;
        final h = w * 1.414;
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.12;
        bottom = (top + h).clamp(top + 80, size.height * 0.86);
        break;
      case _FrameType.book:
        final w = size.width * 0.90;
        final h = w * 0.58;
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.22;
        bottom = top + h;
        break;
      case _FrameType.whiteboard:
        final margin = size.width * 0.05;
        left = margin;
        right = size.width - margin;
        top = size.height * 0.10;
        bottom = size.height * 0.82;
        break;
      case _FrameType.receipt:
        var rw = size.width * 0.72;
        var rh = rw * 1.28;
        final maxH = size.height * 0.58;
        if (rh > maxH) {
          rh = maxH;
          rw = rh / 1.28;
        }
        left = (size.width - rw) / 2;
        right = left + rw;
        top = size.height * 0.16;
        bottom = top + rh;
        break;
      case _FrameType.table:
        final tw = size.width * 0.90;
        final th = tw * 0.52;
        left = (size.width - tw) / 2;
        right = left + tw;
        top = size.height * 0.24;
        bottom = top + th;
        break;
      case _FrameType.photo:
        final w = size.width * 0.94;
        final h = size.height * 0.72;
        left = (size.width - w) / 2;
        right = left + w;
        top = size.height * 0.14;
        bottom = top + h;
        break;
      case _FrameType.document:
        left = 0;
        right = size.width;
        top = 0;
        bottom = size.height;
        break;
    }

    if (frameType != _FrameType.document) {
      left = left + 2;
      top = top + 2;
      right = right - 2;
      bottom = bottom - 2;
    }

    // ── Dim overlay ──
    if (frameType != _FrameType.document) {
      final dimPaint = Paint()
        ..color = Colors.black.withOpacity(0.48)
        ..style = PaintingStyle.fill;

      final framePath = Path()
        ..addRect(Rect.fromLTRB(left, top, right, bottom));
      final fullPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final dimPath =
          Path.combine(PathOperation.difference, fullPath, framePath);
      canvas.drawPath(dimPath, dimPaint);
    }

    // ── Corner brackets ──
    final bracketPaint = Paint()
      ..color = frameColor
      ..strokeWidth = 3.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLen = frameType == _FrameType.qr
        ? 22.0
        : (frameType == _FrameType.whiteboard
            ? 26.0
            : (frameType == _FrameType.receipt
                ? 24.0
                : (frameType == _FrameType.photo
                    ? 18.0
                    : (frameType == _FrameType.document ? 36.0 : 30.0))));

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

    canvas.drawLine(
        Offset(left + 4, scanY), Offset(right - 4, scanY), scanPaint);

    if (frameType == _FrameType.book) {
      final centerX = (left + right) / 2;
      final spine = Paint()
        ..color = frameColor.withValues(alpha: 0.8)
        ..strokeWidth = 1.8;
      canvas.drawLine(
          Offset(centerX, top + 8), Offset(centerX, bottom - 8), spine);
    }

    if (showAlignmentGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.22)
        ..strokeWidth = 1;
      final gw = right - left;
      final gh = bottom - top;
      for (var i = 1; i <= 2; i++) {
        final gx = left + gw * i / 3;
        canvas.drawLine(Offset(gx, top), Offset(gx, bottom), gridPaint);
        final gy = top + gh * i / 3;
        canvas.drawLine(Offset(left, gy), Offset(right, gy), gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) =>
      old.frameType != frameType ||
      old.frameColor != frameColor ||
      old.scanLineProgress != scanLineProgress ||
      old.showAlignmentGrid != showAlignmentGrid;
}

class _ImportSheet extends StatelessWidget {
  final String modeTitle;
  final List<_ImportOption> modeOptions;
  final String Function(_ImportOption opt) optionSubtitle;
  final void Function(_ImportOption opt)? onModeOptionTap;
  final VoidCallback onPickFiles;
  final VoidCallback onPickCamera;
  final VoidCallback onSwitchCamera;

  const _ImportSheet({
    required this.modeTitle,
    this.modeOptions = const [],
    required this.optionSubtitle,
    this.onModeOptionTap,
    required this.onPickFiles,
    required this.onPickCamera,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'More · $modeTitle',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Gallery button (left) opens photos only.',
                style: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _tile(
                      icon: Iconsax.folder_open,
                      label: 'Files',
                      onTap: onPickFiles,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tile(
                      icon: Iconsax.camera,
                      label: 'Camera',
                      onTap: onPickCamera,
                    ),
                  ),
                ],
              ),
            ),
            if (modeOptions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'For this scan type',
                  style: GoogleFonts.nunito(
                    color: Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    for (var i = 0; i < modeOptions.length; i++) ...[
                      _listRow(
                        context: context,
                        icon: modeOptions[i].icon,
                        label: modeOptions[i].label,
                        sub: optionSubtitle(modeOptions[i]),
                        onTap: () => onModeOptionTap?.call(modeOptions[i]),
                      ),
                      if (i < modeOptions.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _listRow(
                context: context,
                icon: Icons.flip_camera_ios_rounded,
                label: 'Switch camera',
                sub: 'Front or back camera on this device',
                onTap: onSwitchCamera,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    const brandColor = AppColors.gold;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: brandColor.withOpacity(0.4),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: brandColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    const brandColor = AppColors.gold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: brandColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.nunito(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white30,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
