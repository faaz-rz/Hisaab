import 'package:flutter/material.dart';
import '../widgets/workspace_components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../widgets/add_expense_dialog.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../mixins/date_filter_mixin.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_service.dart';
import '../services/expense_report.dart';
import '../main.dart';

class _CategoryExpenseSummary {
  final int categoryId;
  final String categoryName;
  double amount = 0;
  int count = 0;

  _CategoryExpenseSummary({
    required this.categoryId,
    required this.categoryName,
  });
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with DateFilterMixin<ExpensesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _categoryId;
  String? _expenseClass;

  String _classKey(String? value) => (value ?? '').trim().toLowerCase();

  bool _matchesFilters(Expense expense) {
    if (_categoryId != null && expense.categoryId != _categoryId) return false;
    if (_expenseClass != null &&
        _classKey(expense.subcategory) != _expenseClass) return false;
    if (dateRange == null) return true;
    final date = DateTime.tryParse(expense.date);
    if (date == null) return false;
    final day = DateTime(date.year, date.month, date.day);
    final start = dateRange!.start;
    final end = dateRange!.end;
    return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
        !day.isAfter(DateTime(end.year, end.month, end.day));
  }

  String _reportLabel(DateFormat fmtDate, List<ExpenseCategory> categories) => [
        _periodLabel(fmtDate),
        'Category: ${_categoryId == null ? 'All categories' : _categoryNameFor(_categoryId!, categories)}',
        'Class: ${_expenseClass == null ? 'All classes' : _expenseClass!.isEmpty ? 'No class' : _expenseClass}',
        if (_searchQuery.trim().isNotEmpty) 'Search: ${_searchQuery.trim()}',
      ].join(' • ');

  Widget _filters(List<Expense> allExpenses, List<ExpenseCategory> categories) {
    final categoryNames = <int, String>{
      for (final category in categories)
        if (category.id != null) category.id!: category.name,
      for (final expense in allExpenses)
        expense.categoryId: _categoryNameFor(expense.categoryId, categories),
      if (_categoryId != null)
        _categoryId!: _categoryNameFor(_categoryId!, categories),
    };
    final categoryOptions = categoryNames.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final classes = <String, String>{
      for (final expense in allExpenses)
        if (_categoryId == null || expense.categoryId == _categoryId)
          _classKey(expense.subcategory): (expense.subcategory ?? '').trim(),
      if (_expenseClass != null) _expenseClass!: _expenseClass!,
    };
    final classOptions = classes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 540
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: width,
              child: DropdownButtonFormField<int>(
                key: ValueKey('expense-category-$_categoryId'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category filter'),
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text('All categories')),
                  for (final option in categoryOptions)
                    DropdownMenuItem(
                        value: option.key,
                        child:
                            Text(option.value, overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) => setState(() {
                  _categoryId = value;
                  _expenseClass = null;
                }),
              )),
          SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: ValueKey('expense-class-$_categoryId-$_expenseClass'),
                initialValue: _expenseClass,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class filter'),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('All classes')),
                  for (final option in classOptions)
                    DropdownMenuItem(
                        value: option.key,
                        child: Text(
                            option.key.isEmpty ? 'No class' : option.value,
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) => setState(() => _expenseClass = value),
              )),
          if (_categoryId != null ||
              _expenseClass != null ||
              dateRange != null ||
              _searchQuery.isNotEmpty)
            TextButton.icon(
                onPressed: () => setState(() {
                      _categoryId = null;
                      _expenseClass = null;
                      dateRange = null;
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear all filters')),
        ]);
      }),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ExpenseCategory? _categoryFor(
    int categoryId,
    List<ExpenseCategory> categories,
  ) {
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  String _categoryNameFor(int categoryId, List<ExpenseCategory> categories) {
    final category = _categoryFor(categoryId, categories);
    if (category != null) return category.name;
    return 'Unknown';
  }

  bool _matchesSearch(Expense expense, List<ExpenseCategory> categories) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final category = _categoryNameFor(expense.categoryId, categories);
    final payment = expense.paymentMethod == null
        ? ''
        : expense.paymentMethod == 'other'
            ? 'other'
            : 'cash';
    final fields = [
      category,
      expense.subcategory,
      expense.item,
      expense.note,
      expense.staffName,
      payment,
      expense.amount.toStringAsFixed(0),
      expense.date,
    ];

    return fields
        .whereType<String>()
        .any((value) => value.toLowerCase().contains(query));
  }

  List<List<String>> _expenseExportData({
    required List<Expense> expenses,
    required List<ExpenseCategory> categories,
    required NumberFormat fmt,
    required DateFormat fmtDate,
  }) {
    return ExpenseReport.rows(expenses, categories, fmt, fmtDate);
  }

  Future<void> _confirmDeleteExpense(
      Expense expense, String categoryName) async {
    final confirmed = await confirmDeleteDialog(
      context,
      title: 'Delete Expense',
      message: 'This expense will be permanently removed.',
      details: '$categoryName • ₹${expense.amount.toStringAsFixed(0)}',
    );
    if (!confirmed || !mounted || expense.id == null) return;
    await ref.read(expensesProvider.notifier).deleteExpense(expense.id!);
  }

  List<_CategoryExpenseSummary> _buildCategorySummaries(
    List<Expense> expenses,
    List<ExpenseCategory> categories,
  ) {
    final summaries = <int, _CategoryExpenseSummary>{};

    for (final expense in expenses) {
      final summary = summaries.putIfAbsent(
        expense.categoryId,
        () => _CategoryExpenseSummary(
          categoryId: expense.categoryId,
          categoryName: _categoryNameFor(expense.categoryId, categories),
        ),
      );
      summary.amount += expense.amount;
      summary.count += 1;
    }

    final sorted = summaries.values.toList()
      ..sort((a, b) {
        final amountCompare = b.amount.compareTo(a.amount);
        if (amountCompare != 0) return amountCompare;
        return a.categoryName
            .toLowerCase()
            .compareTo(b.categoryName.toLowerCase());
      });
    return sorted;
  }

  String _periodLabel(DateFormat fmtDate) {
    return periodLabel(fmtDate, allLabel: 'Up to date');
  }

  void _showCategoryBillsSheet(
    BuildContext context, {
    required _CategoryExpenseSummary summary,
    required List<Expense> expenses,
    required NumberFormat fmt,
    required DateFormat fmtDate,
  }) {
    final bills = expenses
        .where((expense) => expense.categoryId == summary.categoryId)
        .toList()
      ..sort((a, b) {
        final dateCompare =
            DateTime.parse(b.date).compareTo(DateTime.parse(a.date));
        if (dateCompare != 0) return dateCompare;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.70,
          minChildSize: 0.40,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: AppColors.danger, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.categoryName,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_periodLabel(fmtDate)} • ${bills.length} bill${bills.length == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category Total',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          fmt.format(summary.amount),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: bills.length,
                      itemBuilder: (context, index) {
                        final bill = bills[index];
                        final hasClass = bill.subcategory != null &&
                            bill.subcategory!.trim().isNotEmpty;
                        final hasItem =
                            bill.item != null && bill.item!.trim().isNotEmpty;
                        final hasComments =
                            bill.note != null && bill.note!.trim().isNotEmpty;
                        final paymentLabel = bill.paymentMethod == null
                            ? '-'
                            : bill.paymentMethod == 'other'
                                ? 'Other'
                                : 'Cash';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_rounded,
                                    color: AppColors.danger, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fmtDate.format(DateTime.parse(bill.date)),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (hasClass)
                                      Text(
                                        'Class: ${bill.subcategory!.trim()}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (hasItem)
                                      Text(
                                        'Item: ${bill.item!.trim()}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      'Payment: $paymentLabel',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (hasComments)
                                      Text(
                                        'Comments: ${bill.note!.trim()}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                fmt.format(bill.amount),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final categoriesAsync = ref.watch(allExpenseCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const PageHeading(
            title: 'Expenses',
            subtitle: 'Track spending, categories & everyday costs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Expenses',
            onSelected: handleDateFilterSelection,
            itemBuilder: (context) => buildFilterMenu(allLabel: 'Up to Date'),
          ),
          if (dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: clearDateRange,
              tooltip: 'Clear Filter',
            ),
        ],
      ),
      body: expensesAsync.when(
        data: (allExpenses) {
          final categories = categoriesAsync.valueOrNull ?? [];
          final expenses = allExpenses
              .where(_matchesFilters)
              .where((e) => _matchesSearch(e, categories))
              .toList();
          if (allExpenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No expenses recorded',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
          final fmtDate = DateFormat('EEE, MMM dd, yyyy');
          final double totalExpenses =
              expenses.fold(0, (sum, e) => sum + e.amount);

          return Column(
            children: [
              // ─── Summary Bar ───
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: AdaptiveSummaryRow(
                  summary: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Expenses',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(fmt.format(totalExpenses),
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger)),
                      const SizedBox(height: 2),
                      Text(_reportLabel(fmtDate, categories),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final catsAsyncValue =
                              ref.read(allExpenseCategoriesProvider);
                          final cats = catsAsyncValue.valueOrNull ?? [];
                          final data = _expenseExportData(
                            expenses: expenses,
                            categories: cats,
                            fmt: fmt,
                            fmtDate: fmtDate,
                          );

                          await PdfService.generateAndPrintPdf(
                            title: 'Expenses Report',
                            subtitle: _reportLabel(fmtDate, categories),
                            headers: ExpenseReport.headers,
                            data: data,
                            totalAmountLabel: 'Total Expenses:',
                            totalAmount: fmt.format(totalExpenses),
                          );
                        },
                        icon:
                            const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final catsAsyncValue =
                              ref.read(allExpenseCategoriesProvider);
                          final cats = catsAsyncValue.valueOrNull ?? [];
                          final data = _expenseExportData(
                            expenses: expenses,
                            categories: cats,
                            fmt: fmt,
                            fmtDate: fmtDate,
                          );

                          await CsvExportService.generateAndOpenCsv(
                            title: 'Expenses Report',
                            subtitle: _reportLabel(fmtDate, categories),
                            headers: ExpenseReport.headers,
                            data: data,
                            totalAmountLabel: 'Total Expenses:',
                            totalAmount: fmt.format(totalExpenses),
                          );
                        },
                        icon: const Icon(Icons.table_view_rounded, size: 18),
                        label: const Text('CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _filters(allExpenses, categories),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search category, item, comments, or staff...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: expenses.isEmpty ? 2 : expenses.length + 1,
                  itemBuilder: (ctx, index) {
                    if (index == 0) {
                      return categoriesAsync.when(
                        data: (cats) => _CategoryAnalyticsPanel(
                          summaries: _buildCategorySummaries(expenses, cats),
                          totalAmount: totalExpenses,
                          periodLabel: _periodLabel(fmtDate),
                          fmt: fmt,
                          onCategoryTap: (summary) => _showCategoryBillsSheet(
                            context,
                            summary: summary,
                            expenses: expenses,
                            fmt: fmt,
                            fmtDate: fmtDate,
                          ),
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }

                    if (expenses.isEmpty) {
                      return _EmptyExpensePeriodPanel(
                        periodLabel: _reportLabel(fmtDate, categories),
                      );
                    }

                    final expense = expenses[index - 1];
                    return categoriesAsync.when(
                      data: (cats) {
                        final cat = _categoryFor(expense.categoryId, cats);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: const Border(
                                left: BorderSide(
                                    color: AppColors.danger, width: 4)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded,
                                      color: AppColors.danger, size: 22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat?.name ?? 'Unknown',
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      if (expense.subcategory != null &&
                                          expense.subcategory!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                              'Class: ${expense.subcategory}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ),
                                      if (expense.item != null &&
                                          expense.item!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text('Item: ${expense.item}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ),
                                      Text(
                                        fmt.format(expense.amount),
                                        style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.danger),
                                      ),
                                      if (expense.paymentMethod != null &&
                                          expense.paymentMethod!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                              'Payment: ${expense.paymentMethod == 'other' ? 'Other' : 'Cash'}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ),
                                      if (expense.note != null &&
                                          expense.note!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                              'Comments: ${expense.note}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ),
                                      if (expense.staffName != null &&
                                          expense.staffName!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                              'Staff: ${expense.staffName}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      fmtDate
                                          .format(DateTime.parse(expense.date)),
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => showDialog(
                                              context: context,
                                              builder: (ctx) =>
                                                  AddExpenseDialog(
                                                      existingExpense:
                                                          expense)),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(Icons.edit_rounded,
                                                size: 18,
                                                color: AppColors.info
                                                    .withOpacity(0.7)),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _confirmDeleteExpense(
                                            expense,
                                            cat?.name ?? 'Unknown',
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: AppColors.danger
                                                    .withOpacity(0.7)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const ListTile(title: Text('Loading...')),
                      error: (_, __) =>
                          const ListTile(title: Text('Unknown Category')),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context, builder: (ctx) => const AddExpenseDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
    );
  }
}

class _CategoryAnalyticsPanel extends StatelessWidget {
  final List<_CategoryExpenseSummary> summaries;
  final double totalAmount;
  final String periodLabel;
  final NumberFormat fmt;
  final ValueChanged<_CategoryExpenseSummary> onCategoryTap;

  const _CategoryAnalyticsPanel({
    required this.summaries,
    required this.totalAmount,
    required this.periodLabel,
    required this.fmt,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded,
                    color: AppColors.danger, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Analytics',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$periodLabel • ${summaries.length} categor${summaries.length == 1 ? 'y' : 'ies'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                fmt.format(totalAmount),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...summaries.map((summary) {
            final share = totalAmount <= 0 ? 0.0 : summary.amount / totalAmount;
            final percent = (share * 100).clamp(0, 100).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onCategoryTap(summary),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                summary.categoryName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                color:
                                    AppColors.textSecondary.withOpacity(0.65),
                                size: 18),
                            const SizedBox(width: 6),
                            Text(
                              fmt.format(summary.amount),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$percent% of spend',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${summary.count} entr${summary.count == 1 ? 'y' : 'ies'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: share.clamp(0, 1).toDouble(),
                            minHeight: 6,
                            backgroundColor: AppColors.danger.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyExpensePeriodPanel extends StatelessWidget {
  final String periodLabel;

  const _EmptyExpensePeriodPanel({required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 42, color: AppColors.textSecondary.withOpacity(0.35)),
          const SizedBox(height: 10),
          Text(
            'No expenses match these filters',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            periodLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
