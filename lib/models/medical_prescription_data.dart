class MedicineEntry {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String mealInstruction;
  final String genericSuggestion;
  final bool interactionWarning;
  final String availability;

  const MedicineEntry({
    this.name = '',
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.mealInstruction = '',
    this.genericSuggestion = '',
    this.interactionWarning = false,
    this.availability = '',
  });

  MedicineEntry copyWith({
    String? name,
    String? dosage,
    String? frequency,
    String? duration,
    String? mealInstruction,
    String? genericSuggestion,
    bool? interactionWarning,
    String? availability,
  }) {
    return MedicineEntry(
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      mealInstruction: mealInstruction ?? this.mealInstruction,
      genericSuggestion: genericSuggestion ?? this.genericSuggestion,
      interactionWarning: interactionWarning ?? this.interactionWarning,
      availability: availability ?? this.availability,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'meal_instruction': mealInstruction,
        'generic_suggestion': genericSuggestion,
        'interaction_warning': interactionWarning,
        'availability': availability,
      };
}

class MedicalPrescriptionData {
  final String doctorName;
  final String qualification;
  final String clinicName;
  final String doctorContact;
  final String doctorAddress;
  final String pmdcNumber;
  final String patientName;
  final String patientAge;
  final String prescriptionDate;
  final String diagnosis;
  final List<MedicineEntry> medicines;
  final List<String> labTests;
  final String followUpDate;
  final bool signatureDetected;
  final bool pmdcValid;
  final String rawText;
  final String urduText;

  const MedicalPrescriptionData({
    this.doctorName = '',
    this.qualification = '',
    this.clinicName = '',
    this.doctorContact = '',
    this.doctorAddress = '',
    this.pmdcNumber = '',
    this.patientName = '',
    this.patientAge = '',
    this.prescriptionDate = '',
    this.diagnosis = '',
    this.medicines = const [],
    this.labTests = const [],
    this.followUpDate = '',
    this.signatureDetected = false,
    this.pmdcValid = false,
    this.rawText = '',
    this.urduText = '',
  });

  MedicalPrescriptionData copyWith({
    String? doctorName,
    String? qualification,
    String? clinicName,
    String? doctorContact,
    String? doctorAddress,
    String? pmdcNumber,
    String? patientName,
    String? patientAge,
    String? prescriptionDate,
    String? diagnosis,
    List<MedicineEntry>? medicines,
    List<String>? labTests,
    String? followUpDate,
    bool? signatureDetected,
    bool? pmdcValid,
    String? rawText,
    String? urduText,
  }) {
    return MedicalPrescriptionData(
      doctorName: doctorName ?? this.doctorName,
      qualification: qualification ?? this.qualification,
      clinicName: clinicName ?? this.clinicName,
      doctorContact: doctorContact ?? this.doctorContact,
      doctorAddress: doctorAddress ?? this.doctorAddress,
      pmdcNumber: pmdcNumber ?? this.pmdcNumber,
      patientName: patientName ?? this.patientName,
      patientAge: patientAge ?? this.patientAge,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      diagnosis: diagnosis ?? this.diagnosis,
      medicines: medicines ?? this.medicines,
      labTests: labTests ?? this.labTests,
      followUpDate: followUpDate ?? this.followUpDate,
      signatureDetected: signatureDetected ?? this.signatureDetected,
      pmdcValid: pmdcValid ?? this.pmdcValid,
      rawText: rawText ?? this.rawText,
      urduText: urduText ?? this.urduText,
    );
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'doctor_name': doctorName,
      'qualification': qualification,
      'clinic_name': clinicName,
      'doctor_contact': doctorContact,
      'doctor_address': doctorAddress,
      'pmdc_number': pmdcNumber,
      'pmdc_valid': pmdcValid,
      'patient_name': patientName,
      'patient_age': patientAge,
      'prescription_date': prescriptionDate,
      'diagnosis': diagnosis,
      'medicines': medicines.map((e) => e.toMap()).toList(),
      'lab_tests': labTests,
      'follow_up_date': followUpDate,
      'signature_detected': signatureDetected,
      'raw_text': rawText,
      'urdu_text': urduText,
    };
  }
}

