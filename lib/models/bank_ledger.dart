class BankLedger {
  final int? id;
  /// Types: deposit, withdrawal
  final String type;
  final String bankName;
  final String? bankCode;
  final String? accountNo;
  final double amount;
  final String date;
  final String? purpose; // Mandatory for withdrawals

  BankLedger({
    this.id,
    required this.type,
    required this.bankName,
    this.bankCode,
    this.accountNo,
    required this.amount,
    required this.date,
    this.purpose,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'bank_name': bankName,
      'bank_code': bankCode,
      'account_no': accountNo,
      'amount': amount,
      'date': date,
      'purpose': purpose,
    };
  }

  factory BankLedger.fromMap(Map<String, dynamic> map) {
    return BankLedger(
      id: map['id'],
      type: map['type'],
      bankName: map['bank_name'],
      bankCode: map['bank_code'],
      accountNo: map['account_no'],
      amount: map['amount'],
      date: map['date'],
      purpose: map['purpose'],
    );
  }
}
