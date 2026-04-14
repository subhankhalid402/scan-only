import 'dart:ui' show Rect;

import '../models/vehicle_rc_data.dart';
import 'ocr_service.dart';

class VehicleRcOcrResult {
  final VehicleRcData data;
  final List<Rect> textBoxes;
  final bool isMultiPageBook;

  const VehicleRcOcrResult({
    required this.data,
    required this.textBoxes,
    required this.isMultiPageBook,
  });
}

class VehicleRcOcrService {
  VehicleRcOcrService._();
  static final VehicleRcOcrService instance = VehicleRcOcrService._();

  Future<VehicleRcOcrResult> extractFromPages(List<String> imagePaths) async {
    final allLines = <OcrTextLine>[];
    for (final p in imagePaths) {
      final lines = await OcrService.instance.extractTextLines(p);
      allLines.addAll(lines);
    }
    final merged = allLines.map((e) => e.text).join('\n');

    String byKeywords(List<String> keys) {
      for (final l in allLines) {
        final low = l.text.toLowerCase();
        for (final k in keys) {
          if (!low.contains(k.toLowerCase())) continue;
          final v = l.text
              .replaceAll(RegExp('(?i)$k'), '')
              .replaceAll(':', '')
              .trim();
          if (v.isNotEmpty) return _clean(v);
        }
      }
      return '';
    }

    String regNo() {
      final fromLabel =
          byKeywords(const ['registration no', 'reg no', 'registration']);
      if (fromLabel.isNotEmpty) return fromLabel;
      final m = RegExp(r'\b[A-Z]{1,3}[-\s]?\d{1,4}[A-Z]?\b', caseSensitive: false)
          .firstMatch(merged);
      return m?.group(0) ?? '';
    }

    String cnic() {
      final m = RegExp(r'\b\d{5}[-\s]?\d{7}[-\s]?\d\b').firstMatch(merged);
      if (m == null) return '';
      final digits = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length != 13) return m.group(0)!;
      return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
    }

    String dateByLabel(List<String> labels) {
      final line = byKeywords(labels);
      if (line.isNotEmpty) {
        final m = RegExp(r'\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}').firstMatch(line);
        if (m != null) return m.group(0) ?? '';
      }
      final all = RegExp(r'\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}')
          .allMatches(merged)
          .map((e) => e.group(0) ?? '')
          .toList();
      return all.isNotEmpty ? all.first : '';
    }

    String province() {
      final t = merged.toLowerCase();
      if (t.contains('islamabad')) return 'Islamabad';
      if (t.contains('punjab')) return 'Punjab';
      if (t.contains('sindh')) return 'Sindh';
      if (t.contains('kpk') || t.contains('khyber')) return 'KPK';
      if (t.contains('baloch')) return 'Balochistan';
      if (t.contains('gilgit')) return 'GB';
      return '';
    }

    String ownershipHistory() {
      final lines = allLines
          .map((e) => e.text.trim())
          .where((e) =>
              e.toLowerCase().contains('transfer') ||
              e.toLowerCase().contains('owner') ||
              e.toLowerCase().contains('history'))
          .take(6)
          .toList();
      return lines.join(' | ');
    }

    final format = merged.toLowerCase().contains('book') || imagePaths.length > 1
        ? 'rc_book'
        : 'rc_card';

    final data = VehicleRcData(
      registrationNumber: regNo(),
      ownerName: byKeywords(const ['owner', 'registered owner', 'name']),
      ownerAddress: byKeywords(const ['address', 'owner address']),
      fatherName: byKeywords(const ['father', 's/o']),
      cnicNumber: cnic(),
      engineNumber: byKeywords(const ['engine no', 'engine number']),
      chassisNumber: byKeywords(const ['chassis no', 'chassis number']),
      makeModel: byKeywords(const ['make', 'model', 'make/model']),
      manufacturingYear: byKeywords(const ['year', 'manufacturing year']),
      color: byKeywords(const ['color', 'colour']),
      fuelType: byKeywords(const ['fuel', 'fuel type']),
      seatingCapacity: byKeywords(const ['seat', 'seating']),
      tokenTaxStatus: byKeywords(const ['token tax status', 'token status', 'token']),
      tokenTaxDueDate: dateByLabel(const ['token due', 'tax due', 'token tax due']),
      fitnessExpiry: dateByLabel(const ['fitness', 'fitness expiry', 'fitness valid']),
      routePermit: byKeywords(const ['route permit', 'permit']),
      exciseTaxationNumber:
          byKeywords(const ['excise', 'excise & taxation', 'e&t']),
      provinceCity: province().ifEmpty(
        byKeywords(const ['city', 'province', 'registration city']),
      ),
      ownershipHistory: ownershipHistory(),
      documentFormat: format,
      rawText: merged,
    );

    return VehicleRcOcrResult(
      data: data,
      textBoxes: allLines.map((e) => e.boundingBox).toList(),
      isMultiPageBook: imagePaths.length > 1,
    );
  }

  String _clean(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

