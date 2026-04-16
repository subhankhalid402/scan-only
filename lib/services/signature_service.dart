import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class SignatureService {
  static final SignatureService instance = SignatureService._init();
  SignatureService._init();

  /// Add signature to image
  Future<String> addSignatureToImage(
    String imagePath,
    Uint8List signatureBytes, {
    double x = 0.8,
    double y = 0.9,
    double scale = 0.2,
  }) async {
    try {
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) throw Exception('Could not decode image');

      // Decode signature
      var signature = img.decodeImage(signatureBytes);
      if (signature == null) throw Exception('Could not decode signature');

      // Calculate position and size
      final sigWidth = (image.width * scale).toInt();
      final sigHeight = (signature.height * sigWidth ~/ signature.width).toInt();
      final posX = (image.width * x - sigWidth / 2).toInt().clamp(0, image.width - sigWidth);
      final posY = (image.height * y - sigHeight / 2).toInt().clamp(0, image.height - sigHeight);

      // Resize signature
      signature = img.copyResize(signature, width: sigWidth, height: sigHeight);

      // Composite signature onto image
      image = img.compositeImage(image, signature, dstX: posX, dstY: posY);

      final signedPath = await _saveSignedImage(image, imagePath);
      return signedPath;
    } catch (e) {
      debugPrint('Signature Error: $e');
      return imagePath;
    }
  }

  /// Save signature to file
  Future<String> saveSignature(Uint8List signatureBytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = path.join(dir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(signatureBytes);
      return filePath;
    } catch (e) {
      debugPrint('Save Signature Error: $e');
      return '';
    }
  }

  /// Load saved signature
  Future<Uint8List?> loadSignature(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('Load Signature Error: $e');
      return null;
    }
  }

  /// Get all saved signatures
  Future<List<String>> getSavedSignatures() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync();
      return files
          .where((f) => f.path.contains('signature_'))
          .map((f) => f.path)
          .toList();
    } catch (e) {
      debugPrint('Get Signatures Error: $e');
      return [];
    }
  }

  /// Delete signature
  Future<bool> deleteSignature(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete Signature Error: $e');
      return false;
    }
  }

  /// Save signed image
  Future<String> _saveSignedImage(
    img.Image image,
    String originalPath, {
    String suffix = '_signed',
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = path.basenameWithoutExtension(originalPath);
    final ext = path.extension(originalPath);
    final signedPath = path.join(dir.path, '$fileName$suffix$ext');

    final signedFile = File(signedPath);
    await signedFile.writeAsBytes(img.encodeJpg(image));

    return signedPath;
  }
}
