import '../models/bank_statement_data.dart';
import 'ocr_service.dart';

class BankStatementOcrService {
  BankStatementOcrService._();
  static final BankStatementOcrService instance = BankStatementOcrService._();

  Future<BankStatementData> extractFromPages(List<String> imagePaths) async {
    final lines = <String>[];
    for (final p in imagePaths) {
      final txt = await OcrService.instance.extractText(p);
      if (txt.trim().isNotEmpty) {
        lines.addAll(txt.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
    }
    final merged = lines.join('\n');

    String byLabel(List<String> labels) {
      for (final line in lines) {
        final low = line.toLowerCase();
        for (final l in labels) {
          if (!low.contains(l.toLowerCase())) continue;
          final v = line.replaceAll(RegExp('(?i)$l'), '').replaceAll(':', '').trim();
          if (v.isNotEmpty) return v;
        }
      }
      return '';
    }

    String detectBankName() {
      final t = merged.toLowerCase();
      if (t.contains('habib bank') || t.contains('hbl')) return 'HBL';
      if (t.contains('mcb')) return 'MCB';
      if (t.contains('ubl') || t.contains('united bank')) return 'UBL';
      if (t.contains('meezan')) return 'Meezan Bank';
      if (t.contains('allied')) return 'Allied Bank';
      return byLabel(const ['bank']) ;
    }

    String iban() {
      final m = RegExp(r'\bPK\d{2}[A-Z]{4}[A-Z0-9]{16}\b')
          .firstMatch(merged.replaceAll(' ', '').toUpperCase());
      return m?.group(0) ?? '';
    }

    String accountNo() {
      final by = byLabel(const ['account no', 'account number', 'a/c no']);
      if (by.isNotEmpty) return by;
      final m = RegExp(r'\b\d{10,20}\b').firstMatch(merged);
      return m?.group(0) ?? '';
    }

    String currency() {
      final t = merged.toUpperCase();
      if (t.contains('PKR') || t.contains('RS')) return 'PKR';
      if (t.contains('USD') || t.contains(r'$')) return 'USD';
      if (t.contains('EUR')) return 'EUR';
      return 'PKR';
    }

    (String, String) period() {
      final dateMatches = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b')
          .allMatches(merged)
          .map((e) => e.group(0) ?? '')
          .toList();
      if (dateMatches.length >= 2) return (dateMatches.first, dateMatches.last);
      final byFrom = byLabel(const ['from']);
      final byTo = byLabel(const ['to']);
      return (byFrom, byTo);
    }

    String amountByLabel(List<String> labels) {
      for (final line in lines) {
        final low = line.toLowerCase();
        if (!labels.any((l) => low.contains(l))) continue;
        final ms = RegExp(r'(\d+(?:[.,]\d{1,2})?)')
            .allMatches(line.replaceAll(',', ''))
            .toList();
        if (ms.isNotEmpty) return ms.last.group(1) ?? '';
      }
      return '';
    }

    String categorize(String desc) {
      final d = desc.toLowerCase();
      if (d.contains('salary')) return 'Salary';
      if (d.contains('ke') || d.contains('lesco') || d.contains('gas') || d.contains('utility')) return 'Utilities';
      if (d.contains('daraz') || d.contains('market') || d.contains('mart') || d.contains('shop')) return 'Shopping';
      if (d.contains('ibft') || d.contains('raast') || d.contains('transfer')) return 'Transfer';
      if (d.contains('tax') || d.contains('fbr') || d.contains('withholding')) return 'Tax';
      return 'Other';
    }

    List<BankTransaction> txns() {
      final out = <BankTransaction>[];
      final dateRegex = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b');
      final amtRegex = RegExp(r'(\d+(?:[.,]\d{1,2})?)');
      for (final line in lines) {
        final date = dateRegex.firstMatch(line)?.group(0) ?? '';
        if (date.isEmpty) continue;
        final nums = amtRegex
            .allMatches(line.replaceAll(',', ''))
            .map((m) => m.group(1) ?? '')
            .toList();
        if (nums.isEmpty) continue;
        final ref = RegExp(r'\b(?:IBFT|RAAST|TRX|REF|TXN)[A-Z0-9\-]*\b', caseSensitive: false)
            .firstMatch(line)
            ?.group(0) ??
            '';
        final desc = line.replaceAll(date, '').replaceAll(RegExp(r'\d+(?:[.,]\d{1,2})?'), '').trim();
        String debit = '';
        String credit = '';
        String balance = '';
        if (nums.length >= 3) {
          debit = nums[0];
          credit = nums[1];
          balance = nums[2];
        } else if (nums.length == 2) {
          debit = nums[0];
          balance = nums[1];
        } else {
          balance = nums.first;
        }
        out.add(BankTransaction(
          date: date,
          description: desc,
          debit: debit,
          credit: credit,
          balance: balance,
          reference: ref,
          category: categorize('$desc $ref'),
        ));
      }
      return out;
    }

    final pr = period();
    return BankStatementData(
      accountHolderName: byLabel(const ['account title', 'account holder', 'name']),
      accountNumber: accountNo(),
      iban: iban(),
      bankName: detectBankName(),
      branch: byLabel(const ['branch']),
      statementFrom: pr.$1,
      statementTo: pr.$2,
      openingBalance: amountByLabel(const ['opening balance', 'open balance']),
      closingBalance: amountByLabel(const ['closing balance', 'close balance']),
      currency: currency(),
      transactions: txns(),
      rawText: merged,
    );
  }
}

