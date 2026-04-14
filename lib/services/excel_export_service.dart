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

  Future<String> exportReceiptsToExcel(List<Map<String, dynamic>> receipts) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Receipts'];
      TextCellValue cell(dynamic v) => TextCellValue(v?.toString() ?? '');

      sheet.appendRow([
        TextCellValue('Store'),
        TextCellValue('Date Time'),
        TextCellValue('Category'),
        TextCellValue('Currency'),
        TextCellValue('Grand Total'),
        TextCellValue('Payment Method'),
        TextCellValue('Receipt No'),
        TextCellValue('NTN'),
        TextCellValue('GST'),
        TextCellValue('FBR QR Valid'),
      ]);

      for (final r in receipts) {
        sheet.appendRow([
          cell(r['store_name']),
          cell(r['purchase_datetime']),
          cell(r['category']),
          cell(r['currency']),
          cell(r['grand_total']),
          cell(r['payment_method']),
          cell(r['receipt_number']),
          cell(r['ntn_number']),
          cell(r['gst_number']),
          cell(r['fbr_qr_valid']),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/ScanOnly_Receipts_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      return filePath;
    } catch (e) {
      throw Exception('Receipt Excel export failed: $e');
    }
  }

  Future<String> exportVehicleRcToExcel(List<Map<String, dynamic>> records) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Vehicle_RC'];
      TextCellValue cell(dynamic v) => TextCellValue(v?.toString() ?? '');

      sheet.appendRow([
        TextCellValue('Registration No'),
        TextCellValue('Owner Name'),
        TextCellValue('CNIC'),
        TextCellValue('Engine No'),
        TextCellValue('Chassis No'),
        TextCellValue('Make/Model'),
        TextCellValue('Year'),
        TextCellValue('Fuel'),
        TextCellValue('Token Tax Status'),
        TextCellValue('Token Due Date'),
        TextCellValue('Fitness Expiry'),
        TextCellValue('Province/City'),
      ]);

      for (final r in records) {
        sheet.appendRow([
          cell(r['registration_number']),
          cell(r['owner_name']),
          cell(r['cnic_number']),
          cell(r['engine_number']),
          cell(r['chassis_number']),
          cell(r['make_model']),
          cell(r['manufacturing_year']),
          cell(r['fuel_type']),
          cell(r['token_tax_status']),
          cell(r['token_tax_due_date']),
          cell(r['fitness_expiry']),
          cell(r['province_city']),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/ScanOnly_VehicleRC_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      return filePath;
    } catch (e) {
      throw Exception('Vehicle RC Excel export failed: $e');
    }
  }

  Future<String> exportBankStatementToExcel({
    required Map<String, dynamic> statement,
    required List<Map<String, dynamic>> transactions,
  }) async {
    try {
      final excel = Excel.createExcel();
      final summary = excel['Summary'];
      final tx = excel['Transactions'];
      TextCellValue cell(dynamic v) => TextCellValue(v?.toString() ?? '');

      summary.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
      for (final entry in statement.entries) {
        summary.appendRow([cell(entry.key), cell(entry.value)]);
      }

      tx.appendRow([
        TextCellValue('Date'),
        TextCellValue('Description'),
        TextCellValue('Debit'),
        TextCellValue('Credit'),
        TextCellValue('Balance'),
        TextCellValue('Reference'),
        TextCellValue('Category'),
      ]);
      for (final t in transactions) {
        tx.appendRow([
          cell(t['date']),
          cell(t['description']),
          cell(t['debit']),
          cell(t['credit']),
          cell(t['balance']),
          cell(t['reference']),
          cell(t['category']),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/ScanOnly_BankStatement_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      return filePath;
    } catch (e) {
      throw Exception('Bank statement Excel export failed: $e');
    }
  }

  Future<String> exportTableToExcel({
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Table'];
      TextCellValue cell(dynamic v) => TextCellValue(v?.toString() ?? '');

      if (headers.isNotEmpty) {
        sheet.appendRow(headers.map(cell).toList());
      }
      for (final r in rows) {
        sheet.appendRow(r.map(cell).toList());
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/ScanOnly_Table_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      return filePath;
    } catch (e) {
      throw Exception('Table Excel export failed: $e');
    }
  }
}
