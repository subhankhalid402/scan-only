class IdCardData {
  final String name;
  final String fatherName;
  final String cnicNumber;
  final String dateOfBirth;
  final String issueDate;
  final String expiryDate;
  final String address;
  final String gender;
  final String rawFrontText;
  final String rawBackText;

  const IdCardData({
    this.name = '',
    this.fatherName = '',
    this.cnicNumber = '',
    this.dateOfBirth = '',
    this.issueDate = '',
    this.expiryDate = '',
    this.address = '',
    this.gender = '',
    this.rawFrontText = '',
    this.rawBackText = '',
  });

  IdCardData copyWith({
    String? name,
    String? fatherName,
    String? cnicNumber,
    String? dateOfBirth,
    String? issueDate,
    String? expiryDate,
    String? address,
    String? gender,
    String? rawFrontText,
    String? rawBackText,
  }) {
    return IdCardData(
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      rawFrontText: rawFrontText ?? this.rawFrontText,
      rawBackText: rawBackText ?? this.rawBackText,
    );
  }

  bool get isCnicValid =>
      RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(cnicNumber.trim());

  bool get hasExpiry => expiryDate.trim().isNotEmpty;

  bool get isExpired {
    final dt = _parseLooseDate(expiryDate);
    if (dt == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dt.isBefore(today);
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'name': name,
      'father_name': fatherName,
      'cnic_number': cnicNumber,
      'date_of_birth': dateOfBirth,
      'date_of_issue': issueDate,
      'date_of_expiry': expiryDate,
      'address': address,
      'gender': gender,
      'cnic_valid': isCnicValid,
      'is_expired': isExpired,
      'raw_front_text': rawFrontText,
      'raw_back_text': rawBackText,
    };
  }

  static DateTime? _parseLooseDate(String input) {
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

