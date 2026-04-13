import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

/// Local backup: bundle library files into a single ZIP (not encrypted).
class DocumentExportService {
  DocumentExportService._();
  static final DocumentExportService instance = DocumentExportService._();

  /// Creates a ZIP of all documents that still exist on disk. Returns path or null if empty/error.
  Future<String?> exportAllDocumentsToZipFile() async {
    try {
      final docs = await DatabaseService.instance.getAllDocuments();
      if (docs.isEmpty) return null;

      final archive = Archive();
      for (final doc in docs) {
        final f = File(doc.filePath);
        if (!await f.exists()) continue;
        final bytes = await f.readAsBytes();
        final ext = p.extension(doc.filePath).toLowerCase();
        final safeName =
            '${doc.name.replaceAll(RegExp(r'[^\w\-\.\s\(\)]'), '_')}$ext';
        final idPart = doc.id != null ? '${doc.id}_' : '';
        archive.addFile(ArchiveFile('$idPart$safeName', bytes.length, bytes));
      }
      if (archive.isEmpty) return null;

      final outDir = await getTemporaryDirectory();
      final zipPath =
          '${outDir.path}/ScanOnly_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) return null;
      await File(zipPath).writeAsBytes(zipBytes);
      return zipPath;
    } catch (_) {
      return null;
    }
  }
}
