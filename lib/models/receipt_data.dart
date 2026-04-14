class ReceiptItem {
  final String name;
  final String qty;
  final String unitPrice;
  final String totalPrice;

  const ReceiptItem({
    this.name = '',
    this.qty = '',
    this.unitPrice = '',
    this.totalPrice = '',
  });

  ReceiptItem copyWith({
    String? name,
    String? qty,
    String? unitPrice,
    String? totalPrice,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'qty': qty,
        'unit_price': unitPrice,
        'total_price': totalPrice,
      };
}

class ReceiptData {
  final String storeName;
  final String storeAddress;
  final String contactNumber;
  final String purchaseDateTime;
  final String cashierName;
  final String counterNumber;
  final String receiptNumber;
  final String taxNumber;
  final String ntnNumber;
  final String gstNumber;
  final String fbrInvoiceNumber;
  final bool fbrQrValid;
  final String fbrQrRaw;
  final List<ReceiptItem> items;
  final String subtotal;
  final String discount;
  final String tax;
  final String serviceCharge;
  final String grandTotal;
  final String paymentMethod;
  final String amountPaid;
  final String changeReturned;
  final String category;
  final String currency;
  final bool isDuplicate;
  final String rawText;

  const ReceiptData({
    this.storeName = '',
    this.storeAddress = '',
    this.contactNumber = '',
    this.purchaseDateTime = '',
    this.cashierName = '',
    this.counterNumber = '',
    this.receiptNumber = '',
    this.taxNumber = '',
    this.ntnNumber = '',
    this.gstNumber = '',
    this.fbrInvoiceNumber = '',
    this.fbrQrValid = false,
    this.fbrQrRaw = '',
    this.items = const [],
    this.subtotal = '',
    this.discount = '',
    this.tax = '',
    this.serviceCharge = '',
    this.grandTotal = '',
    this.paymentMethod = '',
    this.amountPaid = '',
    this.changeReturned = '',
    this.category = 'Uncategorized',
    this.currency = 'PKR',
    this.isDuplicate = false,
    this.rawText = '',
  });

  ReceiptData copyWith({
    String? storeName,
    String? storeAddress,
    String? contactNumber,
    String? purchaseDateTime,
    String? cashierName,
    String? counterNumber,
    String? receiptNumber,
    String? taxNumber,
    String? ntnNumber,
    String? gstNumber,
    String? fbrInvoiceNumber,
    bool? fbrQrValid,
    String? fbrQrRaw,
    List<ReceiptItem>? items,
    String? subtotal,
    String? discount,
    String? tax,
    String? serviceCharge,
    String? grandTotal,
    String? paymentMethod,
    String? amountPaid,
    String? changeReturned,
    String? category,
    String? currency,
    bool? isDuplicate,
    String? rawText,
  }) {
    return ReceiptData(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      contactNumber: contactNumber ?? this.contactNumber,
      purchaseDateTime: purchaseDateTime ?? this.purchaseDateTime,
      cashierName: cashierName ?? this.cashierName,
      counterNumber: counterNumber ?? this.counterNumber,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      taxNumber: taxNumber ?? this.taxNumber,
      ntnNumber: ntnNumber ?? this.ntnNumber,
      gstNumber: gstNumber ?? this.gstNumber,
      fbrInvoiceNumber: fbrInvoiceNumber ?? this.fbrInvoiceNumber,
      fbrQrValid: fbrQrValid ?? this.fbrQrValid,
      fbrQrRaw: fbrQrRaw ?? this.fbrQrRaw,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountPaid: amountPaid ?? this.amountPaid,
      changeReturned: changeReturned ?? this.changeReturned,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      rawText: rawText ?? this.rawText,
    );
  }

  double get totalAmount => _parseAmount(grandTotal) ?? _parseAmount(subtotal) ?? 0.0;

  Map<String, dynamic> toJsonMap() {
    return {
      'store_name': storeName,
      'store_address': storeAddress,
      'contact_number': contactNumber,
      'purchase_datetime': purchaseDateTime,
      'cashier_name': cashierName,
      'counter_number': counterNumber,
      'receipt_number': receiptNumber,
      'tax_number': taxNumber,
      'ntn_number': ntnNumber,
      'gst_number': gstNumber,
      'fbr_invoice_number': fbrInvoiceNumber,
      'fbr_qr_valid': fbrQrValid,
      'fbr_qr_raw': fbrQrRaw,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'service_charge': serviceCharge,
      'grand_total': grandTotal,
      'payment_method': paymentMethod,
      'amount_paid': amountPaid,
      'change_returned': changeReturned,
      'category': category,
      'currency': currency,
      'is_duplicate': isDuplicate,
      'raw_text': rawText,
    };
  }

  static double? _parseAmount(String text) {
    final m = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(text.replaceAll(',', ''));
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '');
  }
}

