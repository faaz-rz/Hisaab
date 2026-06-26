class Expense {
  final int? id;
  final int categoryId;
  final double amount;
  final String date;
  final String? subcategory;
  final String? item;
  final String? paymentMethod;
  final String? note;
  final String? staffName;

  Expense({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.subcategory,
    this.item,
    this.paymentMethod,
    this.note,
    this.staffName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'date': date,
      'subcategory': subcategory,
      'item': item,
      'payment_method': paymentMethod,
      'note': note,
      'staff_name': staffName,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      categoryId: map['category_id'],
      amount: map['amount'],
      date: map['date'],
      subcategory: map['subcategory'],
      item: map['item'],
      paymentMethod: map['payment_method'],
      note: map['note'],
      staffName: map['staff_name'],
    );
  }
}
