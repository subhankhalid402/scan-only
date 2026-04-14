class AcademicCertificateData {
  final String holderName;
  final String fatherName;
  final String rollNumber;
  final String registrationNumber;
  final String degreeTitle;
  final String fieldOfStudy;
  final String instituteName;
  final String boardRecognition;
  final String qualificationLevel;
  final String yearOfPassing;
  final String gradeCgpaDivision;
  final String issueDate;
  final String signatureAreaHint;
  final String nadraAttestationMark;
  final String hecQrValue;
  final bool hecQrDetected;
  final bool hecVerified;
  final bool watermarkDetected;
  final List<String> fakeFlags;
  final String orientation;
  final String rawText;

  const AcademicCertificateData({
    this.holderName = '',
    this.fatherName = '',
    this.rollNumber = '',
    this.registrationNumber = '',
    this.degreeTitle = '',
    this.fieldOfStudy = '',
    this.instituteName = '',
    this.boardRecognition = '',
    this.qualificationLevel = '',
    this.yearOfPassing = '',
    this.gradeCgpaDivision = '',
    this.issueDate = '',
    this.signatureAreaHint = '',
    this.nadraAttestationMark = '',
    this.hecQrValue = '',
    this.hecQrDetected = false,
    this.hecVerified = false,
    this.watermarkDetected = false,
    this.fakeFlags = const [],
    this.orientation = '',
    this.rawText = '',
  });

  AcademicCertificateData copyWith({
    String? holderName,
    String? fatherName,
    String? rollNumber,
    String? registrationNumber,
    String? degreeTitle,
    String? fieldOfStudy,
    String? instituteName,
    String? boardRecognition,
    String? qualificationLevel,
    String? yearOfPassing,
    String? gradeCgpaDivision,
    String? issueDate,
    String? signatureAreaHint,
    String? nadraAttestationMark,
    String? hecQrValue,
    bool? hecQrDetected,
    bool? hecVerified,
    bool? watermarkDetected,
    List<String>? fakeFlags,
    String? orientation,
    String? rawText,
  }) {
    return AcademicCertificateData(
      holderName: holderName ?? this.holderName,
      fatherName: fatherName ?? this.fatherName,
      rollNumber: rollNumber ?? this.rollNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      degreeTitle: degreeTitle ?? this.degreeTitle,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      instituteName: instituteName ?? this.instituteName,
      boardRecognition: boardRecognition ?? this.boardRecognition,
      qualificationLevel: qualificationLevel ?? this.qualificationLevel,
      yearOfPassing: yearOfPassing ?? this.yearOfPassing,
      gradeCgpaDivision: gradeCgpaDivision ?? this.gradeCgpaDivision,
      issueDate: issueDate ?? this.issueDate,
      signatureAreaHint: signatureAreaHint ?? this.signatureAreaHint,
      nadraAttestationMark:
          nadraAttestationMark ?? this.nadraAttestationMark,
      hecQrValue: hecQrValue ?? this.hecQrValue,
      hecQrDetected: hecQrDetected ?? this.hecQrDetected,
      hecVerified: hecVerified ?? this.hecVerified,
      watermarkDetected: watermarkDetected ?? this.watermarkDetected,
      fakeFlags: fakeFlags ?? this.fakeFlags,
      orientation: orientation ?? this.orientation,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toJsonMap() => {
        'holder_name': holderName,
        'father_name': fatherName,
        'roll_number': rollNumber,
        'registration_number': registrationNumber,
        'degree_title': degreeTitle,
        'field_of_study': fieldOfStudy,
        'institute_name': instituteName,
        'board_recognition': boardRecognition,
        'qualification_level': qualificationLevel,
        'year_of_passing': yearOfPassing,
        'grade_cgpa_division': gradeCgpaDivision,
        'issue_date': issueDate,
        'signature_area_hint': signatureAreaHint,
        'nadra_attestation_mark': nadraAttestationMark,
        'hec_qr_value': hecQrValue,
        'hec_qr_detected': hecQrDetected,
        'hec_verified': hecVerified,
        'watermark_detected': watermarkDetected,
        'fake_flags': fakeFlags,
        'orientation': orientation,
        'raw_text': rawText,
      };
}

