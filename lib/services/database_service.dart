import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document_model.dart';

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
      version: 2,
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
        tags TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  Future<int> insertDocument(DocumentModel doc) async {
    final db = await instance.database;
    return await db.insert('documents', doc.toMap());
  }

  Future<List<DocumentModel>> getAllDocuments() async {
    final db = await instance.database;
    final result = await db.query('documents', orderBy: 'createdAt DESC');
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

  Future<int> deleteDocument(int id) async {
    final db = await instance.database;
    return await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getDocumentCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM documents');
    return Sqflite.firstIntValue(result) ?? 0;
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
}
