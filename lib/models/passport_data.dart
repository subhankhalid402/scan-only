class PassportData {
  final String fullName;
  final String surname;
  final String givenNames;
  final String passportNumber;
  final String nationality;
  final String countryCode;
  final String dateOfBirth;
  final String gender;
  final String dateOfExpiry;
  final String dateOfIssue;
  final String placeOfBirth;
  final String issuingAuthority;
  final String personalNumber;
  final String fatherName;
  final String motherName;
  final String cnicNumber;
  final String nicNumber;
  final String oldPassportNumber;
  final String profession;
  final String religion;
  final String maritalStatus;
  final String mrzLine1;
  final String mrzLine2;
  final bool mrzChecksumValid;
  final bool mrzVisualCrossCheck;
  final String rawText;

  const PassportData({
    this.fullName = '',
    this.surname = '',
    this.givenNames = '',
    this.passportNumber = '',
    this.nationality = '',
    this.countryCode = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.dateOfExpiry = '',
    this.dateOfIssue = '',
    this.placeOfBirth = '',
    this.issuingAuthority = '',
    this.personalNumber = '',
    this.fatherName = '',
    this.motherName = '',
    this.cnicNumber = '',
    this.nicNumber = '',
    this.oldPassportNumber = '',
    this.profession = '',
    this.religion = '',
    this.maritalStatus = '',
    this.mrzLine1 = '',
    this.mrzLine2 = '',
    this.mrzChecksumValid = false,
    this.mrzVisualCrossCheck = false,
    this.rawText = '',
  });

  PassportData copyWith({
    String? fullName,
    String? surname,
    String? givenNames,
    String? passportNumber,
    String? nationality,
    String? countryCode,
    String? dateOfBirth,
    String? gender,
    String? dateOfExpiry,
    String? dateOfIssue,
    String? placeOfBirth,
    String? issuingAuthority,
    String? personalNumber,
    String? fatherName,
    String? motherName,
    String? cnicNumber,
    String? nicNumber,
    String? oldPassportNumber,
    String? profession,
    String? religion,
    String? maritalStatus,
    String? mrzLine1,
    String? mrzLine2,
    bool? mrzChecksumValid,
    bool? mrzVisualCrossCheck,
    String? rawText,
  }) {
    return PassportData(
      fullName: fullName ?? this.fullName,
      surname: surname ?? this.surname,
      givenNames: givenNames ?? this.givenNames,
      passportNumber: passportNumber ?? this.passportNumber,
      nationality: nationality ?? this.nationality,
      countryCode: countryCode ?? this.countryCode,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      dateOfExpiry: dateOfExpiry ?? this.dateOfExpiry,
      dateOfIssue: dateOfIssue ?? this.dateOfIssue,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      personalNumber: personalNumber ?? this.personalNumber,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      nicNumber: nicNumber ?? this.nicNumber,
      oldPassportNumber: oldPassportNumber ?? this.oldPassportNumber,
      profession: profession ?? this.profession,
      religion: religion ?? this.religion,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      mrzLine1: mrzLine1 ?? this.mrzLine1,
      mrzLine2: mrzLine2 ?? this.mrzLine2,
      mrzChecksumValid: mrzChecksumValid ?? this.mrzChecksumValid,
      mrzVisualCrossCheck: mrzVisualCrossCheck ?? this.mrzVisualCrossCheck,
      rawText: rawText ?? this.rawText,
    );
  }

  bool get hasExpiry => dateOfExpiry.trim().isNotEmpty;

  bool get isExpired {
    final dt = _parseDate(dateOfExpiry);
    if (dt == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dt.isBefore(today);
  }

  bool get passportNumberValid {
    final v = passportNumber.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[A-Z0-9]{6,10}$', caseSensitive: false).hasMatch(v);
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'full_name': fullName,
      'surname': surname,
      'given_names': givenNames,
      'passport_number': passportNumber,
      'nationality': nationality,
      'country_code': countryCode,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'date_of_expiry': dateOfExpiry,
      'date_of_issue': dateOfIssue,
      'place_of_birth': placeOfBirth,
      'issuing_authority': issuingAuthority,
      'personal_number': personalNumber,
      'father_name': fatherName,
      'mother_name': motherName,
      'cnic_number': cnicNumber,
      'nic_number': nicNumber,
      'old_passport_number': oldPassportNumber,
      'profession': profession,
      'religion': religion,
      'marital_status': maritalStatus,
      'mrz_line_1': mrzLine1,
      'mrz_line_2': mrzLine2,
      'mrz_checksum_valid': mrzChecksumValid,
      'mrz_visual_cross_check': mrzVisualCrossCheck,
      'passport_number_valid': passportNumberValid,
      'is_expired': isExpired,
      'raw_text': rawText,
    };
  }

  static DateTime? _parseDate(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})').firstMatch(t);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    var y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    if (y < 100) y += 2000;
    try {
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }
}

