import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class AdvancedBarcodeService {
  static final AdvancedBarcodeService _instance = AdvancedBarcodeService._internal();

  factory AdvancedBarcodeService() {
    return _instance;
  }

  AdvancedBarcodeService._internal();

  static AdvancedBarcodeService get instance => _instance;

  final _barcodeScanner = BarcodeScanner(
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upca,
      BarcodeFormat.upce,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
    ],
  );

  Future<List<Barcode>> scanBarcodes(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final barcodes = await _barcodeScanner.processImage(inputImage);
      return barcodes;
    } catch (e) {
      return [];
    }
  }

  String getBarcodeTypeString(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.ean13:
        return 'EAN 13';
      case BarcodeFormat.ean8:
        return 'EAN 8';
      case BarcodeFormat.upca:
        return 'UPC A';
      case BarcodeFormat.upce:
        return 'UPC E';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.pdf417:
        return 'PDF 417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      default:
        return 'Unknown';
    }
  }

  void dispose() {
    _barcodeScanner.close();
  }
}
