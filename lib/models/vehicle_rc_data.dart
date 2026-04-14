class VehicleRcData {
  final String registrationNumber;
  final String ownerName;
  final String ownerAddress;
  final String fatherName;
  final String cnicNumber;
  final String engineNumber;
  final String chassisNumber;
  final String makeModel;
  final String manufacturingYear;
  final String color;
  final String fuelType;
  final String seatingCapacity;
  final String tokenTaxStatus;
  final String tokenTaxDueDate;
  final String fitnessExpiry;
  final String routePermit;
  final String exciseTaxationNumber;
  final String provinceCity;
  final String ownershipHistory;
  final String documentFormat; // rc_book | rc_card
  final String rawText;

  const VehicleRcData({
    this.registrationNumber = '',
    this.ownerName = '',
    this.ownerAddress = '',
    this.fatherName = '',
    this.cnicNumber = '',
    this.engineNumber = '',
    this.chassisNumber = '',
    this.makeModel = '',
    this.manufacturingYear = '',
    this.color = '',
    this.fuelType = '',
    this.seatingCapacity = '',
    this.tokenTaxStatus = '',
    this.tokenTaxDueDate = '',
    this.fitnessExpiry = '',
    this.routePermit = '',
    this.exciseTaxationNumber = '',
    this.provinceCity = '',
    this.ownershipHistory = '',
    this.documentFormat = '',
    this.rawText = '',
  });

  VehicleRcData copyWith({
    String? registrationNumber,
    String? ownerName,
    String? ownerAddress,
    String? fatherName,
    String? cnicNumber,
    String? engineNumber,
    String? chassisNumber,
    String? makeModel,
    String? manufacturingYear,
    String? color,
    String? fuelType,
    String? seatingCapacity,
    String? tokenTaxStatus,
    String? tokenTaxDueDate,
    String? fitnessExpiry,
    String? routePermit,
    String? exciseTaxationNumber,
    String? provinceCity,
    String? ownershipHistory,
    String? documentFormat,
    String? rawText,
  }) {
    return VehicleRcData(
      registrationNumber: registrationNumber ?? this.registrationNumber,
      ownerName: ownerName ?? this.ownerName,
      ownerAddress: ownerAddress ?? this.ownerAddress,
      fatherName: fatherName ?? this.fatherName,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      engineNumber: engineNumber ?? this.engineNumber,
      chassisNumber: chassisNumber ?? this.chassisNumber,
      makeModel: makeModel ?? this.makeModel,
      manufacturingYear: manufacturingYear ?? this.manufacturingYear,
      color: color ?? this.color,
      fuelType: fuelType ?? this.fuelType,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      tokenTaxStatus: tokenTaxStatus ?? this.tokenTaxStatus,
      tokenTaxDueDate: tokenTaxDueDate ?? this.tokenTaxDueDate,
      fitnessExpiry: fitnessExpiry ?? this.fitnessExpiry,
      routePermit: routePermit ?? this.routePermit,
      exciseTaxationNumber: exciseTaxationNumber ?? this.exciseTaxationNumber,
      provinceCity: provinceCity ?? this.provinceCity,
      ownershipHistory: ownershipHistory ?? this.ownershipHistory,
      documentFormat: documentFormat ?? this.documentFormat,
      rawText: rawText ?? this.rawText,
    );
  }

  bool get registrationNumberValid {
    final t = registrationNumber.trim().toUpperCase();
    if (t.isEmpty) return false;
    return RegExp(r'^[A-Z]{1,3}[-\s]?\d{1,4}[A-Z]?$').hasMatch(t) ||
        RegExp(r'^\d{3,4}-[A-Z]{2,3}-\d{2,4}$').hasMatch(t);
  }

  bool get tokenTaxValid => !_isDateExpired(tokenTaxDueDate);
  bool get fitnessValid => !_isDateExpired(fitnessExpiry);

  bool _isDateExpired(String value) {
    final d = _parseDate(value);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }

  DateTime? _parseDate(String value) {
    final m = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})')
        .firstMatch(value);
    if (m == null) return null;
    final dd = int.tryParse(m.group(1)!);
    final mm = int.tryParse(m.group(2)!);
    var yy = int.tryParse(m.group(3)!);
    if (dd == null || mm == null || yy == null) return null;
    if (yy < 100) yy += 2000;
    try {
      return DateTime(yy, mm, dd);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'registration_number': registrationNumber,
      'owner_name': ownerName,
      'owner_address': ownerAddress,
      'father_name': fatherName,
      'cnic_number': cnicNumber,
      'engine_number': engineNumber,
      'chassis_number': chassisNumber,
      'make_model': makeModel,
      'manufacturing_year': manufacturingYear,
      'color': color,
      'fuel_type': fuelType,
      'seating_capacity': seatingCapacity,
      'token_tax_status': tokenTaxStatus,
      'token_tax_due_date': tokenTaxDueDate,
      'fitness_expiry': fitnessExpiry,
      'route_permit': routePermit,
      'excise_taxation_number': exciseTaxationNumber,
      'province_city': provinceCity,
      'ownership_history': ownershipHistory,
      'document_format': documentFormat,
      'registration_number_valid': registrationNumberValid,
      'token_tax_valid': tokenTaxValid,
      'fitness_valid': fitnessValid,
      'raw_text': rawText,
    };
  }
}

