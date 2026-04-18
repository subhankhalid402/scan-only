import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/document_model.dart';
import 'app_local_storage.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scanonly.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileType TEXT NOT NULL,
        scanType TEXT NOT NULL,
        pageCount INTEGER NOT NULL DEFAULT 1,
        fileSizeMB REAL NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        thumbnailPath TEXT,
        ocrText TEXT,
        tags TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'local_only',
        cloudPath TEXT,
        cloudUpdatedAt TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_filePath_unique ON documents(filePath)',
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN syncStatus TEXT NOT NULL DEFAULT 'local_only'",
      );
      await db.execute(
        'ALTER TABLE documents ADD COLUMN cloudPath TEXT',
      );
      await db.execute(
        'ALTER TABLE documents ADD COLUMN cloudUpdatedAt TEXT',
      );
    }
    if (oldVersion < 4) {
      await _removeDuplicateFilePathRows(db);
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_filePath_unique ON documents(filePath)',
      );
    }
  }

  Future<int> insertDocument(DocumentModel doc) async {
    final db = await instance.database;
    final cloudBackupEnabled = AppLocalStorage.getBool('cloudBackupEnabled');
    final docToInsert = (cloudBackupEnabled && doc.syncStatus == 'local_only')
        ? doc.copyWith(syncStatus: 'queued_for_upload')
        : doc;
    final existing = await db.query(
      'documents',
      columns: ['id'],
      where: 'filePath = ?',
      whereArgs: [docToInsert.filePath],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return (existing.first['id'] as int?) ?? 0;
    }
    return await db.insert('documents', docToInsert.toMap());
  }

  Future<List<DocumentModel>> getAllDocuments() async {
    final db = await instance.database;
    final result = await db.query('documents', orderBy: 'createdAt DESC');
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  /// Newest first, capped in SQL (avoids loading the whole table for home / previews).
  Future<List<DocumentModel>> getRecentDocuments(int limit) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<List<DocumentModel>> searchDocuments(String query) async {
    final db = await instance.database;
    final q = '%$query%';
    final result = await db.query(
      'documents',
      where: 'name LIKE ? OR ocrText LIKE ? OR tags LIKE ?',
      whereArgs: [q, q, q],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<List<DocumentModel>> getFavorites() async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<List<DocumentModel>> getByType(String fileType) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'fileType = ?',
      whereArgs: [fileType],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<List<DocumentModel>> getByScanType(String scanType) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'scanType = ?',
      whereArgs: [scanType],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<List<DocumentModel>> getBySyncStatus(String syncStatus) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'syncStatus = ?',
      whereArgs: [syncStatus],
      orderBy: 'createdAt ASC',
    );
    return result.map((map) => DocumentModel.fromMap(map)).toList();
  }

  Future<int> updateDocument(DocumentModel doc) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<int> toggleFavorite(int id, bool isFavorite) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      {
        'isFavorite': isFavorite ? 1 : 0,
        'modifiedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateOcrText(int id, String ocrText) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      {
        'ocrText': ocrText,
        'modifiedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTags(int id, List<String> tags) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      {
        'tags': tags.join(','),
        'modifiedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateThumbnail(int id, String thumbnailPath) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      {'thumbnailPath': thumbnailPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCloudSyncFields({
    required int id,
    required String syncStatus,
    String? cloudPath,
  }) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      {
        'syncStatus': syncStatus,
        'cloudPath': cloudPath,
        'cloudUpdatedAt': DateTime.now().toIso8601String(),
        'modifiedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// When cloud backup is enabled, queue local and previously failed items.
  Future<int> queueLocalOnlyForUpload() async {
    final db = await instance.database;
    return await db.update(
      'documents',
      {
        'syncStatus': 'queued_for_upload',
        'modifiedAt': DateTime.now().toIso8601String(),
      },
      where: 'syncStatus IN (?, ?)',
      whereArgs: ['local_only', 'upload_failed'],
    );
  }

  Future<int> deleteDocument(int id) async {
    final db = await instance.database;
    return await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes every row and removes referenced files from disk.
  Future<void> deleteAllDocumentsWithFiles() async {
    final db = await instance.database;
    final rows = await db.query('documents');
    for (final row in rows) {
      final fp = row['filePath'] as String?;
      final tp = row['thumbnailPath'] as String?;
      for (final path in [fp, tp]) {
        if (path == null || path.isEmpty) continue;
        try {
          final f = File(path);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    }
    await db.delete('documents');
  }

  Future<int> getDocumentCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM documents');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Counts rows grouped by [DocumentModel.syncStatus] (`local_only`, `synced`, etc.).
  Future<Map<String, int>> countDocumentsBySyncStatus() async {
    final db = await instance.database;
    final rows = await db.rawQuery(
      'SELECT syncStatus, COUNT(*) AS n FROM documents GROUP BY syncStatus',
    );
    final out = <String, int>{};
    for (final r in rows) {
      final key = (r['syncStatus'] as String?) ?? 'unknown';
      final n = r['n'];
      out[key] = n is int ? n : (n as num?)?.toInt() ?? 0;
    }
    return out;
  }

  Future<Map<String, int>> getDocumentCountByType() async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT fileType, COUNT(*) as count FROM documents GROUP BY fileType');
    final map = <String, int>{};
    for (final row in result) {
      map[row['fileType'] as String] = row['count'] as int;
    }
    return map;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> _removeDuplicateFilePathRows(Database db) async {
    final rows = await db.query(
      'documents',
      columns: ['id', 'filePath'],
      orderBy: 'createdAt DESC, id DESC',
    );
    final seen = <String>{};
    for (final row in rows) {
      final id = row['id'] as int?;
      final filePath = (row['filePath'] as String?) ?? '';
      if (id == null || filePath.isEmpty) continue;
      if (seen.contains(filePath)) {
        await db.delete('documents', where: 'id = ?', whereArgs: [id]);
      } else {
        seen.add(filePath);
      }
    }
  }
}
