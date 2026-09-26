import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

/// Both export formats use exactly the filtered records shown on Expenses.
class ExpenseReport {
  static const headers = [
    'Date',
    'Category',
    'Class',
    'Item',
    'Staff',
    'Payment',
    'Comments',
    'Amount'
  ];

  static List<List<String>> rows(
      List<Expense> expenses,
      List<ExpenseCategory> categories,
      NumberFormat currency,
      DateFormat date) {
    final names = {
      for (final category in categories) category.id: category.name
    };
    return expenses
        .map((expense) => [
              date.format(DateTime.parse(expense.date)),
              names[expense.categoryId] ?? 'Unknown',
              expense.subcategory ?? '-',
              expense.item ?? '-',
              expense.staffName ?? '-',
              expense.paymentMethod == null
                  ? '-'
                  : expense.paymentMethod == 'other'
                      ? 'Other'
                      : 'Cash',
              expense.note ?? '-',
              currency.format(expense.amount),
            ])
        .toList();
  }
}
