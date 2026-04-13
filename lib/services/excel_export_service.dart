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

      TextCellValue cell(dynamic v) => TextCellValue(v?.toString() ?? '');

      // Add headers
      sheet.appendRow([
        TextCellValue('Document Name'),
        TextCellValue('Type'),
        TextCellValue('Size (MB)'),
        TextCellValue('Pages'),
        TextCellValue('Created Date'),
        TextCellValue('Modified Date'),
      ]);

      // Add data
      for (final doc in documents) {
        final size = doc['fileSizeMB'];
        sheet.appendRow([
          cell(doc['name'] ?? 'Unknown'),
          cell(doc['fileType'] ?? 'N/A'),
          TextCellValue(
            size is num ? size.toStringAsFixed(2) : (size?.toString() ?? '0'),
          ),
          cell(doc['pageCount'] ?? '0'),
          cell(doc['createdAt'] ?? 'N/A'),
          cell(doc['modifiedAt'] ?? 'N/A'),
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
