import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';
import 'database_service.dart';
import 'pdf_service.dart';

class SmartGalleryService {
  SmartGalleryService._();
  static final SmartGalleryService instance = SmartGalleryService._();

  Future<List<DocumentModel>> loadAll() => DatabaseService.instance.getAllDocuments();

  String categoryFor(DocumentModel d) {
    switch (d.scanType) {
      case 'document':
        return 'Documents';
      case 'id_card':
        return 'ID Cards';
      case 'passport':
        return 'Passports';
      case 'receipt':
        return 'Receipts';
      case 'driving_license':
        return 'Licenses';
      case 'book':
        return 'Books';
      case 'whiteboard':
        return 'Whiteboards';
      case 'photo':
        return 'Photos';
      case 'qr':
        return 'QR Codes';
      default:
        return 'Others';
    }
  }

  Map<DateTime, List<DocumentModel>> groupByScanDate(List<DocumentModel> docs) {
    final map = <DateTime, List<DocumentModel>>{};
    for (final d in docs) {
      final key = DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day);
      map.putIfAbsent(key, () => []).add(d);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  double totalStorageMB(List<DocumentModel> docs) {
    var sum = 0.0;
    for (final d in docs) {
      sum += d.fileSizeMB;
    }
    return sum;
  }

  List<List<DocumentModel>> detectDuplicates(List<DocumentModel> docs) {
    final byKey = <String, List<DocumentModel>>{};
    for (final d in docs) {
      final name = d.name.toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), '');
      final key = '$name|${d.fileSizeMB.toStringAsFixed(3)}|${d.pageCount}';
      byKey.putIfAbsent(key, () => []).add(d);
    }
    return byKey.values.where((g) => g.length > 1).toList();
  }

  Future<String?> exportZip(List<DocumentModel> docs) async {
    if (docs.isEmpty) return null;
    final archive = Archive();
    for (final d in docs) {
      final f = File(d.filePath);
      if (!await f.exists()) continue;
      final bytes = await f.readAsBytes();
      final ext = p.extension(d.filePath).toLowerCase();
      final safe = d.name.replaceAll(RegExp(r'[^\w\-\.\s\(\)]'), '_');
      archive.addFile(ArchiveFile('${d.id ?? ''}_$safe$ext', bytes.length, bytes));
    }
    if (archive.isEmpty) return null;
    final tmp = await getTemporaryDirectory();
    final out = File('${tmp.path}/smart_gallery_${DateTime.now().millisecondsSinceEpoch}.zip');
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) return null;
    await out.writeAsBytes(encoded);
    return out.path;
  }

  Future<String?> mergeAsPdf(List<DocumentModel> docs) async {
    if (docs.isEmpty) return null;
    final pdfs = <String>[];
    final images = <String>[];
    for (final d in docs) {
      final ft = d.fileType.toLowerCase();
      if (ft == 'pdf') {
        pdfs.add(d.filePath);
      } else if (ft == 'jpg' || ft == 'jpeg' || ft == 'png' || ft == 'webp') {
        images.add(d.filePath);
      }
    }
    if (pdfs.isEmpty && images.isEmpty) return null;
    if (pdfs.isNotEmpty && images.isEmpty) {
      return PdfService.instance.mergePdfFiles(pdfs, 'Merged');
    }
    if (pdfs.isEmpty && images.isNotEmpty) {
      return PdfService.instance.createPdfFromImages(images, 'Merged');
    }
    final imgPdf = await PdfService.instance.createPdfFromImages(images, 'MergedImages');
    return PdfService.instance.mergePdfFiles([...pdfs, imgPdf], 'Merged');
  }

  Future<int> cleanupOldTempFiles({int olderThanDays = 7}) async {
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    var deleted = 0;
    for (final e in dir.listSync()) {
      if (e is! File) continue;
      try {
        final stat = await e.stat();
        if (stat.modified.isBefore(cutoff)) {
          await e.delete();
          deleted++;
        }
      } catch (_) {}
    }
    return deleted;
  }

  Future<void> applyTag(List<DocumentModel> docs, String tag) async {
    for (final d in docs) {
      if (d.id == null) continue;
      final tags = List<String>.from(d.tags);
      if (!tags.contains(tag)) tags.add(tag);
      await DatabaseService.instance.updateTags(d.id!, tags);
    }
  }
}

