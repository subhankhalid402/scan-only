import '../models/document_model.dart';
import 'database_service.dart';

class BatchRenameService {
  static final BatchRenameService _instance = BatchRenameService._internal();

  factory BatchRenameService() {
    return _instance;
  }

  BatchRenameService._internal();

  static BatchRenameService get instance => _instance;

  Future<void> renameMultipleDocuments(
    List<DocumentModel> documents,
    String prefix,
  ) async {
    try {
      for (int i = 0; i < documents.length; i++) {
        final newName = '$prefix ${i + 1}';
        final updated = documents[i].copyWith(
          name: newName,
          modifiedAt: DateTime.now(),
        );
        await DatabaseService.instance.updateDocument(updated);
      }
    } catch (e) {
      throw Exception('Batch rename failed: $e');
    }
  }

  Future<void> renameWithPattern(
    List<DocumentModel> documents,
    String pattern, // e.g., "Document_{date}_{index}"
  ) async {
    try {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month}${now.day}';

      for (int i = 0; i < documents.length; i++) {
        String newName = pattern
            .replaceAll('{date}', dateStr)
            .replaceAll('{index}', (i + 1).toString())
            .replaceAll('{type}', documents[i].fileType);

        final updated = documents[i].copyWith(
          name: newName,
          modifiedAt: DateTime.now(),
        );
        await DatabaseService.instance.updateDocument(updated);
      }
    } catch (e) {
      throw Exception('Pattern rename failed: $e');
    }
  }
}
