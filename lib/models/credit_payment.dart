class CreditPayment {
  final int? id;
  final int transactionId; // Links to the credit purchase transaction
  final String date;
  final double amount;

  CreditPayment({
    this.id,
    required this.transactionId,
    required this.date,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'date': date,
      'amount': amount,
    };
  }

  factory CreditPayment.fromMap(Map<String, dynamic> map) {
    return CreditPayment(
      id: map['id'],
      transactionId: map['transaction_id'],
      date: map['date'],
      amount: map['amount'],
    );
  }
}
