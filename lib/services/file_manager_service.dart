import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class FileManagerService {
  static final FileManagerService instance = FileManagerService._init();
  FileManagerService._init();

  static const _docExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'
  ];
  static const _imgExtensions = ['jpg', 'jpeg', 'png'];
  static const _allExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'jpg', 'jpeg', 'png', 'txt'
  ];

  /// Pick a single document from device storage
  Future<String?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allExtensions,
        allowMultiple: false,
      );
      return result?.files.firstOrNull?.path;
    } catch (e) {
      print('pickDocument error: $e');
      return null;
    }
  }

  /// FIX: Pick multiple documents — uses FileType.any to avoid
  /// Android restriction that blocks multi-select on FileType.custom.
  /// Then filters to supported extensions manually.
  Future<List<String>> pickMultipleDocuments() async {
    try {
      // Try with FileType.any first (most reliable for multi-select on Android)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return [];

      // Filter to only supported file types
      final paths = result.files
          .where((f) => f.path != null && _isSupportedFile(f.path!))
          .map((f) => f.path!)
          .toList();

      return paths;
    } catch (e) {
      print('pickMultipleDocuments error: $e');
      return [];
    }
  }

  /// FIX: Pick multiple images specifically (uses image_picker for better
  /// Android compatibility)
  Future<List<String>> pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 95);
      return images.map((img) => img.path).toList();
    } catch (e) {
      print('pickMultipleImages error: $e');
      return [];
    }
  }

  /// Get all documents from device storage
  Future<List<FileSystemEntity>> getAllDocumentsFromDevice() async {
    try {
      final List<FileSystemEntity> allFiles = [];
      final directories = await _getCommonDocumentDirectories();

      for (final dir in directories) {
        if (await dir.exists()) {
          try {
            final files = dir.listSync(recursive: false);
            for (final file in files) {
              if (file is File && _isSupportedFile(file.path)) {
                allFiles.add(file);
              }
            }
          } catch (e) {
            print('Error reading dir ${dir.path}: $e');
          }
        }
      }

      // Sort by modification date, newest first
      allFiles.sort((a, b) {
        try {
          final aStat = (a as File).statSync();
          final bStat = (b as File).statSync();
          return bStat.modified.compareTo(aStat.modified);
        } catch (_) {
          return 0;
        }
      });

      return allFiles;
    } catch (e) {
      print('getAllDocumentsFromDevice error: $e');
      return [];
    }
  }

  Future<List<Directory>> _getCommonDocumentDirectories() async {
    final List<Directory> dirs = [];

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      dirs.add(appDocDir);

      if (Platform.isAndroid) {
        final externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null) dirs.addAll(externalDirs);

        for (final p in [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/DCIM',
        ]) {
          final d = Directory(p);
          if (await d.exists()) dirs.add(d);
        }
      } else if (Platform.isIOS) {
        // iOS: app sandbox only — no raw filesystem access
        final tmp = await getTemporaryDirectory();
        dirs.add(tmp);
      }
    } catch (e) {
      print('_getCommonDocumentDirectories error: $e');
    }

    return dirs;
  }

  bool _isSupportedFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _allExtensions.contains(ext);
  }

  Future<double> getFileSizeMB(String filePath) async {
    try {
      return await File(filePath).length() / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  String getFileName(String filePath) => filePath.split('/').last;

  String getFileExtension(String filePath) =>
      filePath.split('.').last.toLowerCase();
}
