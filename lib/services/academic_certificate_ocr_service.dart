import '../models/academic_certificate_data.dart';
import 'advanced_barcode_service.dart';
import 'ocr_service.dart';

class AcademicCertificateOcrService {
  AcademicCertificateOcrService._();
  static final AcademicCertificateOcrService instance =
      AcademicCertificateOcrService._();

  Future<AcademicCertificateData> extractFromPages(List<String> imagePaths) async {
    final allText = <String>[];
    for (final p in imagePaths) {
      final t = await OcrService.instance.extractText(p);
      if (t.trim().isNotEmpty) allText.add(t.trim());
    }
    final merged = allText.join('\n');
    final lines = merged.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final upper = merged.toUpperCase();

    String byKeywords(List<String> keys) {
      for (final line in lines) {
        final low = line.toLowerCase();
        for (final k in keys) {
          if (!low.contains(k.toLowerCase())) continue;
          final v = line.replaceAll(RegExp('(?i)$k'), '').replaceAll(':', '').trim();
          if (v.isNotEmpty) return _clean(v);
        }
      }
      return '';
    }

    String firstMatching(RegExp reg) => reg.firstMatch(merged)?.group(0) ?? '';

    String inferInstitute() {
      final known = [
        'university',
        'institute',
        'college',
        'board',
        'hec',
        'fbise',
        'punjab board',
        'sindh board',
      ];
      for (final line in lines) {
        final l = line.toLowerCase();
        if (known.any(l.contains)) return _clean(line);
      }
      return '';
    }

    String qualLevel() {
      final t = merged.toLowerCase();
      if (t.contains('matric')) return 'Matric';
      if (t.contains('intermediate') || t.contains('hssc') || t.contains('fsc')) {
        return 'Intermediate';
      }
      if (t.contains('bachelor') || t.contains('bs ') || t.contains('b.sc')) {
        return 'Bachelor';
      }
      if (t.contains('master') || t.contains('m.sc') || t.contains('ms ')) {
        return 'Master';
      }
      if (t.contains('phd')) return 'PhD';
      return '';
    }

    String boardRec() {
      final t = merged.toLowerCase();
      if (t.contains('fbise')) return 'FBISE';
      if (t.contains('punjab board')) return 'Punjab Board';
      if (t.contains('sindh board')) return 'Sindh Board';
      if (t.contains('bise')) return 'BISE';
      if (t.contains('hec')) return 'HEC Recognized';
      return '';
    }

    String degreeTitle() {
      final l = byKeywords(const ['degree', 'certificate', 'title']);
      if (l.isNotEmpty) return l;
      for (final line in lines) {
        final low = line.toLowerCase();
        if (low.contains('certificate') || low.contains('degree')) return _clean(line);
      }
      return '';
    }

    String holderName() {
      final l = byKeywords(const ['name', 'student name', 'holder name']);
      if (l.isNotEmpty) return l;
      final cands = lines
          .where((e) => RegExp(r'^[A-Za-z\s]{6,}$').hasMatch(e))
          .where((e) => !e.toLowerCase().contains('father'))
          .take(3)
          .toList();
      return cands.isEmpty ? '' : _clean(cands.first);
    }

    String orientation() {
      // Heuristic from layout keywords
      if (upper.contains('TRANSCRIPT') || upper.contains('STATEMENT OF MARKS')) {
        return 'portrait';
      }
      return 'landscape_or_portrait';
    }

    String dateValue() =>
        firstMatching(RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b'));

    String grade() {
      final cgpa = firstMatching(RegExp(r'\bCGPA[:\s]*\d(?:\.\d{1,2})?\b', caseSensitive: false));
      if (cgpa.isNotEmpty) return cgpa;
      final div = firstMatching(RegExp(r'\b(?:1st|2nd|3rd)\s+Division\b', caseSensitive: false));
      if (div.isNotEmpty) return div;
      return byKeywords(const ['grade', 'marks', 'division']);
    }

    String yearPass() => firstMatching(RegExp(r'\b(19|20)\d{2}\b'));

    String rollNo() => byKeywords(const ['roll no', 'roll number']).ifEmpty(
          firstMatching(RegExp(r'\b\d{4,12}\b')),
        );

    String regNo() =>
        byKeywords(const ['registration no', 'reg no', 'registration number']);

    String major() => byKeywords(const ['major', 'field', 'discipline', 'program']);

    String signatureArea() {
      for (final line in lines) {
        final low = line.toLowerCase();
        if (low.contains('registrar') ||
            low.contains('controller') ||
            low.contains('signature')) {
          return _clean(line);
        }
      }
      return '';
    }

    String nadraMark() {
      final t = merged.toLowerCase();
      if (t.contains('nadra')) return 'NADRA mark detected';
      return '';
    }

    bool watermarkDetected() {
      final t = merged.toLowerCase();
      return t.contains('watermark') ||
          t.contains('security') ||
          t.contains('hologram');
    }

    String hecQr = '';
    var hecQrDetected = false;
    if (imagePaths.isNotEmpty) {
      final barcodes =
          await AdvancedBarcodeService.instance.scanBarcodes(imagePaths.first);
      final qr = barcodes.map((e) => e.rawValue ?? '').firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );
      if (qr.isNotEmpty) {
        hecQr = qr;
        hecQrDetected = true;
      }
    }

    final fakeFlags = <String>[];
    if (!hecQrDetected && boardRec().isEmpty) {
      fakeFlags.add('No board/HEC authenticity marker detected');
    }
    if (holderName().isEmpty || degreeTitle().isEmpty || inferInstitute().isEmpty) {
      fakeFlags.add('Core degree fields are incomplete');
    }
    if (!watermarkDetected()) {
      fakeFlags.add('No security watermark/hologram clue detected');
    }

    return AcademicCertificateData(
      holderName: holderName(),
      fatherName: byKeywords(const ['father', 's/o', 'son of']),
      rollNumber: rollNo(),
      registrationNumber: regNo(),
      degreeTitle: degreeTitle(),
      fieldOfStudy: major(),
      instituteName: inferInstitute(),
      boardRecognition: boardRec(),
      qualificationLevel: qualLevel(),
      yearOfPassing: yearPass(),
      gradeCgpaDivision: grade(),
      issueDate: dateValue(),
      signatureAreaHint: signatureArea(),
      nadraAttestationMark: nadraMark(),
      hecQrValue: hecQr,
      hecQrDetected: hecQrDetected,
      hecVerified: hecQrDetected || upper.contains('HEC'),
      watermarkDetected: watermarkDetected(),
      fakeFlags: fakeFlags,
      orientation: orientation(),
      rawText: merged,
    );
  }

  String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension on String {
  String ifEmpty(String alt) => trim().isEmpty ? alt : this;
}

