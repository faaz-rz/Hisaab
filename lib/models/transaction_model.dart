class TransactionModel {
  final int? id;

  /// Types: sale, purchase_cash, purchase_credit, sales_return, credit_note
  final String type;
  final String date;
  final double totalAmount;
  final double? upiAmount; // For Sales
  final String? agencyName; // For Purchases/Returns
  final String? agencyCode;
  final String? billNo;
  final String? originalBillNo; // For returns & credit notes

  // New fields
  final double? profit; // Sales
  final double? discount; // Sales
  final String? adjustmentDetails; // Credit Note
  final String? billDate; // Purchases
  final String? paymentMethod; // Credit payments: cash or upi
  final String? receiptNo; // Cash receipt number

  /// How much of this credit purchase has been paid back
  final double paidAmount;

  TransactionModel({
    this.id,
    required this.type,
    required this.date,
    required this.totalAmount,
    this.upiAmount,
    this.agencyName,
    this.agencyCode,
    this.billNo,
    this.originalBillNo,
    this.profit,
    this.discount,
    this.adjustmentDetails,
    this.billDate,
    this.paymentMethod,
    this.receiptNo,
    this.paidAmount = 0,
  });

  /// Whether this credit purchase is fully paid
  bool get isPaid => type == 'purchase_credit' && paidAmount >= totalAmount;

  /// Remaining unpaid amount for a credit purchase
  double get remainingAmount => totalAmount - paidAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'date': date,
      'total_amount': totalAmount,
      'upi_amount': upiAmount,
      'agency_name': agencyName,
      'agency_code': agencyCode,
      'bill_no': billNo,
      'original_bill_no': originalBillNo,
      'profit': profit,
      'discount': discount,
      'adjustment_details': adjustmentDetails,
      'bill_date': billDate,
      'payment_method': paymentMethod,
      'receipt_no': receiptNo,
      'paid_amount': paidAmount,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      type: map['type'],
      date: map['date'],
      totalAmount: map['total_amount'],
      upiAmount: map['upi_amount'],
      agencyName: map['agency_name'],
      agencyCode: map['agency_code'],
      billNo: map['bill_no'],
      originalBillNo: map['original_bill_no'],
      profit: map['profit'],
      discount: map['discount'],
      adjustmentDetails: map['adjustment_details'],
      billDate: map['bill_date'],
      paymentMethod: map['payment_method'],
      receiptNo: map['receipt_no'],
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
