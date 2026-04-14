import 'dart:ui' show Rect;

import '../models/driving_license_data.dart';
import 'ocr_service.dart';

class DrivingLicenseOcrResult {
  final DrivingLicenseData data;
  final List<Rect> frontBoxes;
  final List<Rect> backBoxes;

  const DrivingLicenseOcrResult({
    required this.data,
    required this.frontBoxes,
    required this.backBoxes,
  });
}

class DrivingLicenseOcrService {
  DrivingLicenseOcrService._();
  static final DrivingLicenseOcrService instance = DrivingLicenseOcrService._();

  Future<DrivingLicenseOcrResult> extractFromSides({
    required String frontImagePath,
    String? backImagePath,
  }) async {
    final front = await OcrService.instance.extractTextLines(frontImagePath);
    final back = backImagePath == null
        ? const <OcrTextLine>[]
        : await OcrService.instance.extractTextLines(backImagePath);
    final all = [...front, ...back];
    final mergedText = all.map((e) => e.text).join('\n');

    String byKeywords(List<String> keys) {
      for (final l in all) {
        final lower = l.text.toLowerCase();
        for (final key in keys) {
          if (!lower.contains(key.toLowerCase())) continue;
          final v = l.text
              .replaceAll(RegExp('(?i)$key'), '')
              .replaceAll(':', '')
              .trim();
          if (v.isNotEmpty) return _clean(v);
        }
      }
      return '';
    }

    String cnic() {
      final m = RegExp(r'\b\d{5}[-\s]?\d{7}[-\s]?\d\b').firstMatch(mergedText);
      if (m == null) return '';
      final digits = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length != 13) return m.group(0)!;
      return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
    }

    String licenseNo() {
      final byLabel = byKeywords(
          const ['license no', 'licence no', 'dl no', 'license number']);
      if (byLabel.isNotEmpty) return byLabel;
      final m = RegExp(r'\b[A-Z0-9\-]{6,20}\b', caseSensitive: false)
          .firstMatch(mergedText);
      return m?.group(0) ?? '';
    }

    List<String> dates() => RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b')
        .allMatches(mergedText)
        .map((m) => m.group(0) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    List<String> categories() {
      final set = <String>{};
      for (final m in RegExp(r'\b(?:A|B|C|D|E|LTV|HTV|MC|PSV|TR)\b',
              caseSensitive: false)
          .allMatches(mergedText)) {
        set.add((m.group(0) ?? '').toUpperCase());
      }
      return set.toList();
    }

    String blood() {
      final m = RegExp(r'\b(?:A|B|AB|O)[+-]\b', caseSensitive: false)
          .firstMatch(mergedText);
      return (m?.group(0) ?? '').toUpperCase();
    }

    String province() {
      final t = mergedText.toLowerCase();
      if (t.contains('punjab')) return 'Punjab';
      if (t.contains('sindh')) return 'Sindh';
      if (t.contains('kpk') || t.contains('khyber')) return 'KPK';
      if (t.contains('baloch')) return 'Balochistan';
      if (t.contains('islamabad')) return 'ICT';
      if (t.contains('gilgit')) return 'GB';
      return '';
    }

    String dlims() {
      final m = RegExp(r'\bDLIMS[:\s-]*([A-Z0-9\-]{4,})', caseSensitive: false)
          .firstMatch(mergedText);
      if (m != null) return m.group(1) ?? '';
      final m2 = RegExp(r'\b\d{10,16}\b').firstMatch(mergedText);
      return m2?.group(0) ?? '';
    }

    String licenseType() {
      final t = mergedText.toLowerCase();
      if (t.contains('learner')) return 'Learner';
      if (t.contains('full') || t.contains('permanent')) return 'Full';
      return '';
    }

    String pickName() {
      final v = byKeywords(const ['name', 'holder name']);
      if (v.isNotEmpty) return v;
      final cand = all
          .map((e) => e.text.trim())
          .where((t) => RegExp(r'^[A-Za-z\s]{4,}$').hasMatch(t))
          .where((t) => !t.toLowerCase().contains('father'))
          .toList();
      return cand.isEmpty ? '' : _clean(cand.first);
    }

    final ds = dates();
    final data = DrivingLicenseData(
      fullName: pickName(),
      fatherName: byKeywords(const ['father', 's/o', 'son of']),
      cnicNumber: cnic(),
      licenseNumber: licenseNo(),
      dateOfBirth: byKeywords(const ['birth', 'dob']).ifEmpty(ds.isNotEmpty ? ds[0] : ''),
      dateOfIssue: byKeywords(const ['issue']).ifEmpty(ds.length > 1 ? ds[1] : ''),
      dateOfExpiry: byKeywords(const ['expiry', 'valid till']).ifEmpty(ds.length > 2 ? ds[2] : ''),
      address: byKeywords(const ['address', 'addr']),
      vehicleCategories: categories(),
      bloodGroup: blood(),
      issuingAuthority:
          byKeywords(const ['issuing authority', 'rto', 'traffic police', 'licensing authority']),
      dlimsNumber: dlims(),
      province: province(),
      licenseType: licenseType(),
      rawFrontText: front.map((e) => e.text).join('\n'),
      rawBackText: back.map((e) => e.text).join('\n'),
    );

    return DrivingLicenseOcrResult(
      data: data,
      frontBoxes: front.map((e) => e.boundingBox).toList(),
      backBoxes: back.map((e) => e.boundingBox).toList(),
    );
  }

  String _clean(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

