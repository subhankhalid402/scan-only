import 'dart:io';

import '../models/document_model.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class CloudSyncResult {
  final int uploaded;
  final int failed;

  const CloudSyncResult({
    required this.uploaded,
    required this.failed,
  });
}

class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  static const String bucketName = 'scan-olny';
  bool _running = false;

  Future<CloudSyncResult> syncPendingUploads() async {
    if (_running) return const CloudSyncResult(uploaded: 0, failed: 0);
    _running = true;
    var uploaded = 0;
    var failed = 0;
    try {
      if (!SupabaseService.isAvailable) {
        return const CloudSyncResult(uploaded: 0, failed: 0);
      }

      final client = SupabaseService.client;
      if (client == null) {
        return const CloudSyncResult(uploaded: 0, failed: 0);
      }

      if (client.auth.currentSession == null) {
        try {
          await client.auth.signInAnonymously();
        } catch (_) {
          return const CloudSyncResult(uploaded: 0, failed: 0);
        }
      }

      final pending = await DatabaseService.instance.getBySyncStatus('queued_for_upload');
      for (final doc in pending) {
        final ok = await _uploadSingle(client, doc);
        if (ok) {
          uploaded++;
        } else {
          failed++;
        }
      }
    } finally {
      _running = false;
    }

    return CloudSyncResult(uploaded: uploaded, failed: failed);
  }

  Future<bool> _uploadSingle(dynamic client, DocumentModel doc) async {
    if (doc.id == null) return false;
    final f = File(doc.filePath);
    if (!f.existsSync()) {
      await DatabaseService.instance.updateCloudSyncFields(
        id: doc.id!,
        syncStatus: 'upload_failed',
      );
      return false;
    }

    try {
      final uid = client.auth.currentUser?.id ?? 'anon';
      final ext = doc.fileType.toLowerCase();
      final cloudPath = '$uid/${doc.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await client.storage.from(bucketName).upload(
            cloudPath,
            f,
          );

      // Best-effort metadata upsert.
      await client.from('cloud_documents').upsert({
        'local_id': doc.id,
        'user_id': uid,
        'name': doc.name,
        'scan_type': doc.scanType,
        'file_type': doc.fileType,
        'file_size_mb': doc.fileSizeMB,
        'cloud_path': cloudPath,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await DatabaseService.instance.updateCloudSyncFields(
        id: doc.id!,
        syncStatus: 'synced',
        cloudPath: cloudPath,
      );
      return true;
    } catch (_) {
      await DatabaseService.instance.updateCloudSyncFields(
        id: doc.id!,
        syncStatus: 'upload_failed',
      );
      return false;
    }
  }
}
