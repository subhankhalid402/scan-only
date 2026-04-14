import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/receipt_data.dart';

class ReceiptExpenseService {
  ReceiptExpenseService._();
  static final ReceiptExpenseService instance = ReceiptExpenseService._();

  Future<File> _historyFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/ScanOnly/Receipts');
    await out.create(recursive: true);
    return File('${out.path}/expense_history.json');
  }

  Future<List<Map<String, dynamic>>> _readHistory() async {
    final file = await _historyFile();
    if (!await file.exists()) return [];
    final txt = await file.readAsString();
    if (txt.trim().isEmpty) return [];
    final decoded = jsonDecode(txt);
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> saveExpense(ReceiptData data) async {
    final list = await _readHistory();
    list.add({
      ...data.toJsonMap(),
      'saved_at': DateTime.now().toIso8601String(),
      'total_amount_num': data.totalAmount,
    });
    final file = await _historyFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
  }

  Future<bool> isDuplicate(ReceiptData data) async {
    final list = await _readHistory();
    final key = _dupKey(data);
    for (final e in list) {
      final k = '${e['store_name']}_${e['receipt_number']}_${e['grand_total']}_${e['purchase_datetime']}'
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      if (k == key) return true;
    }
    return false;
  }

  Future<Map<String, double>> monthlySpendingSummary({DateTime? month}) async {
    final m = month ?? DateTime.now();
    final start = DateTime(m.year, m.month, 1);
    final end = DateTime(m.year, m.month + 1, 1);
    final list = await _readHistory();
    final out = <String, double>{};
    for (final e in list) {
      final dt = DateTime.tryParse('${e['saved_at'] ?? ''}');
      if (dt == null || dt.isBefore(start) || !dt.isBefore(end)) continue;
      final cat = (e['category'] ?? 'Uncategorized').toString();
      final amount = (e['total_amount_num'] as num?)?.toDouble() ?? 0.0;
      out[cat] = (out[cat] ?? 0.0) + amount;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> searchExpenses({
    String query = '',
    String? dateContains,
    double? minAmount,
  }) async {
    final list = await _readHistory();
    return list.where((e) {
      final q = query.toLowerCase().trim();
      final store = (e['store_name'] ?? '').toString().toLowerCase();
      final receiptNo = (e['receipt_number'] ?? '').toString().toLowerCase();
      final dt = (e['purchase_datetime'] ?? '').toString().toLowerCase();
      final amount = (e['total_amount_num'] as num?)?.toDouble() ?? 0.0;
      final qPass = q.isEmpty || store.contains(q) || receiptNo.contains(q);
      final dPass = dateContains == null || dt.contains(dateContains.toLowerCase());
      final aPass = minAmount == null || amount >= minAmount;
      return qPass && dPass && aPass;
    }).toList();
  }

  String _dupKey(ReceiptData data) {
    return '${data.storeName}_${data.receiptNumber}_${data.grandTotal}_${data.purchaseDateTime}'
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
  }
}

