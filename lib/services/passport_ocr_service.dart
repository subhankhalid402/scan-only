import 'dart:ui' show Rect;

import '../models/passport_data.dart';
import 'ocr_service.dart';

class PassportOcrResult {
  final PassportData data;
  final List<Rect> textBoxes;
  final Rect? mrzRect;
  final Rect? photoRect;

  const PassportOcrResult({
    required this.data,
    required this.textBoxes,
    required this.mrzRect,
    required this.photoRect,
  });
}

class PassportOcrService {
  PassportOcrService._();
  static final PassportOcrService instance = PassportOcrService._();

  Future<PassportOcrResult> extract(String imagePath) async {
    final lines = await OcrService.instance.extractTextLines(imagePath);
    final text = lines.map((e) => e.text).join('\n');
    String byLabel(List<String> labels) {
      for (final l in lines) {
        final lower = l.text.toLowerCase();
        for (final label in labels) {
          if (!lower.contains(label.toLowerCase())) continue;
          final val = l.text
              .replaceAll(RegExp('(?i)$label'), '')
              .replaceAll(':', '')
              .trim();
          if (val.isNotEmpty) return _clean(val);
        }
      }
      return '';
    }

    List<String> dateHits() {
      final out = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b')
          .allMatches(text)
          .map((m) => m.group(0) ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      return out;
    }

    final mrz = _extractMrz(lines);
    final mrzInfo = _parseMrz(mrz.$1, mrz.$2);
    final visualPassport = byLabel(const ['passport no', 'passport number', 'passport']);
    final finalPassportNumber =
        visualPassport.isNotEmpty ? visualPassport : mrzInfo.passportNumber;
    final visualName = byLabel(const ['name', 'surname', 'given name', 'given names']);
    final fullName = visualName.isNotEmpty ? visualName : mrzInfo.fullName;
    final dates = dateHits();

    final data = PassportData(
      fullName: fullName,
      surname: byLabel(const ['surname']).ifEmpty(mrzInfo.surname),
      givenNames: byLabel(const ['given name', 'given names']).ifEmpty(mrzInfo.givenNames),
      passportNumber: finalPassportNumber,
      nationality: byLabel(const ['nationality']).ifEmpty(mrzInfo.nationality),
      countryCode: byLabel(const ['country code']).ifEmpty(mrzInfo.countryCode),
      dateOfBirth: byLabel(const ['date of birth', 'birth']).ifEmpty(mrzInfo.dateOfBirth),
      gender: byLabel(const ['sex', 'gender']).ifEmpty(mrzInfo.gender),
      dateOfExpiry: byLabel(const ['date of expiry', 'expiry']).ifEmpty(mrzInfo.dateOfExpiry),
      dateOfIssue: byLabel(const ['date of issue', 'issue']),
      placeOfBirth: byLabel(const ['place of birth']),
      issuingAuthority: byLabel(const ['authority', 'issuing authority']),
      personalNumber: mrzInfo.personalNumber,
      fatherName: byLabel(const ['father', 'father name', 's/o']),
      motherName: byLabel(const ['mother', 'mother name']),
      cnicNumber: _extractCnic(text),
      nicNumber: byLabel(const ['nic', 'nic number']),
      oldPassportNumber: byLabel(const ['old passport']),
      profession: byLabel(const ['profession', 'occupation']),
      religion: byLabel(const ['religion']),
      maritalStatus: byLabel(const ['marital status']),
      mrzLine1: mrz.$1,
      mrzLine2: mrz.$2,
      mrzChecksumValid: mrzInfo.checksumValid,
      mrzVisualCrossCheck: _crossCheck(
        mrzPassport: mrzInfo.passportNumber,
        visualPassport: finalPassportNumber,
        mrzName: mrzInfo.fullName,
        visualName: fullName,
      ),
      rawText: text,
    ).copyWith(
      dateOfBirth: byLabel(const ['date of birth', 'birth']).ifEmpty(
        mrzInfo.dateOfBirth.ifEmpty(dates.isNotEmpty ? dates[0] : ''),
      ),
      dateOfIssue: byLabel(const ['date of issue', 'issue']).ifEmpty(
        dates.length > 1 ? dates[1] : '',
      ),
      dateOfExpiry: byLabel(const ['date of expiry', 'expiry']).ifEmpty(
        mrzInfo.dateOfExpiry.ifEmpty(dates.length > 2 ? dates[2] : ''),
      ),
    );

    final mrzRect = _mrzRect(lines);
    final photoRect = _photoRect(lines, mrzRect);

    return PassportOcrResult(
      data: data,
      textBoxes: lines.map((e) => e.boundingBox).toList(),
      mrzRect: mrzRect,
      photoRect: photoRect,
    );
  }

  (String, String) _extractMrz(List<OcrTextLine> lines) {
    final candidates = lines
        .map((e) => e.text.replaceAll(' ', '').toUpperCase())
        .where((t) => t.contains('<') && t.length >= 25)
        .toList();
    if (candidates.length >= 2) {
      return (candidates[candidates.length - 2], candidates.last);
    }
    if (candidates.length == 1) {
      final one = candidates.first;
      if (one.length >= 80) {
        return (one.substring(0, 44), one.substring(44, 88));
      }
    }
    return ('', '');
  }

  _MrzInfo _parseMrz(String l1, String l2) {
    if (l1.length < 40 || l2.length < 40) return const _MrzInfo();
    final line1 = l1.padRight(44, '<').substring(0, 44);
    final line2 = l2.padRight(44, '<').substring(0, 44);
    final country = line1.substring(2, 5).replaceAll('<', '');
    final names = line1.substring(5).split('<<');
    final surname = names.isNotEmpty ? names.first.replaceAll('<', ' ').trim() : '';
    final given = names.length > 1 ? names[1].replaceAll('<', ' ').trim() : '';
    final passportNum = line2.substring(0, 9).replaceAll('<', '');
    final passportCheck = line2.substring(9, 10);
    final nationality = line2.substring(10, 13).replaceAll('<', '');
    final dobRaw = line2.substring(13, 19);
    final dobCheck = line2.substring(19, 20);
    final gender = line2.substring(20, 21).replaceAll('<', '');
    final expRaw = line2.substring(21, 27);
    final expCheck = line2.substring(27, 28);
    final personal = line2.substring(28, 42).replaceAll('<', '');
    final personalCheck = line2.substring(42, 43);

    final c1 = _checksum(passportNum.padRight(9, '<')) == _charToInt(passportCheck);
    final c2 = _checksum(dobRaw) == _charToInt(dobCheck);
    final c3 = _checksum(expRaw) == _charToInt(expCheck);
    final c4 = _checksum(line2.substring(28, 42)) == _charToInt(personalCheck);

    return _MrzInfo(
      surname: surname,
      givenNames: given,
      fullName: _clean('$surname $given'),
      passportNumber: passportNum,
      nationality: nationality,
      countryCode: country,
      dateOfBirth: _yyMMddToDisplay(dobRaw),
      gender: gender == 'M' ? 'Male' : (gender == 'F' ? 'Female' : gender),
      dateOfExpiry: _yyMMddToDisplay(expRaw),
      personalNumber: personal,
      checksumValid: c1 && c2 && c3 && c4,
    );
  }

  Rect? _mrzRect(List<OcrTextLine> lines) {
    Rect? best;
    for (final l in lines) {
      final t = l.text.replaceAll(' ', '');
      if (!t.contains('<')) continue;
      best = best == null ? l.boundingBox : best.expandToInclude(l.boundingBox);
    }
    return best;
  }

  Rect? _photoRect(List<OcrTextLine> lines, Rect? mrz) {
    if (lines.isEmpty) return null;
    Rect bounds = lines.first.boundingBox;
    for (final l in lines.skip(1)) {
      bounds = bounds.expandToInclude(l.boundingBox);
    }
    final h = bounds.height;
    final photo = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width * 0.36,
      h * 0.55,
    );
    if (mrz != null && photo.bottom > mrz.top) {
      return Rect.fromLTWH(photo.left, photo.top, photo.width, (mrz.top - photo.top).clamp(10, photo.height));
    }
    return photo;
  }

  bool _crossCheck({
    required String mrzPassport,
    required String visualPassport,
    required String mrzName,
    required String visualName,
  }) {
    final p1 = mrzPassport.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final p2 = visualPassport.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final n1 = mrzName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final n2 = visualName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final passportOk = p1.isEmpty || p2.isEmpty || p1 == p2;
    final nameOk = n1.isEmpty || n2.isEmpty || n2.contains(n1) || n1.contains(n2);
    return passportOk && nameOk;
  }

  String _yyMMddToDisplay(String yymmdd) {
    if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return '';
    final yy = int.parse(yymmdd.substring(0, 2));
    final mm = yymmdd.substring(2, 4);
    final dd = yymmdd.substring(4, 6);
    final year = yy > 40 ? 1900 + yy : 2000 + yy;
    return '$dd/$mm/$year';
  }

  int _checksum(String value) {
    const weights = [7, 3, 1];
    var sum = 0;
    for (var i = 0; i < value.length; i++) {
      sum += _charValue(value[i]) * weights[i % 3];
    }
    return sum % 10;
  }

  int _charValue(String ch) {
    if (ch == '<') return 0;
    final code = ch.codeUnitAt(0);
    if (code >= 48 && code <= 57) return code - 48;
    if (code >= 65 && code <= 90) return code - 55;
    return 0;
  }

  int _charToInt(String ch) => int.tryParse(ch) ?? 0;

  String _extractCnic(String text) {
    final m = RegExp(r'\b\d{5}[-\s]?\d{7}[-\s]?\d\b').firstMatch(text);
    if (m == null) return '';
    final digits = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 13) return m.group(0)!;
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
  }

  String _clean(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _MrzInfo {
  final String surname;
  final String givenNames;
  final String fullName;
  final String passportNumber;
  final String nationality;
  final String countryCode;
  final String dateOfBirth;
  final String gender;
  final String dateOfExpiry;
  final String personalNumber;
  final bool checksumValid;

  const _MrzInfo({
    this.surname = '',
    this.givenNames = '',
    this.fullName = '',
    this.passportNumber = '',
    this.nationality = '',
    this.countryCode = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.dateOfExpiry = '',
    this.personalNumber = '',
    this.checksumValid = false,
  });
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

