class ExpenseCategory {
  final int? id;
  final String name;
  final bool isActive;

  ExpenseCategory({
    this.id,
    required this.name,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
