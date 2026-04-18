import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shares local files via the system sheet.
///
/// On Android, Flutter stores documents under `app_flutter/`, which is often
/// **outside** `FileProvider` roots in `file_paths.xml`. [Share.shareXFiles]
/// then fails to attach bytes and targets may only see the caption text.
/// This helper copies into the app cache (always provider-backed) before sharing.
class ShareFileService {
  ShareFileService._();

  static String? _mimeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.json':
        return 'application/json';
      case '.csv':
        return 'text/csv';
      case '.txt':
        return 'text/plain';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.epub':
        return 'application/epub+zip';
      case '.zip':
        return 'application/zip';
      case '.html':
      case '.htm':
        return 'text/html';
      default:
        return 'application/octet-stream';
    }
  }

  /// Shares one or more existing files (copies to cache first when needed).
  /// Returns how many files were attached (0 if none could be read).
  static Future<int> sharePaths(
    List<String> paths, {
    String? text,
    String? subject,
  }) async {
    if (paths.isEmpty) return 0;
    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final xFiles = <XFile>[];
    var i = 0;
    for (final path in paths) {
      if (path.isEmpty) continue;
      final src = File(path);
      if (!await src.exists()) continue;
      var base = p.basename(path);
      if (base.isEmpty) base = 'file_$i';
      base = base.replaceAll(RegExp(r'[/\\]'), '_');
      final destPath = p.join(tempDir.path, 'scanonly_share_${stamp}_${i}_$base');
      await src.copy(destPath);
      xFiles.add(XFile(
        destPath,
        name: base,
        mimeType: _mimeForPath(destPath),
      ));
      i++;
    }
    if (xFiles.isEmpty) return 0;

    // Many targets (e.g. WhatsApp) treat `text` as the main payload and drop or
    // mishandle the file when both are sent. Only pass non-empty strings.
    // With multiple attachments, omit caption so all files are delivered reliably.
    final multi = xFiles.length > 1;
    final t = multi ? null : _nullIfBlank(text);
    final s = multi ? null : _nullIfBlank(subject);
    await Share.shareXFiles(xFiles, text: t, subject: s);
    return xFiles.length;
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final v = value.trim();
    return v.isEmpty ? null : v;
  }
}
