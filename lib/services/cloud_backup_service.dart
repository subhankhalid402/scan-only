import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import 'app_local_storage.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class CloudSyncResult {
  final int uploaded;
  final int failed;
  /// Rows updated from `local_only` / `upload_failed` → `queued_for_upload` in this run.
  final int newlyQueuedCount;
  /// Rows still `queued_for_upload` when this run finished (e.g. upload not attempted yet).
  final int pendingUploadCount;
  /// Why uploads did not run (when [pendingUploadCount] > 0 and nothing uploaded).
  final String? diagnostic;

  const CloudSyncResult({
    required this.uploaded,
    required this.failed,
    this.newlyQueuedCount = 0,
    this.pendingUploadCount = 0,
    this.diagnostic,
  });
}

class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  static const String bucketName = 'scan-only';
  static const String legacyBucketName = 'scan-olny';
  bool _running = false;

  Future<CloudSyncResult> syncPendingUploads() async {
    if (_running) {
      return const CloudSyncResult(
        uploaded: 0,
        failed: 0,
        newlyQueuedCount: 0,
        pendingUploadCount: 0,
        diagnostic: 'Another sync is already running. Wait a few seconds and tap Sync again.',
      );
    }
    _running = true;
    var uploaded = 0;
    var failed = 0;
    var newlyQueued = 0;
    try {
      if (!AppLocalStorage.getBool('cloudBackupEnabled')) {
        debugPrint('[CloudBackup] Cloud backup is off in settings; skipping.');
        return const CloudSyncResult(
          uploaded: 0,
          failed: 0,
          diagnostic: 'Cloud backup is turned off in Settings.',
        );
      }

      // Queue *before* Supabase checks so older `local_only` docs are marked when backup is on,
      // even if this run cannot upload yet (offline / init failed).
      newlyQueued = await DatabaseService.instance.queueLocalOnlyForUpload();
      debugPrint('[CloudBackup] Rows marked queued_for_upload (updated): $newlyQueued');

      if (!SupabaseService.isAvailable) {
        final pending =
            await DatabaseService.instance.getBySyncStatus('queued_for_upload');
        debugPrint(
          '[CloudBackup] Supabase unavailable; ${pending.length} doc(s) waiting for upload.',
        );
        return CloudSyncResult(
          uploaded: 0,
          failed: 0,
          newlyQueuedCount: newlyQueued,
          pendingUploadCount: pending.length,
          diagnostic:
              'Supabase did not finish initializing (wrong URL/key, no network at app start, or init error). '
              'Fully close the app, turn Wi‑Fi/mobile data on, open again, then Sync.'
              '${SupabaseService.lastInitError != null ? '\n\nInit error: ${SupabaseService.lastInitError}' : ''}',
        );
      }

      final client = SupabaseService.client;
      if (client == null) {
        final pending =
            await DatabaseService.instance.getBySyncStatus('queued_for_upload');
        debugPrint('[CloudBackup] Client null; ${pending.length} pending.');
        return CloudSyncResult(
          uploaded: 0,
          failed: 0,
          newlyQueuedCount: newlyQueued,
          pendingUploadCount: pending.length,
          diagnostic: 'Supabase client is not ready. Restart the app and try Sync again.',
        );
      }

      if (client.auth.currentSession == null) {
        try {
          await client.auth.signInAnonymously();
        } catch (e) {
          debugPrint('[CloudBackup] Anonymous sign-in failed: $e');
          final pending =
              await DatabaseService.instance.getBySyncStatus('queued_for_upload');
          return CloudSyncResult(
            uploaded: 0,
            failed: 0,
            newlyQueuedCount: newlyQueued,
            pendingUploadCount: pending.length,
            diagnostic:
                'Anonymous sign-in was rejected (this is the usual cause).\n\n'
                'In Supabase Dashboard: Authentication → Providers → Anonymous → turn ON, then save.\n\n'
                'Technical detail: $e',
          );
        }
      }

      final pending = await DatabaseService.instance.getBySyncStatus('queued_for_upload');
      debugPrint('[CloudBackup] Pending uploads count: ${pending.length}');
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

    final stillQueued =
        (await DatabaseService.instance.getBySyncStatus('queued_for_upload')).length;
    debugPrint(
      '[CloudBackup] Sync result => uploaded: $uploaded, failed: $failed, stillQueued: $stillQueued',
    );
    String? diagnostic;
    if (stillQueued > 0 && uploaded == 0 && failed == 0) {
      diagnostic =
          'Queue did not empty (unexpected). See debug console for [CloudBackup] lines.';
    }
    return CloudSyncResult(
      uploaded: uploaded,
      failed: failed,
      newlyQueuedCount: newlyQueued,
      pendingUploadCount: stillQueued,
      diagnostic: diagnostic,
    );
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
      final usedBucket = await _uploadWithBucketFallback(
        client: client,
        cloudPath: cloudPath,
        file: f,
      );
      debugPrint('[CloudBackup] Uploaded to bucket: $usedBucket');

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
    } catch (e) {
      debugPrint('[CloudBackup] Upload failed for doc ${doc.id}: $e');
      await DatabaseService.instance.updateCloudSyncFields(
        id: doc.id!,
        syncStatus: 'upload_failed',
      );
      return false;
    }
  }

  Future<String> _uploadWithBucketFallback({
    required dynamic client,
    required String cloudPath,
    required File file,
  }) async {
    try {
      await client.storage.from(bucketName).upload(cloudPath, file);
      return bucketName;
    } catch (e) {
      debugPrint('[CloudBackup] Primary bucket "$bucketName" failed: $e');
      await client.storage.from(legacyBucketName).upload(cloudPath, file);
      debugPrint('[CloudBackup] Uploaded using legacy bucket "$legacyBucketName".');
      return legacyBucketName;
    }
  }
}
