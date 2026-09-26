import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_management/models/expense.dart';
import 'package:pharmacy_management/models/expense_category.dart';
import 'package:pharmacy_management/providers/expense_provider.dart';
import 'package:pharmacy_management/screens/expenses_screen.dart';
import 'package:pharmacy_management/services/expense_report.dart';
import 'package:pharmacy_management/theme/app_theme.dart';

final _categories = [
  ExpenseCategory(id: 1, name: 'Salary', isActive: true),
  ExpenseCategory(id: 2, name: 'Rent', isActive: false),
];
List<Expense> _records() => [
      Expense(
          id: 1,
          categoryId: 1,
          amount: 10000,
          date: DateTime.now().toIso8601String(),
          subcategory: 'Permanent',
          staffName: 'Sample staff',
          item: 'Monthly salary'),
      Expense(
          id: 2,
          categoryId: 1,
          amount: 5000,
          date: DateTime.now().toIso8601String(),
          subcategory: 'Contract'),
      Expense(
          id: 3,
          categoryId: 1,
          amount: 100,
          date: DateTime.now().toIso8601String()),
      Expense(
          id: 4,
          categoryId: 2,
          amount: 3000,
          date: DateTime.now().toIso8601String(),
          subcategory: 'Permanent'),
      Expense(
          id: 5,
          categoryId: 1,
          amount: 2000,
          date: '2020-01-01',
          subcategory: ' permanent '),
    ];

class _Expenses extends ExpenseNotifier {
  @override
  Future<void> loadExpenses() async {
    state = AsyncValue.data(_records());
  }
}

void main() {
  test('export rows retain all fields and include salary staff', () {
    final rows = ExpenseReport.rows(
        [_records().first],
        _categories,
        NumberFormat.currency(symbol: '₹', decimalDigits: 0),
        DateFormat('yyyy-MM-dd'));
    expect(rows.single.length, ExpenseReport.headers.length);
    expect(rows.single[1], 'Salary');
    expect(rows.single[2], 'Permanent');
    expect(rows.single[4], 'Sample staff');
    expect(rows.single.last, '₹10,000');
    expect(ExpenseReport.rows([], _categories, NumberFormat(), DateFormat()),
        isEmpty);
  });
  testWidgets(
      'category, class, date and search combine; reset restores every record',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (const bool.fromEnvironment('HISAAB_CAPTURE')) {
      await tester.runAsync(() async {
        await (FontLoader('Inter')
              ..addFont(rootBundle
                  .load('assets/fonts/google_fonts/Inter-Regular.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      });
    }
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          expensesProvider.overrideWith((ref) => _Expenses()),
          allExpenseCategoriesProvider.overrideWith((ref) async => _categories),
        ],
        child:
            MaterialApp(theme: buildAppTheme(), home: const ExpensesScreen())));
    await tester.pumpAndSettle();
    expect(find.text('₹20,100'), findsWidgets);
    Future<void> category(String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> expenseClass(String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await category('Salary');
    expect(find.text('₹17,100'), findsWidgets);
    await expenseClass('permanent');
    expect(find.text('₹12,000'), findsWidgets);
    await tester.tap(find.byTooltip('Filter Expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Year'));
    await tester.pumpAndSettle();
    expect(find.text('₹10,000'), findsWidgets);
    if (const bool.fromEnvironment('HISAAB_CAPTURE')) {
      await expectLater(find.byType(ExpensesScreen),
          matchesGoldenFile('previews/expense-category-class-filters.png'));
    }
    expect(find.textContaining('Category: Salary • Class: permanent'),
        findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(900, 720));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'does not exist');
    await tester.pumpAndSettle();
    expect(find.text('₹0'), findsOneWidget);
    expect(find.text('No expenses match these filters'), findsOneWidget);
    await tester.tap(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    expect(find.text('₹20,100'), findsWidgets);
    await category('Salary');
    await expenseClass('No class');
    expect(find.text('₹100'), findsWidgets);
    await category('Rent');
    expect(find.text('All classes'), findsOneWidget);
    expect(find.text('₹3,000'), findsWidgets);
    await category('All categories');
    await expenseClass('permanent');
    expect(find.text('₹15,000'), findsWidgets);
    await expenseClass('All classes');
    expect(find.text('₹20,100'), findsWidgets);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
