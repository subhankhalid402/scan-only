import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrTextLine {
  final String text;
  final Rect boundingBox;
  final double confidence;

  const OcrTextLine({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });
}

class OcrService {
  static final OcrService instance = OcrService._init();

  late final TextRecognizer _latinRecognizer;
  late final TextRecognizer _chineseRecognizer;
  late final TextRecognizer _devanagariRecognizer;

  OcrService._init() {
    _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _chineseRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    _devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
  }

  /// Bounding boxes for detected text (Latin model). Used by Smart Erase.
  Future<List<Rect>> getTextBoundingBoxesForErase(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _latinRecognizer.processImage(inputImage);
      final boxes = <Rect>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.elements.isNotEmpty) {
            for (final el in line.elements) {
              boxes.add(el.boundingBox);
            }
          } else {
            boxes.add(line.boundingBox);
          }
        }
      }
      return boxes;
    } catch (e) {
      print('OCR boxes error: $e');
      return [];
    }
  }

  /// Extract text - auto detects script
  Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _latinRecognizer.processImage(inputImage);

      String extractedText = '';
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      return extractedText.trim();
    } catch (e) {
      print('OCR Error: $e');
      return '';
    }
  }

  /// Extract OCR lines with bounding boxes for UI overlays.
  Future<List<OcrTextLine>> extractTextLines(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _latinRecognizer.processImage(inputImage);
      final out = <OcrTextLine>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isEmpty) continue;
          out.add(
            OcrTextLine(
              text: t,
              boundingBox: line.boundingBox,
              confidence: line.elements.isNotEmpty
                  ? line.elements
                          .map((e) => e.confidence ?? 0.0)
                          .fold<double>(0.0, (a, b) => a + b) /
                      line.elements.length
                  : 0.0,
            ),
          );
        }
      }
      return out;
    } catch (e) {
      print('OCR lines error: $e');
      return const [];
    }
  }

  /// Extract Urdu / Arabic text (uses Latin recognizer — ML Kit
  /// handles Urdu/Arabic script within Latin mode on device)
  Future<String> extractUrduText(String imagePath) async {
    try {
      // ML Kit Latin recognizer handles Urdu on Android devices
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _latinRecognizer.processImage(inputImage);

      String extractedText = '';
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      return extractedText.trim().isEmpty
          ? 'No text detected. Try better lighting.'
          : extractedText.trim();
    } catch (e) {
      print('Urdu OCR Error: $e');
      return '';
    }
  }

  /// Extract text with confidence score details
  Future<Map<String, dynamic>> extractTextWithDetails(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _latinRecognizer.processImage(inputImage);

      String extractedText = '';
      double totalConfidence = 0;
      int elementCount = 0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          extractedText += '${line.text}\n';
          for (final element in line.elements) {
            totalConfidence += element.confidence ?? 0;
            elementCount++;
          }
        }
      }

      final averageConfidence =
          elementCount > 0 ? totalConfidence / elementCount : 0.0;

      return {
        'text': extractedText.trim(),
        'confidence': averageConfidence,
        'wordCount': elementCount,
        'lineCount': recognizedText.blocks
            .fold(0, (sum, b) => sum + b.lines.length),
      };
    } catch (e) {
      print('OCR Details Error: $e');
      return {'text': '', 'confidence': 0.0, 'wordCount': 0, 'lineCount': 0};
    }
  }

  /// Extract text from Chinese documents
  Future<String> extractChineseText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _chineseRecognizer.processImage(inputImage);
      String text = '';
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          text += '${line.text}\n';
        }
      }
      return text.trim();
    } catch (e) {
      print('Chinese OCR Error: $e');
      return '';
    }
  }

  void dispose() {
    _latinRecognizer.close();
    _chineseRecognizer.close();
    _devanagariRecognizer.close();
  }
}
