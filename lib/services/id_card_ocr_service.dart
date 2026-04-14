import 'dart:ui' show Rect;

import '../models/id_card_data.dart';
import 'ocr_service.dart';

class IdCardOcrResult {
  final IdCardData data;
  final List<Rect> frontBoxes;
  final List<Rect> backBoxes;
  final String frontText;
  final String backText;

  const IdCardOcrResult({
    required this.data,
    required this.frontBoxes,
    required this.backBoxes,
    required this.frontText,
    required this.backText,
  });
}

class IdCardOcrService {
  IdCardOcrService._();
  static final IdCardOcrService instance = IdCardOcrService._();

  Future<IdCardOcrResult> extractFromCardSides({
    required String frontImagePath,
    String? backImagePath,
  }) async {
    final frontLines = await OcrService.instance.extractTextLines(frontImagePath);
    final backLines = backImagePath == null
        ? const <OcrTextLine>[]
        : await OcrService.instance.extractTextLines(backImagePath);

    final frontText = frontLines.map((e) => e.text).join('\n');
    final backText = backLines.map((e) => e.text).join('\n');
    final mergedLines = [...frontLines, ...backLines];
    final mergedText = '$frontText\n$backText';

    String pickByKeywords(List<String> keywords) {
      for (final l in mergedLines) {
        final t = l.text.trim();
        final lower = t.toLowerCase();
        for (final kw in keywords) {
          if (!lower.contains(kw)) continue;
          final value = t
              .replaceAll(RegExp('(?i)$kw'), '')
              .replaceAll(':', '')
              .trim();
          if (value.isNotEmpty && value.length > 1) return value;
        }
      }
      return '';
    }

    String pickName() {
      var name = pickByKeywords(const ['name', 'name of holder']);
      if (name.isNotEmpty) return _cleanValue(name);
      final candidates = mergedLines
          .map((e) => e.text.trim())
          .where((t) => RegExp(r'^[A-Za-z\s]{4,}$').hasMatch(t))
          .where((t) => !t.toLowerCase().contains('father'))
          .toList();
      return candidates.isEmpty ? '' : _cleanValue(candidates.first);
    }

    String pickCnic() {
      final cnic = RegExp(r'\b\d{5}[-\s]?\d{7}[-\s]?\d\b').firstMatch(mergedText);
      if (cnic == null) return '';
      final raw = cnic.group(0)!.replaceAll(' ', '-');
      final digits = raw.replaceAll('-', '');
      if (digits.length == 13) {
        return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
      }
      return raw;
    }

    List<String> pickDates() {
      final matches = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b')
          .allMatches(mergedText)
          .map((m) => m.group(0) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return matches.toSet().toList();
    }

    String pickGender() {
      for (final l in mergedLines) {
        final t = l.text.toLowerCase();
        if (t.contains('female') || t.contains('f')) return 'Female';
        if (t.contains('male') || t.contains('m')) return 'Male';
      }
      return '';
    }

    final dates = pickDates();
    final dobByLabel = pickByKeywords(const ['birth', 'dob']);
    final issueByLabel = pickByKeywords(const ['issue']);
    final expiryByLabel = pickByKeywords(const ['expiry', 'expire', 'valid']);
    final addr = _cleanValue(
      pickByKeywords(const ['address', 'addr']),
    );

    final result = IdCardData(
      name: pickName(),
      fatherName: _cleanValue(
        pickByKeywords(const ['father', 's/o', 'son of']),
      ),
      cnicNumber: pickCnic(),
      dateOfBirth: dobByLabel.isNotEmpty ? dobByLabel : (dates.isNotEmpty ? dates[0] : ''),
      issueDate: issueByLabel.isNotEmpty ? issueByLabel : (dates.length > 1 ? dates[1] : ''),
      expiryDate: expiryByLabel.isNotEmpty ? expiryByLabel : (dates.length > 2 ? dates[2] : ''),
      address: addr,
      gender: pickGender(),
      rawFrontText: frontText,
      rawBackText: backText,
    );

    return IdCardOcrResult(
      data: result,
      frontBoxes: frontLines.map((e) => e.boundingBox).toList(),
      backBoxes: backLines.map((e) => e.boundingBox).toList(),
      frontText: frontText,
      backText: backText,
    );
  }

  String _cleanValue(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

