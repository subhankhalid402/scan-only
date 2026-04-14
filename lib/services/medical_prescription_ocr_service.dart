import 'dart:ui' show Rect;

import '../models/medical_prescription_data.dart';
import 'handwriting_service.dart';
import 'ocr_service.dart';

class MedicalPrescriptionOcrResult {
  final MedicalPrescriptionData data;
  final List<Rect> textBoxes;

  const MedicalPrescriptionOcrResult({
    required this.data,
    required this.textBoxes,
  });
}

class MedicalPrescriptionOcrService {
  MedicalPrescriptionOcrService._();
  static final MedicalPrescriptionOcrService instance =
      MedicalPrescriptionOcrService._();

  static const Map<String, String> _genericMap = {
    'panadol': 'Paracetamol',
    'augmentin': 'Amoxicillin + Clavulanate',
    'brufen': 'Ibuprofen',
    'flagyl': 'Metronidazole',
    'calpol': 'Paracetamol',
    'risek': 'Omeprazole',
    'ponstan': 'Mefenamic Acid',
  };

  static const Set<String> _interactionPairA = {
    'ibuprofen',
    'diclofenac',
  };
  static const Set<String> _interactionPairB = {
    'warfarin',
    'aspirin',
  };

  Future<MedicalPrescriptionOcrResult> extractFromPages(
      List<String> imagePaths) async {
    final lines = <OcrTextLine>[];
    final htrTexts = <String>[];

    for (final p in imagePaths) {
      final l = await OcrService.instance.extractTextLines(p);
      lines.addAll(l);
      final htr = await HandwritingService.instance.recognizeHandwriting(p);
      if (htr.trim().isNotEmpty) htrTexts.add(htr.trim());
    }

    final raw = lines.map((e) => e.text).join('\n');
    final urdu = (await OcrService.instance.extractUrduText(imagePaths.first)).trim();
    final merged = '$raw\n${htrTexts.join('\n')}\n$urdu';

    String byKeywords(List<String> keys) {
      for (final l in lines) {
        final low = l.text.toLowerCase();
        for (final k in keys) {
          if (!low.contains(k.toLowerCase())) continue;
          final v =
              l.text.replaceAll(RegExp('(?i)$k'), '').replaceAll(':', '').trim();
          if (v.isNotEmpty) return _clean(v);
        }
      }
      return '';
    }

    String firstDate() {
      final m = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b')
          .firstMatch(merged);
      return m?.group(0) ?? '';
    }

    String phone() {
      final m = RegExp(r'(\+?\d[\d\-\s]{7,}\d)').firstMatch(merged);
      return m?.group(1)?.trim() ?? '';
    }

    String pmdc() {
      final m = RegExp(r'\bPMDC[:\s-]*([A-Z0-9\-]{4,})', caseSensitive: false)
          .firstMatch(merged);
      if (m != null) return m.group(1) ?? '';
      final m2 = RegExp(r'\b\d{5,10}\b').firstMatch(merged);
      return m2?.group(0) ?? '';
    }

    List<MedicineEntry> meds() {
      final out = <MedicineEntry>[];
      for (final l in lines) {
        final t = l.text.trim();
        if (t.length < 3) continue;
        if (!RegExp(r'[A-Za-z]').hasMatch(t)) continue;
        final low = t.toLowerCase();
        if (low.contains('diagnosis') ||
            low.contains('test') ||
            low.contains('follow') ||
            low.contains('patient')) {
          continue;
        }
        final dosage =
            RegExp(r'\b\d+\s?(?:mg|ml|g)\b', caseSensitive: false).firstMatch(t)?.group(0) ?? '';
        final freq = RegExp(r'\b\d-\d-\d\b|\bonce daily\b|\btwice daily\b|\bthrice daily\b',
                caseSensitive: false)
            .firstMatch(t)
            ?.group(0) ??
            '';
        final duration = RegExp(r'\b\d+\s?(?:day|days|week|weeks|month|months)\b',
                caseSensitive: false)
            .firstMatch(t)
            ?.group(0) ??
            '';
        final meal = RegExp(r'before meal|after meal|before food|after food',
                caseSensitive: false)
            .firstMatch(t)
            ?.group(0) ??
            '';
        final name =
            t.replaceAll(RegExp(r'\b\d+\s?(?:mg|ml|g)\b', caseSensitive: false), '').trim();
        if (name.isEmpty) continue;
        final generic = _genericMap[name.toLowerCase()] ?? '';
        out.add(MedicineEntry(
          name: _clean(name),
          dosage: dosage,
          frequency: freq,
          duration: duration,
          mealInstruction: meal,
          genericSuggestion: generic,
          availability: generic.isNotEmpty ? 'Likely available' : 'Check pharmacy',
        ));
      }
      return _applyInteractionWarnings(out);
    }

    List<String> tests() {
      final out = <String>[];
      for (final l in lines) {
        final low = l.text.toLowerCase();
        if (low.contains('cbc') ||
            low.contains('x-ray') ||
            low.contains('ultrasound') ||
            low.contains('lft') ||
            low.contains('kft') ||
            low.contains('blood test') ||
            low.contains('urine')) {
          out.add(_clean(l.text));
        }
      }
      return out.toSet().toList();
    }

    bool signatureDetected() {
      final low = merged.toLowerCase();
      return low.contains('signature') ||
          low.contains('dr.') ||
          RegExp(r'sig[:\s]', caseSensitive: false).hasMatch(low);
    }

    final pmdcNo = pmdc();
    final data = MedicalPrescriptionData(
      doctorName: byKeywords(const ['doctor', 'dr.', 'consultant']),
      qualification: byKeywords(const ['mbbs', 'fcps', 'md', 'ms']),
      clinicName: byKeywords(const ['clinic', 'hospital', 'medical center']),
      doctorContact: phone(),
      doctorAddress: byKeywords(const ['address', 'clinic address']),
      pmdcNumber: pmdcNo,
      pmdcValid: RegExp(r'^[A-Z0-9\-]{4,}$', caseSensitive: false)
          .hasMatch(pmdcNo.trim()),
      patientName: byKeywords(const ['patient', 'pt name', 'name']),
      patientAge: byKeywords(const ['age']),
      prescriptionDate: firstDate(),
      diagnosis: byKeywords(const ['diagnosis', 'symptom', 'complaint']),
      medicines: meds(),
      labTests: tests(),
      followUpDate: byKeywords(const ['follow up', 'review']),
      signatureDetected: signatureDetected(),
      rawText: raw,
      urduText: urdu,
    );

    return MedicalPrescriptionOcrResult(
      data: data,
      textBoxes: lines.map((e) => e.boundingBox).toList(),
    );
  }

  List<MedicineEntry> _applyInteractionWarnings(List<MedicineEntry> meds) {
    final names = meds.map((e) => e.name.toLowerCase()).toSet();
    final hasA = names.any((n) => _interactionPairA.any(n.contains));
    final hasB = names.any((n) => _interactionPairB.any(n.contains));
    if (!(hasA && hasB)) return meds;
    return meds
        .map((m) => m.copyWith(
              interactionWarning: _interactionPairA.any(m.name.toLowerCase().contains) ||
                  _interactionPairB.any(m.name.toLowerCase().contains),
            ))
        .toList();
  }

  String _clean(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

