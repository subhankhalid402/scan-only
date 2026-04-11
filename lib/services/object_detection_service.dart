import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ObjectDetectionService {
  static final ObjectDetectionService _instance = ObjectDetectionService._internal();

  factory ObjectDetectionService() {
    return _instance;
  }

  ObjectDetectionService._internal();

  static ObjectDetectionService get instance => _instance;

  late ObjectDetector _objectDetector;

  Future<void> initialize() async {
    try {
      _objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
    } catch (e) {
      print('Object detection initialization error: $e');
    }
  }

  Future<List<DetectedObject>> detectObjects(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final objects = await _objectDetector.processImage(inputImage);
      return objects;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _objectDetector.close();
  }
}
