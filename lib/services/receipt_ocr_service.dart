import 'dart:ui' show Rect;
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/receipt_data.dart';
import 'advanced_barcode_service.dart';
import 'image_enhancement_service.dart';
import 'ocr_service.dart';

class ReceiptOcrResult {
  final ReceiptData data;
  final List<Rect> textBoxes;
  final List<Rect> itemBoxes;
  final Rect? headerZone;
  final Rect? summaryZone;

  const ReceiptOcrResult({
    required this.data,
    required this.textBoxes,
    required this.itemBoxes,
    required this.headerZone,
    required this.summaryZone,
  });
}

class ReceiptOcrService {
  ReceiptOcrService._();
  static final ReceiptOcrService instance = ReceiptOcrService._();

  Future<String> enhanceReceiptImage(String imagePath) async {
    final thermal = await ImageEnhancementService.instance.polishCaptureForScanMode(
      imagePath,
      'receipt',
      filter: 'thermal',
    );
    return ImageEnhancementService.instance.polishCaptureForScanMode(
      thermal,
      'receipt',
      filter: 'enhanced',
    );
  }

  Future<String> stitchLongReceipt(List<String> imagePaths) async {
    if (imagePaths.length <= 1) return imagePaths.first;
    final decoded = <img.Image>[];
    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final im = img.decodeImage(bytes);
      if (im != null) decoded.add(im);
    }
    if (decoded.isEmpty) return imagePaths.first;
    final maxW = decoded.map((e) => e.width).reduce((a, b) => a > b ? a : b);
    final resized = decoded.map((e) => e.width == maxW ? e : img.copyResize(e, width: maxW)).toList();
    final totalH = resized.fold<int>(0, (a, b) => a + b.height);
    final out = img.Image(width: maxW, height: totalH);
    var y = 0;
    for (final r in resized) {
      img.compositeImage(out, r, dstX: 0, dstY: y);
      y += r.height;
    }
    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, 'receipt_stitch_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(outPath).writeAsBytes(img.encodeJpg(out, quality: 92));
    return outPath;
  }

  Future<ReceiptOcrResult> extract(String imagePath) async {
    final linesEn = await OcrService.instance.extractTextLines(imagePath);
    final urdu = await OcrService.instance.extractUrduText(imagePath);
    final mergedText = '${linesEn.map((e) => e.text).join('\n')}\n$urdu';
    final textBoxes = linesEn.map((e) => e.boundingBox).toList();

    String byKeywords(List<String> keys) {
      for (final l in linesEn) {
        final lower = l.text.toLowerCase();
        for (final k in keys) {
          if (!lower.contains(k.toLowerCase())) continue;
          final cleaned = l.text.replaceAll(RegExp('(?i)$k'), '').replaceAll(':', '').trim();
          if (cleaned.isNotEmpty) return cleaned;
        }
      }
      return '';
    }

    String extractPhone() {
      final m = RegExp(r'(\+?\d[\d\-\s]{7,}\d)').firstMatch(mergedText);
      return m?.group(1)?.trim() ?? '';
    }

    String extractDateTime() {
      final date = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b').firstMatch(mergedText)?.group(0) ?? '';
      final time = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b').firstMatch(mergedText)?.group(0) ?? '';
      return '$date $time'.trim();
    }

    String extractCurrency() {
      final t = mergedText.toUpperCase();
      if (t.contains('PKR') || t.contains('RS') || t.contains('RUP')) return 'PKR';
      if (t.contains('USD') || t.contains(r'$')) return 'USD';
      if (t.contains('AED')) return 'AED';
      return 'PKR';
    }

    String amountByLabel(List<String> keys) {
      for (final l in linesEn) {
        final low = l.text.toLowerCase();
        if (!keys.any((k) => low.contains(k))) continue;
        final matches = RegExp(r'(\d+(?:[.,]\d{1,2})?)').allMatches(l.text).toList();
        if (matches.isNotEmpty) return matches.last.group(1) ?? '';
      }
      return '';
    }

    List<ReceiptItem> extractItems() {
      final list = <ReceiptItem>[];
      for (final l in linesEn) {
        final t = l.text.trim();
        if (t.length < 4) continue;
        final lower = t.toLowerCase();
        if (lower.contains('total') ||
            lower.contains('subtotal') ||
            lower.contains('tax') ||
            lower.contains('discount') ||
            lower.contains('cash') ||
            lower.contains('change')) {
          continue;
        }
        final nums = RegExp(r'(\d+(?:[.,]\d{1,2})?)').allMatches(t).map((m) => m.group(1) ?? '').toList();
        if (nums.length < 2) continue;
        final total = nums.last;
        final unit = nums.length > 2 ? nums[nums.length - 2] : '';
        final qty = nums.length > 2 ? nums.first : '1';
        final name = t.replaceAll(RegExp(r'(\d+(?:[.,]\d{1,2})?)'), '').trim();
        if (name.isEmpty) continue;
        list.add(ReceiptItem(name: name, qty: qty, unitPrice: unit, totalPrice: total));
      }
      return list;
    }

    String categorize(String text) {
      final t = text.toLowerCase();
      if (RegExp(r'burger|restaurant|food|cafe|pizza|kfc|mcd').hasMatch(t)) return 'Food';
      if (RegExp(r'pharmacy|hospital|clinic|medical').hasMatch(t)) return 'Medical';
      if (RegExp(r'fuel|petrol|uber|careem|transport').hasMatch(t)) return 'Transport';
      if (RegExp(r'grocery|mart|store|shopping|mall').hasMatch(t)) return 'Shopping';
      if (RegExp(r'school|book|tuition|academy').hasMatch(t)) return 'Education';
      return 'General';
    }

    final barcodeList = await AdvancedBarcodeService.instance.scanBarcodes(imagePath);
    final fbrQr = barcodeList
        .map((e) => e.rawValue ?? '')
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final fbrQrValid = fbrQr.toLowerCase().contains('fbr') ||
        fbrQr.toLowerCase().contains('pos') ||
        fbrQr.toLowerCase().contains('invoice');

    final ntn = RegExp(r'\bNTN[:\s-]*([A-Z0-9\-]{5,})', caseSensitive: false)
            .firstMatch(mergedText)
            ?.group(1) ??
        '';
    final gst = RegExp(r'\bGST[:\s-]*([A-Z0-9\-]{4,})', caseSensitive: false)
            .firstMatch(mergedText)
            ?.group(1) ??
        '';
    final invoice = RegExp(r'\b(?:Invoice|Receipt)\s*(?:No|#|Number)?[:\s-]*([A-Z0-9\-]{4,})', caseSensitive: false)
            .firstMatch(mergedText)
            ?.group(1) ??
        '';
    final taxNo = RegExp(r'\b(?:Tax|NTN|GST)\s*(?:No|#|Number)?[:\s-]*([A-Z0-9\-]{4,})', caseSensitive: false)
            .firstMatch(mergedText)
            ?.group(1) ??
        '';

    final items = extractItems();
    Rect? headerZone;
    Rect? summaryZone;
    final itemBoxes = <Rect>[];
    if (textBoxes.isNotEmpty) {
      Rect bounds = textBoxes.first;
      for (final b in textBoxes.skip(1)) {
        bounds = bounds.expandToInclude(b);
      }
      final h = bounds.height;
      headerZone = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, h * 0.22);
      summaryZone = Rect.fromLTWH(bounds.left, bounds.bottom - (h * 0.25), bounds.width, h * 0.25);
      for (final b in textBoxes) {
        if (b.top >= headerZone.bottom && b.bottom <= summaryZone.top) {
          itemBoxes.add(b);
        }
      }
    }

    final data = ReceiptData(
      storeName: byKeywords(const ['store', 'shop', 'mart']).ifEmpty(linesEn.isNotEmpty ? linesEn.first.text : ''),
      storeAddress: byKeywords(const ['address', 'addr']),
      contactNumber: extractPhone(),
      purchaseDateTime: extractDateTime(),
      cashierName: byKeywords(const ['cashier']),
      counterNumber: byKeywords(const ['counter', 'till']),
      receiptNumber: invoice,
      taxNumber: taxNo,
      ntnNumber: ntn,
      gstNumber: gst,
      fbrInvoiceNumber: invoice,
      fbrQrValid: fbrQrValid,
      fbrQrRaw: fbrQr,
      items: items,
      subtotal: amountByLabel(const ['subtotal', 'sub total']),
      discount: amountByLabel(const ['discount']),
      tax: amountByLabel(const ['tax', 'gst', 'vat']),
      serviceCharge: amountByLabel(const ['service']),
      grandTotal: amountByLabel(const ['grand total', 'total', 'net total']),
      paymentMethod: byKeywords(const ['cash', 'card', 'online', 'bank']),
      amountPaid: amountByLabel(const ['paid', 'amount paid']),
      changeReturned: amountByLabel(const ['change']),
      category: categorize(mergedText),
      currency: extractCurrency(),
      rawText: mergedText,
    );

    return ReceiptOcrResult(
      data: data,
      textBoxes: textBoxes,
      itemBoxes: itemBoxes,
      headerZone: headerZone,
      summaryZone: summaryZone,
    );
  }
}

extension on String {
  String ifEmpty(String alt) => trim().isEmpty ? alt : this;
}

