import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

class FaceDetectionService {
  static final FaceDetectionService _instance = FaceDetectionService._internal();

  factory FaceDetectionService() {
    return _instance;
  }

  FaceDetectionService._internal();

  static FaceDetectionService get instance => _instance;

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
    ),
  );

  Future<List<Face>> detectFaces(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      return [];
    }
  }

  Future<bool> hasFaces(String imagePath) async {
    final faces = await detectFaces(imagePath);
    return faces.isNotEmpty;
  }

  void dispose() {
    _faceDetector.close();
  }
}
