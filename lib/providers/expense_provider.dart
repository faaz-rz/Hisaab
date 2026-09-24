import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../services/database_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/entry_service.dart';

final expenseCategoriesProvider =
    FutureProvider<List<ExpenseCategory>>((ref) async {
  final db = await DatabaseService.instance.database;
  final maps = await db.query('expense_categories', where: 'is_active = 1');
  return maps.map((e) => ExpenseCategory.fromMap(e)).toList();
});

final allExpenseCategoriesProvider =
    FutureProvider<List<ExpenseCategory>>((ref) async {
  final db = await DatabaseService.instance.database;
  final maps = await db.query('expense_categories');
  return maps.map((e) => ExpenseCategory.fromMap(e)).toList();
});

final expensesProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>((ref) {
  return ExpenseNotifier();
});

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  ExpenseNotifier() : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final db = await DatabaseService.instance.database;
      final maps = await db.query('expenses', orderBy: 'date DESC');
      final expenses = maps.map((e) => Expense.fromMap(e)).toList();
      state = AsyncValue.data(expenses);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addExpense(Expense expense, {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.database;
    await EntryService.save(db, 'expenses', expense.toMap(),
        allowDuplicate: allowDuplicate);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadExpenses();
  }

  Future<void> updateExpense(Expense expense, {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.database;
    await EntryService.save(db, 'expenses', expense.toMap(),
        allowDuplicate: allowDuplicate);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadExpenses();
  }
}

class ExpenseRepository {
  static Future<List<String>> getClassesForCategory(int categoryId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT TRIM(subcategory) AS class_name
      FROM expenses
      WHERE category_id = ?
        AND subcategory IS NOT NULL
        AND TRIM(subcategory) != ''
      ORDER BY class_name COLLATE NOCASE ASC
      ''',
      [categoryId],
    );

    return rows
        .map((row) => (row['class_name'] as String?)?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static Future<List<String>> getItemsForCategoryClass({
    required int categoryId,
    String? expenseClass,
  }) async {
    final db = await DatabaseService.instance.database;
    final normalizedClass = expenseClass?.trim() ?? '';
    final classFilter = normalizedClass.isEmpty
        ? "AND (subcategory IS NULL OR TRIM(subcategory) = '')"
        : 'AND LOWER(TRIM(subcategory)) = LOWER(?)';
    final args = <Object?>[categoryId];
    if (normalizedClass.isNotEmpty) args.add(normalizedClass);

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT TRIM(item) AS item_name
      FROM expenses
      WHERE category_id = ?
        $classFilter
        AND item IS NOT NULL
        AND TRIM(item) != ''
      ORDER BY item_name COLLATE NOCASE ASC
      ''',
      args,
    );

    return rows
        .map((row) => (row['item_name'] as String?)?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }
}

// Category Management methods (outside of the basic Provider for simpler access)
enum CategoryDeleteResult { deleted, hidden }

class CategoryRepository {
  static Future<ExpenseCategory> addCategory(String name) async {
    final db = await DatabaseService.instance.database;
    final normalizedName = name.trim();
    final existing = await db.query(
      'expense_categories',
      where: 'name = ?',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final existingRow = Map<String, dynamic>.from(existing.first);
      await db.update(
        'expense_categories',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [existingRow['id']],
      );
      await CloudSyncService.instance.pushLocalIfEnabled();
      existingRow['is_active'] = 1;
      return ExpenseCategory.fromMap(existingRow);
    }

    final cat = ExpenseCategory(
      name: normalizedName,
      isActive: true,
    );
    final id = await db.insert('expense_categories', cat.toMap());
    await CloudSyncService.instance.pushLocalIfEnabled();
    return ExpenseCategory(id: id, name: normalizedName, isActive: true);
  }

  static Future<CategoryDeleteResult> deleteCategory(int id) async {
    final db = await DatabaseService.instance.database;
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM expenses WHERE category_id = ?',
      [id],
    );
    final usageCount = (countRows.first['total'] as int?) ?? 0;

    if (usageCount == 0) {
      await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
      await CloudSyncService.instance.pushLocalIfEnabled();
      return CategoryDeleteResult.deleted;
    }

    await db.update(
      'expense_categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await CloudSyncService.instance.pushLocalIfEnabled();
    return CategoryDeleteResult.hidden;
  }
}
