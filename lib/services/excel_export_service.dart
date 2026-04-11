import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExcelExportService {
  static final ExcelExportService _instance = ExcelExportService._internal();

  factory ExcelExportService() {
    return _instance;
  }

  ExcelExportService._internal();

  static ExcelExportService get instance => _instance;

  Future<String> exportDocumentsToExcel(List<Map<String, dynamic>> documents) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add headers
      sheet.appendRow(['Document Name', 'Type', 'Size (MB)', 'Pages', 'Created Date', 'Modified Date']);

      // Add data
      for (var doc in documents) {
        sheet.appendRow([
          doc['name'] ?? 'Unknown',
          doc['fileType'] ?? 'N/A',
          doc['fileSizeMB']?.toStringAsFixed(2) ?? '0',
          doc['pageCount']?.toString() ?? '0',
          doc['createdAt']?.toString() ?? 'N/A',
          doc['modifiedAt']?.toString() ?? 'N/A',
        ]);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/ScanOnly_Documents_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      return filePath;
    } catch (e) {
      throw Exception('Excel export failed: $e');
    }
  }
}
