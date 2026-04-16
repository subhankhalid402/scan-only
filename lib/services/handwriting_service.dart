import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class HandwritingService {
  static final HandwritingService instance = HandwritingService._init();
  late final TextRecognizer _textRecognizer;

  HandwritingService._init() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Recognize handwriting from image
  Future<String> recognizeHandwriting(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      String extractedText = '';
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }
      
      return extractedText.trim();
    } catch (e) {
      debugPrint('Handwriting Recognition Error: $e');
      return '';
    }
  }

  /// Get confidence score for handwriting recognition
  Future<double> getConfidenceScore(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      double totalConfidence = 0;
      int elementCount = 0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            totalConfidence += element.confidence ?? 0;
            elementCount++;
          }
        }
      }
      
      return elementCount > 0 ? totalConfidence / elementCount : 0;
    } catch (e) {
      debugPrint('Confidence Score Error: $e');
      return 0;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
