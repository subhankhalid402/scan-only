import 'dart:io';
import 'package:flutter/foundation.dart';

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

  static const String bucketName = 'scan-only';
  static const String legacyBucketName = 'scan-olny';
  bool _running = false;

  Future<CloudSyncResult> syncPendingUploads() async {
    if (_running) return const CloudSyncResult(uploaded: 0, failed: 0);
    _running = true;
    var uploaded = 0;
    var failed = 0;
    try {
      if (!SupabaseService.isAvailable) {
        debugPrint('[CloudBackup] Supabase unavailable, skipping sync.');
        return const CloudSyncResult(uploaded: 0, failed: 0);
      }
      final queuedNow = await DatabaseService.instance.queueLocalOnlyForUpload();
      debugPrint('[CloudBackup] Queued local docs: $queuedNow');

      final client = SupabaseService.client;
      if (client == null) {
        debugPrint('[CloudBackup] Client null, skipping sync.');
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

    debugPrint('[CloudBackup] Sync result => uploaded: $uploaded, failed: $failed');
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
