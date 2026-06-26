import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../widgets/add_expense_dialog.dart';
import '../services/pdf_service.dart';
import '../widgets/month_year_picker.dart';
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

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTimeRange? _dateRange;

  void _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() {
        _dateRange = range;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _dateRange = null;
    });
  }

  void _pickMonth() async {
    final date = await showMonthYearPicker(context, onlyYear: false);
    if (date != null) {
      final start = DateTime(date.year, date.month, 1);
      final end = DateTime(date.year, date.month + 1, 0);
      setState(() {
        _dateRange = DateTimeRange(start: start, end: end);
      });
    }
  }

  void _pickYear() async {
    final date = await showMonthYearPicker(context, onlyYear: true);
    if (date != null) {
      final start = DateTime(date.year, 1, 1);
      final end = DateTime(date.year, 12, 31);
      setState(() {
        _dateRange = DateTimeRange(start: start, end: end);
      });
    }
  }

  void _setPresetDateRange(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (preset == 'week') {
      start = now.subtract(Duration(days: now.weekday - 1));
    } else if (preset == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else if (preset == 'year') {
      start = DateTime(now.year, 1, 1);
    } else {
      _clearDateRange();
      return;
    }

    setState(() {
      _dateRange = DateTimeRange(start: start, end: end);
    });
  }

  bool _isWithinRange(String dateStr) {
    if (_dateRange == null) return true;
    final date = DateTime.parse(dateStr);
    return date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
        date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
  }

  String _categoryNameFor(int categoryId, List<ExpenseCategory> categories) {
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return 'Unknown';
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
    if (_dateRange == null) return 'Up to date';

    final start = _dateRange!.start;
    final end = _dateRange!.end;
    final monthEnd = DateTime(start.year, start.month + 1, 0);
    final isFullMonth = start.day == 1 &&
        start.year == end.year &&
        start.month == end.month &&
        end.day == monthEnd.day;
    if (isFullMonth) return DateFormat('MMMM yyyy').format(start);

    final isFullYear = start.month == 1 &&
        start.day == 1 &&
        end.year == start.year &&
        end.month == 12 &&
        end.day == 31;
    if (isFullYear) return start.year.toString();

    return '${fmtDate.format(start)} - ${fmtDate.format(end)}';
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
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Expenses',
            onSelected: (value) {
              if (value == 'custom') {
                _pickDateRange();
              } else if (value == 'pick_month') {
                _pickMonth();
              } else if (value == 'pick_year') {
                _pickYear();
              } else {
                _setPresetDateRange(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Up to Date')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
              const PopupMenuItem(value: 'year', child: Text('This Year')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'pick_month', child: Text('Select Month...')),
              const PopupMenuItem(
                  value: 'pick_year', child: Text('Select Year...')),
              const PopupMenuItem(
                  value: 'custom', child: Text('Custom Date Range...')),
            ],
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: _clearDateRange,
              tooltip: 'Clear Filter',
            ),
        ],
      ),
      body: expensesAsync.when(
        data: (allExpenses) {
          final expenses =
              allExpenses.where((e) => _isWithinRange(e.date)).toList();
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.danger,
                      AppColors.danger.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Expenses',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(fmt.format(totalExpenses),
                            style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(_periodLabel(fmtDate),
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final catsAsyncValue =
                            ref.read(allExpenseCategoriesProvider);
                        final cats = catsAsyncValue.valueOrNull ?? [];

                        final List<List<String>> data =
                            expenses.map<List<String>>((e) {
                          final cat = cats.cast().firstWhere(
                              (element) => element.id == e.categoryId,
                              orElse: () => null);
                          return <String>[
                            fmtDate.format(DateTime.parse(e.date)),
                            cat?.name ?? 'Unknown',
                            e.subcategory ?? '-',
                            e.item ?? '-',
                            e.paymentMethod == null
                                ? '-'
                                : e.paymentMethod == 'other'
                                    ? 'Other'
                                    : 'Cash',
                            e.note ?? '-',
                            fmt.format(e.amount)
                          ];
                        }).toList();

                        await PdfService.generateAndPrintPdf(
                          title: 'Expenses Report',
                          subtitle: _dateRange != null
                              ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                              : 'Up to date',
                          headers: [
                            'Date',
                            'Category',
                            'Class',
                            'Item',
                            'Payment',
                            'Comments',
                            'Amount'
                          ],
                          data: data,
                          totalAmountLabel: 'Total Expenses:',
                          totalAmount: fmt.format(totalExpenses),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
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
                        periodLabel: _periodLabel(fmtDate),
                      );
                    }

                    final expense = expenses[index - 1];
                    return categoriesAsync.when(
                      data: (cats) {
                        final cat = cats.cast().firstWhere(
                            (element) => element.id == expense.categoryId,
                            orElse: () => null);
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
                                          onTap: () => ref
                                              .read(expensesProvider.notifier)
                                              .deleteExpense(expense.id!),
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
            'No expenses in this period',
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
