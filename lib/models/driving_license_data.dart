class DrivingLicenseData {
  final String fullName;
  final String fatherName;
  final String cnicNumber;
  final String licenseNumber;
  final String dateOfBirth;
  final String dateOfIssue;
  final String dateOfExpiry;
  final String address;
  final List<String> vehicleCategories;
  final String bloodGroup;
  final String issuingAuthority;
  final String dlimsNumber;
  final String province;
  final String licenseType; // Learner / Full
  final String rawFrontText;
  final String rawBackText;

  const DrivingLicenseData({
    this.fullName = '',
    this.fatherName = '',
    this.cnicNumber = '',
    this.licenseNumber = '',
    this.dateOfBirth = '',
    this.dateOfIssue = '',
    this.dateOfExpiry = '',
    this.address = '',
    this.vehicleCategories = const [],
    this.bloodGroup = '',
    this.issuingAuthority = '',
    this.dlimsNumber = '',
    this.province = '',
    this.licenseType = '',
    this.rawFrontText = '',
    this.rawBackText = '',
  });

  DrivingLicenseData copyWith({
    String? fullName,
    String? fatherName,
    String? cnicNumber,
    String? licenseNumber,
    String? dateOfBirth,
    String? dateOfIssue,
    String? dateOfExpiry,
    String? address,
    List<String>? vehicleCategories,
    String? bloodGroup,
    String? issuingAuthority,
    String? dlimsNumber,
    String? province,
    String? licenseType,
    String? rawFrontText,
    String? rawBackText,
  }) {
    return DrivingLicenseData(
      fullName: fullName ?? this.fullName,
      fatherName: fatherName ?? this.fatherName,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfIssue: dateOfIssue ?? this.dateOfIssue,
      dateOfExpiry: dateOfExpiry ?? this.dateOfExpiry,
      address: address ?? this.address,
      vehicleCategories: vehicleCategories ?? this.vehicleCategories,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      dlimsNumber: dlimsNumber ?? this.dlimsNumber,
      province: province ?? this.province,
      licenseType: licenseType ?? this.licenseType,
      rawFrontText: rawFrontText ?? this.rawFrontText,
      rawBackText: rawBackText ?? this.rawBackText,
    );
  }

  bool get cnicValid => RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(cnicNumber.trim());

  bool get licenseNumberValid => RegExp(r'^[A-Z0-9\-]{6,20}$', caseSensitive: false)
      .hasMatch(licenseNumber.trim());

  bool get hasExpiry => dateOfExpiry.trim().isNotEmpty;

  bool get isExpired {
    final dt = _parseDate(dateOfExpiry);
    if (dt == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dt.isBefore(today);
  }

  bool get vehicleCategoriesValid {
    const allowed = {
      'A',
      'B',
      'C',
      'D',
      'E',
      'LTV',
      'HTV',
      'MC',
      'PSV',
      'TR',
    };
    if (vehicleCategories.isEmpty) return false;
    return vehicleCategories
        .map((e) => e.toUpperCase().trim())
        .every(allowed.contains);
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'full_name': fullName,
      'father_name': fatherName,
      'cnic_number': cnicNumber,
      'license_number': licenseNumber,
      'date_of_birth': dateOfBirth,
      'date_of_issue': dateOfIssue,
      'date_of_expiry': dateOfExpiry,
      'address': address,
      'vehicle_categories': vehicleCategories,
      'blood_group': bloodGroup,
      'issuing_authority': issuingAuthority,
      'dlims_number': dlimsNumber,
      'province': province,
      'license_type': licenseType,
      'cnic_valid': cnicValid,
      'license_number_valid': licenseNumberValid,
      'vehicle_categories_valid': vehicleCategoriesValid,
      'is_expired': isExpired,
      'raw_front_text': rawFrontText,
      'raw_back_text': rawBackText,
    };
  }

  static DateTime? _parseDate(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final m =
        RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})').firstMatch(t);
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

