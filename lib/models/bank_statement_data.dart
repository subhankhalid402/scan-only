class BankTransaction {
  final String date;
  final String description;
  final String debit;
  final String credit;
  final String balance;
  final String reference;
  final String category;

  const BankTransaction({
    this.date = '',
    this.description = '',
    this.debit = '',
    this.credit = '',
    this.balance = '',
    this.reference = '',
    this.category = 'Other',
  });

  BankTransaction copyWith({
    String? date,
    String? description,
    String? debit,
    String? credit,
    String? balance,
    String? reference,
    String? category,
  }) {
    return BankTransaction(
      date: date ?? this.date,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      reference: reference ?? this.reference,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'description': description,
        'debit': debit,
        'credit': credit,
        'balance': balance,
        'reference': reference,
        'category': category,
      };
}

class BankStatementData {
  final String accountHolderName;
  final String accountNumber;
  final String iban;
  final String bankName;
  final String branch;
  final String statementFrom;
  final String statementTo;
  final String openingBalance;
  final String closingBalance;
  final String currency;
  final List<BankTransaction> transactions;
  final String rawText;

  const BankStatementData({
    this.accountHolderName = '',
    this.accountNumber = '',
    this.iban = '',
    this.bankName = '',
    this.branch = '',
    this.statementFrom = '',
    this.statementTo = '',
    this.openingBalance = '',
    this.closingBalance = '',
    this.currency = 'PKR',
    this.transactions = const [],
    this.rawText = '',
  });

  BankStatementData copyWith({
    String? accountHolderName,
    String? accountNumber,
    String? iban,
    String? bankName,
    String? branch,
    String? statementFrom,
    String? statementTo,
    String? openingBalance,
    String? closingBalance,
    String? currency,
    List<BankTransaction>? transactions,
    String? rawText,
  }) {
    return BankStatementData(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      statementFrom: statementFrom ?? this.statementFrom,
      statementTo: statementTo ?? this.statementTo,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      currency: currency ?? this.currency,
      transactions: transactions ?? this.transactions,
      rawText: rawText ?? this.rawText,
    );
  }

  double get totalCredits =>
      transactions.fold(0.0, (a, b) => a + _num(b.credit));
  double get totalDebits =>
      transactions.fold(0.0, (a, b) => a + _num(b.debit));

  double get averageMonthlyBalance {
    final vals = transactions
        .map((e) => _num(e.balance))
        .where((e) => e > 0)
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  List<BankTransaction> get largestTransactions {
    final copy = List<BankTransaction>.from(transactions);
    copy.sort((a, b) {
      final va = _num(a.debit) + _num(a.credit);
      final vb = _num(b.debit) + _num(b.credit);
      return vb.compareTo(va);
    });
    return copy.take(5).toList();
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'iban': iban,
      'bank_name': bankName,
      'branch': branch,
      'statement_from': statementFrom,
      'statement_to': statementTo,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'currency': currency,
      'total_credits': totalCredits,
      'total_debits': totalDebits,
      'average_monthly_balance': averageMonthlyBalance,
      'transactions': transactions.map((e) => e.toMap()).toList(),
      'raw_text': rawText,
    };
  }

  static double _num(String t) {
    final m = RegExp(r'(\d+(?:[.,]\d{1,2})?)')
        .firstMatch(t.replaceAll(',', ''));
    return m == null ? 0 : (double.tryParse(m.group(1) ?? '') ?? 0);
  }
}

