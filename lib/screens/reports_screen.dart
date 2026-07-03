import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../mixins/date_filter_mixin.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_service.dart';
import '../main.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin, DateFilterMixin<ReportsScreen> {
  late TabController _tabController;
  DateTimeRange? get _dateRange => dateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  Future<void> _pickDateRange() => pickDateRange();

  void _clearDateRange() => clearDateRange();

  Future<void> _pickMonth() => pickMonth();

  Future<void> _pickYear() => pickYear();

  void _setPresetDateRange(String preset) => setPresetDateRange(preset);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isWithinRange(String dateStr) {
    return isWithinRange(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Daily Sales'),
                Tab(text: 'Total Purchases'),
                Tab(text: 'Credit Purchases'),
                Tab(text: 'Cash Purchases'),
                Tab(text: 'Credit Payments'),
                Tab(text: 'Credit Notes'),
                Tab(text: 'Unpaid Agencies'),
                Tab(text: 'Agency-wise'),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Reports',
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
              const PopupMenuItem(value: 'all', child: Text('All Time')),
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
                tooltip: 'Clear Filter'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesReport(ref),
          _buildPurchaseReport(ref, 'all'),
          _buildPurchaseReport(ref, 'credit'),
          _buildPurchaseReport(ref, 'cash'),
          _buildCreditPaymentReport(ref),
          _buildCreditNoteReport(ref),
          _buildUnpaidAgencyReport(ref),
          _buildAgencyReport(ref),
        ],
      ),
    );
  }

  // ─── Summary Header Widget ───────────────────────────────────
  Widget _summaryHeader(
      {required String label,
      required String value,
      required Color color,
      Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _exportButtons({
    required Future<void> Function() onPdf,
    required Future<void> Function() onCsv,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _exportButton(
          label: 'PDF',
          icon: Icons.picture_as_pdf_rounded,
          onPressed: onPdf,
        ),
        const SizedBox(width: 8),
        _exportButton(
          label: 'CSV',
          icon: Icons.table_view_rounded,
          onPressed: onCsv,
        ),
      ],
    );
  }

  Widget _exportButton({
    required String label,
    required IconData icon,
    required Future<void> Function() onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: () async => onPressed(),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  // ─── Report Row Card ─────────────────────────────────────────
  Widget _reportRow(
      {required String title,
      String? subtitle,
      required String trailing,
      Color accentColor = AppColors.accent,
      IconData icon = Icons.show_chart_rounded,
      Widget? badge}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
            if (badge != null) badge,
          ],
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary))
            : null,
        trailing: Text(trailing,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ),
    );
  }

  // ─── Status Badge Builder ─────────────────────────────────────
  Widget _statusBadge(TransactionModel tx) {
    if (!tx.type.contains('purchase_credit')) return const SizedBox.shrink();

    final Color bgColor;
    final Color textColor;
    final String label;

    if (tx.isPaid) {
      bgColor = AppColors.success.withOpacity(0.1);
      textColor = AppColors.success;
      label = '✓ PAID';
    } else if (tx.paidAmount > 0) {
      bgColor = AppColors.warning.withOpacity(0.1);
      textColor = AppColors.warning;
      final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
      label = '${fmtCurr.format(tx.remainingAmount)} due';
    } else {
      bgColor = AppColors.danger.withOpacity(0.1);
      textColor = AppColors.danger;
      label = 'UNPAID';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
    );
  }

  Widget _buildSalesReport(WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final fmtDate = DateFormat('yyyy-MM-dd');
    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return txsAsync.when(
      data: (txs) {
        final sales = txs
            .where((tx) => tx.type == 'sale' && _isWithinRange(tx.date))
            .toList();
        final groupedSales = <String, double>{};
        for (var sale in sales) {
          final dateStr = fmtDate.format(DateTime.parse(sale.date));
          groupedSales[dateStr] =
              (groupedSales[dateStr] ?? 0) + sale.totalAmount;
        }
        final sortedKeys = groupedSales.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        final totalSales = sortedKeys.fold<double>(
            0, (sum, d) => sum + (groupedSales[d] ?? 0));

        return Column(
          children: [
            _summaryHeader(
              label: 'Total Sales',
              value: fmtCurr.format(totalSales),
              color: AppColors.success,
              trailing: _exportButtons(
                onPdf: () async {
                  final data = sortedKeys
                      .map<List<String>>(
                          (d) => [d, fmtCurr.format(groupedSales[d])])
                      .toList();
                  await PdfService.generateAndPrintPdf(
                      title: 'Daily Sales Report',
                      subtitle: _dateRange != null
                          ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                          : 'All Time',
                      headers: ['Date', 'Sales'],
                      data: data,
                      totalAmountLabel: 'Total Sales:',
                      totalAmount: fmtCurr.format(totalSales));
                },
                onCsv: () async {
                  final data = sortedKeys
                      .map<List<String>>(
                          (d) => [d, fmtCurr.format(groupedSales[d])])
                      .toList();
                  await CsvExportService.generateAndOpenCsv(
                      title: 'Daily Sales Report',
                      subtitle: _dateRange != null
                          ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                          : 'All Time',
                      headers: ['Date', 'Sales'],
                      data: data,
                      totalAmountLabel: 'Total Sales:',
                      totalAmount: fmtCurr.format(totalSales));
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sortedKeys.length,
                itemBuilder: (ctx, idx) {
                  final date = sortedKeys[idx];
                  return _reportRow(
                    title: date,
                    trailing: fmtCurr.format(groupedSales[date]),
                    accentColor: AppColors.success,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── Purchase Report ─────────────────────────────────────────
  Widget _buildPurchaseReport(WidgetRef ref, String mode) {
    final txsAsync = ref.watch(transactionsProvider);
    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('yyyy-MM-dd');

    return txsAsync.when(
      data: (txs) {
        final purchases = txs.where((tx) {
          if (!_isWithinRange(tx.date)) return false;
          if (mode == 'all') return tx.type.startsWith('purchase');
          if (mode == 'credit') return tx.type == 'purchase_credit';
          if (mode == 'cash') return tx.type == 'purchase_cash';
          return false;
        }).toList();
        final double total = purchases.fold(0, (sum, p) => sum + p.totalAmount);
        String title = mode == 'all'
            ? 'Total Purchases'
            : (mode == 'credit' ? 'Credit Purchases' : 'Cash Purchases');

        // For credit mode: show paid/remaining summary
        double totalPaid = 0;
        double totalRemaining = 0;
        if (mode == 'credit') {
          totalPaid = purchases.fold(0.0, (sum, p) => sum + p.paidAmount);
          totalRemaining =
              purchases.fold(0.0, (sum, p) => sum + p.remainingAmount);
        }

        return Column(
          children: [
            _summaryHeader(
              label: mode == 'credit'
                  ? '$title: ${fmtCurr.format(total)} | Paid: ${fmtCurr.format(totalPaid)}'
                  : title,
              value: mode == 'credit'
                  ? 'Remaining: ${fmtCurr.format(totalRemaining)}'
                  : fmtCurr.format(total),
              color: mode == 'credit' ? Colors.deepOrange : AppColors.warning,
              trailing: _exportButtons(
                onPdf: () async {
                  final List<List<String>> data;
                  final List<String> headers;
                  if (mode == 'credit') {
                    headers = [
                      'Date',
                      'Agency',
                      'Bill No',
                      'Amount',
                      'Paid',
                      'Remaining',
                      'Status'
                    ];
                    data = purchases
                        .map<List<String>>((p) => [
                              fmtDate.format(DateTime.parse(p.date)),
                              p.agencyName ?? 'N/A',
                              p.billNo ?? 'N/A',
                              fmtCurr.format(p.totalAmount),
                              fmtCurr.format(p.paidAmount),
                              fmtCurr.format(p.remainingAmount),
                              p.isPaid ? 'PAID' : 'UNPAID',
                            ])
                        .toList();
                  } else {
                    headers = ['Date', 'Type', 'Agency', 'Amount'];
                    data = purchases
                        .map<List<String>>((p) => [
                              fmtDate.format(DateTime.parse(p.date)),
                              p.type == 'purchase_cash' ? 'Cash' : 'Credit',
                              p.agencyName ?? 'N/A',
                              fmtCurr.format(p.totalAmount)
                            ])
                        .toList();
                  }
                  await PdfService.generateAndPrintPdf(
                      title: '$title Report',
                      subtitle: _dateRange != null
                          ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                          : 'All Time',
                      headers: headers,
                      data: data,
                      totalAmountLabel: 'Total:',
                      totalAmount: fmtCurr.format(total));
                },
                onCsv: () async {
                  final List<List<String>> data;
                  final List<String> headers;
                  if (mode == 'credit') {
                    headers = [
                      'Date',
                      'Agency',
                      'Bill No',
                      'Amount',
                      'Paid',
                      'Remaining',
                      'Status'
                    ];
                    data = purchases
                        .map<List<String>>((p) => [
                              fmtDate.format(DateTime.parse(p.date)),
                              p.agencyName ?? 'N/A',
                              p.billNo ?? 'N/A',
                              fmtCurr.format(p.totalAmount),
                              fmtCurr.format(p.paidAmount),
                              fmtCurr.format(p.remainingAmount),
                              p.isPaid ? 'PAID' : 'UNPAID',
                            ])
                        .toList();
                  } else {
                    headers = ['Date', 'Type', 'Agency', 'Amount'];
                    data = purchases
                        .map<List<String>>((p) => [
                              fmtDate.format(DateTime.parse(p.date)),
                              p.type == 'purchase_cash' ? 'Cash' : 'Credit',
                              p.agencyName ?? 'N/A',
                              fmtCurr.format(p.totalAmount)
                            ])
                        .toList();
                  }
                  await CsvExportService.generateAndOpenCsv(
                      title: '$title Report',
                      subtitle: _dateRange != null
                          ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                          : 'All Time',
                      headers: headers,
                      data: data,
                      totalAmountLabel: 'Total:',
                      totalAmount: fmtCurr.format(total));
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: purchases.length,
                itemBuilder: (ctx, idx) {
                  final p = purchases[idx];
                  final String subtitleText;
                  if (mode == 'credit') {
                    subtitleText =
                        '${fmtDate.format(DateTime.parse(p.date))} • Bill: ${p.billNo ?? 'N/A'} • Paid: ${fmtCurr.format(p.paidAmount)}';
                  } else {
                    subtitleText =
                        '${fmtDate.format(DateTime.parse(p.date))} • ${p.type == 'purchase_cash' ? 'Cash' : 'Credit'}';
                  }
                  return _reportRow(
                    title: p.agencyName ?? 'Unknown Agency',
                    subtitle: subtitleText,
                    trailing: fmtCurr.format(p.totalAmount),
                    accentColor: mode == 'credit'
                        ? Colors.deepOrange
                        : AppColors.warning,
                    icon: Icons.shopping_cart_rounded,
                    badge: mode == 'credit' ? _statusBadge(p) : null,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── Unpaid Agencies ─────────────────────────────────────────
  Widget _buildUnpaidAgencyReport(WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('yyyy-MM-dd');

    return txsAsync.when(
      data: (txs) {
        // Only show unpaid or partially paid credit purchases
        final unpaidPurchases = txs
            .where((tx) =>
                tx.type == 'purchase_credit' &&
                _isWithinRange(tx.date) &&
                !tx.isPaid)
            .toList();

        // Group by agency
        final Map<String, List<TransactionModel>> byAgency = {};
        for (var tx in unpaidPurchases) {
          final key = (tx.agencyCode ?? tx.agencyName ?? 'UNKNOWN')
              .toUpperCase()
              .trim();
          byAgency.putIfAbsent(key, () => []).add(tx);
        }
        final agencyKeys = byAgency.keys.toList()..sort();

        // Total remaining across all
        final totalRemaining =
            unpaidPurchases.fold(0.0, (sum, p) => sum + p.remainingAmount);

        return Column(
          children: [
            _summaryHeader(
              label: 'Unpaid Agencies: ${agencyKeys.length}',
              value: 'Total Due: ${fmtCurr.format(totalRemaining)}',
              color: AppColors.danger,
              trailing: _exportButtons(
                onPdf: () async {
                  final List<List<String>> data = [];
                  for (var key in agencyKeys) {
                    final agencyTxs = byAgency[key]!;
                    final name = agencyTxs.first.agencyName ?? 'Unknown';
                    for (var p in agencyTxs) {
                      data.add([
                        fmtDate.format(DateTime.parse(p.date)),
                        name,
                        p.billNo ?? 'N/A',
                        fmtCurr.format(p.totalAmount),
                        fmtCurr.format(p.paidAmount),
                        fmtCurr.format(p.remainingAmount),
                      ]);
                    }
                  }
                  await PdfService.generateAndPrintPdf(
                    title: 'Unpaid Agencies Report',
                    subtitle: _dateRange != null
                        ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                        : 'All Time',
                    headers: [
                      'Date',
                      'Agency',
                      'Bill No',
                      'Total',
                      'Paid',
                      'Remaining'
                    ],
                    data: data,
                    totalAmountLabel: 'Total Due:',
                    totalAmount: fmtCurr.format(totalRemaining),
                  );
                },
                onCsv: () async {
                  final List<List<String>> data = [];
                  for (var key in agencyKeys) {
                    final agencyTxs = byAgency[key]!;
                    final name = agencyTxs.first.agencyName ?? 'Unknown';
                    for (var p in agencyTxs) {
                      data.add([
                        fmtDate.format(DateTime.parse(p.date)),
                        name,
                        p.billNo ?? 'N/A',
                        fmtCurr.format(p.totalAmount),
                        fmtCurr.format(p.paidAmount),
                        fmtCurr.format(p.remainingAmount),
                      ]);
                    }
                  }
                  await CsvExportService.generateAndOpenCsv(
                    title: 'Unpaid Agencies Report',
                    subtitle: _dateRange != null
                        ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                        : 'All Time',
                    headers: [
                      'Date',
                      'Agency',
                      'Bill No',
                      'Total',
                      'Paid',
                      'Remaining'
                    ],
                    data: data,
                    totalAmountLabel: 'Total Due:',
                    totalAmount: fmtCurr.format(totalRemaining),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: agencyKeys.length,
                itemBuilder: (ctx, idx) {
                  final key = agencyKeys[idx];
                  final agencyTxs = byAgency[key]!;
                  final name = agencyTxs.first.agencyName ?? 'Unknown';
                  final agencyRemaining = agencyTxs.fold(0.0,
                      (double s, TransactionModel t) => s + t.remainingAmount);
                  final agencyTotal = agencyTxs.fold(
                      0.0, (double s, TransactionModel t) => s + t.totalAmount);
                  final agencyPaid = agencyTxs.fold(
                      0.0, (double s, TransactionModel t) => s + t.paidAmount);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                          left: BorderSide(color: AppColors.danger, width: 3)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.warning_rounded,
                            color: AppColors.danger, size: 20),
                      ),
                      title: Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${agencyTxs.length} unpaid bill(s) • Total: ${fmtCurr.format(agencyTotal)}',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          if (agencyPaid > 0)
                            Text('Paid so far: ${fmtCurr.format(agencyPaid)}',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.success)),
                        ],
                      ),
                      trailing: Text(
                        fmtCurr.format(agencyRemaining),
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger),
                      ),
                      children: agencyTxs
                          .map((p) => ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                dense: true,
                                title: Text(
                                    'Bill: ${p.billNo ?? "N/A"} • ${fmtDate.format(DateTime.parse(p.date))}',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textPrimary)),
                                subtitle: p.paidAmount > 0
                                    ? Text(
                                        'Paid: ${fmtCurr.format(p.paidAmount)} of ${fmtCurr.format(p.totalAmount)}',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.warning))
                                    : null,
                                trailing: Text(
                                  fmtCurr.format(p.remainingAmount),
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.danger),
                                ),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── Credit Payments ─────────────────────────────────────────
  Widget _buildCreditPaymentReport(WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('yyyy-MM-dd');

    return txsAsync.when(
      data: (txs) {
        final payments = txs
            .where(
                (tx) => tx.type == 'credit_payment' && _isWithinRange(tx.date))
            .toList();
        final double totalPaid =
            payments.fold(0, (sum, tx) => sum + tx.totalAmount);

        return Column(
          children: [
            _summaryHeader(
              label: 'Total Credit Payments',
              value: fmtCurr.format(totalPaid),
              color: AppColors.info,
              trailing: _exportButtons(
                onPdf: () async {
                  final data = payments
                      .map<List<String>>((p) => [
                            fmtDate.format(DateTime.parse(p.date)),
                            p.agencyName ?? 'N/A',
                            p.originalBillNo ?? 'N/A',
                            fmtCurr.format(p.totalAmount)
                          ])
                      .toList();
                  await PdfService.generateAndPrintPdf(
                      title: 'Credit Payments Report',
                      subtitle: _dateRange != null
                          ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                          : 'All Time',
                      headers: ['Date', 'Agency', 'Ref Bill', 'Amount'],
                      data: data,
                      totalAmountLabel: 'Total Payments:',
                      totalAmount: fmtCurr.format(totalPaid));
                },
                onCsv: () async {
                  final data = payments
                      .map<List<String>>((p) => [
                            fmtDate.format(DateTime.parse(p.date)),
                            p.agencyName ?? 'N/A',
                            p.originalBillNo ?? 'N/A',
                            fmtCurr.format(p.totalAmount)
                          ])
                      .toList();
                  await CsvExportService.generateAndOpenCsv(
                      title: 'Credit Payments Report',
                      subtitle: _dateRange != null
                          ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                          : 'All Time',
                      headers: ['Date', 'Agency', 'Ref Bill', 'Amount'],
                      data: data,
                      totalAmountLabel: 'Total Payments:',
                      totalAmount: fmtCurr.format(totalPaid));
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: payments.length,
                itemBuilder: (ctx, idx) {
                  final p = payments[idx];
                  return _reportRow(
                    title: p.agencyName ?? 'Unknown Agency',
                    subtitle:
                        'Ref: ${p.originalBillNo ?? 'N/A'} • ${fmtDate.format(DateTime.parse(p.date))}',
                    trailing: fmtCurr.format(p.totalAmount),
                    accentColor: AppColors.info,
                    icon: Icons.payment_rounded,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── Credit Notes Report (NEW) ────────────────────────────────
  Widget _buildCreditNoteReport(WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('yyyy-MM-dd');

    return txsAsync.when(
      data: (txs) {
        final creditNotes = txs
            .where((tx) => tx.type == 'credit_note' && _isWithinRange(tx.date))
            .toList();
        final double totalNotes =
            creditNotes.fold(0, (sum, tx) => sum + tx.totalAmount);

        return Column(
          children: [
            _summaryHeader(
              label: 'Total Credit Notes',
              value: fmtCurr.format(totalNotes),
              color: Colors.purple,
              trailing: _exportButtons(
                onPdf: () async {
                  final data = creditNotes
                      .map<List<String>>((p) => [
                            fmtDate.format(DateTime.parse(p.date)),
                            p.agencyName ?? 'N/A',
                            p.originalBillNo ?? 'N/A',
                            p.billNo ?? 'N/A',
                            p.adjustmentDetails ?? '-',
                            fmtCurr.format(p.totalAmount),
                          ])
                      .toList();
                  await PdfService.generateAndPrintPdf(
                    title: 'Credit Notes Report',
                    subtitle: _dateRange != null
                        ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                        : 'All Time',
                    headers: [
                      'Date',
                      'Agency',
                      'CN No',
                      'Against Bill',
                      'Details',
                      'Amount'
                    ],
                    data: data,
                    totalAmountLabel: 'Total Credit Notes:',
                    totalAmount: fmtCurr.format(totalNotes),
                  );
                },
                onCsv: () async {
                  final data = creditNotes
                      .map<List<String>>((p) => [
                            fmtDate.format(DateTime.parse(p.date)),
                            p.agencyName ?? 'N/A',
                            p.originalBillNo ?? 'N/A',
                            p.billNo ?? 'N/A',
                            p.adjustmentDetails ?? '-',
                            fmtCurr.format(p.totalAmount),
                          ])
                      .toList();
                  await CsvExportService.generateAndOpenCsv(
                    title: 'Credit Notes Report',
                    subtitle: _dateRange != null
                        ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                        : 'All Time',
                    headers: [
                      'Date',
                      'Agency',
                      'CN No',
                      'Against Bill',
                      'Details',
                      'Amount'
                    ],
                    data: data,
                    totalAmountLabel: 'Total Credit Notes:',
                    totalAmount: fmtCurr.format(totalNotes),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: creditNotes.length,
                itemBuilder: (ctx, idx) {
                  final p = creditNotes[idx];
                  return _reportRow(
                    title: p.agencyName ?? 'Unknown Agency',
                    subtitle:
                        'CN: ${p.originalBillNo ?? 'N/A'} • Against Bill: ${p.billNo ?? 'N/A'} • ${fmtDate.format(DateTime.parse(p.date))}',
                    trailing: fmtCurr.format(p.totalAmount),
                    accentColor: Colors.purple,
                    icon: Icons.note_alt_rounded,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── Agency-wise Report ───────────────────────────────────────
  Widget _buildAgencyReport(WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('yyyy-MM-dd');

    return txsAsync.when(
      data: (txs) {
        // Group all purchase transactions by agency code
        final purchases = txs
            .where((tx) =>
                tx.type.startsWith('purchase') && _isWithinRange(tx.date))
            .toList();

        // Group by agency code (normalized uppercase)
        final Map<String, List<TransactionModel>> byAgency = {};
        for (var tx in purchases) {
          final code = (tx.agencyCode ?? 'UNKNOWN').toUpperCase().trim();
          byAgency.putIfAbsent(code, () => []).add(tx);
        }

        final agencyCodes = byAgency.keys.toList()..sort();
        final grandTotal =
            purchases.fold<double>(0, (sum, tx) => sum + tx.totalAmount);
        final grandPaid = purchases
            .where((tx) => tx.type == 'purchase_credit')
            .fold<double>(0, (sum, tx) => sum + tx.paidAmount);
        final grandRemaining = purchases
            .where((tx) => tx.type == 'purchase_credit')
            .fold<double>(0, (sum, tx) => sum + tx.remainingAmount);

        return Column(
          children: [
            _summaryHeader(
              label:
                  'Agencies: ${agencyCodes.length} • Paid: ${fmtCurr.format(grandPaid)}',
              value:
                  'Total: ${fmtCurr.format(grandTotal)} • Due: ${fmtCurr.format(grandRemaining)}',
              color: AppColors.primary,
              trailing: _exportButtons(
                onPdf: () async {
                  final List<List<String>> data = [];
                  for (var code in agencyCodes) {
                    final agencyTxs = byAgency[code]!;
                    final agencyTotal = agencyTxs.fold<double>(
                        0, (double s, TransactionModel t) => s + t.totalAmount);
                    final creditTxs =
                        agencyTxs.where((t) => t.type == 'purchase_credit');
                    final agencyPaid = creditTxs.fold<double>(
                        0, (double s, TransactionModel t) => s + t.paidAmount);
                    final agencyDue = creditTxs.fold<double>(
                        0,
                        (double s, TransactionModel t) =>
                            s + t.remainingAmount);
                    final name = agencyTxs.first.agencyName ?? 'Unknown';
                    data.add([
                      code,
                      name,
                      agencyTxs.length.toString(),
                      fmtCurr.format(agencyTotal),
                      fmtCurr.format(agencyPaid),
                      fmtCurr.format(agencyDue)
                    ]);
                  }
                  await PdfService.generateAndPrintPdf(
                    title: 'Agency-wise Purchase Report',
                    subtitle: _dateRange != null
                        ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                        : 'All Time',
                    headers: [
                      'Code',
                      'Agency',
                      'Bills',
                      'Total',
                      'Paid',
                      'Due'
                    ],
                    data: data,
                    totalAmountLabel: 'Grand Total:',
                    totalAmount: fmtCurr.format(grandTotal),
                  );
                },
                onCsv: () async {
                  final List<List<String>> data = [];
                  for (var code in agencyCodes) {
                    final agencyTxs = byAgency[code]!;
                    final agencyTotal = agencyTxs.fold<double>(
                        0, (double s, TransactionModel t) => s + t.totalAmount);
                    final creditTxs =
                        agencyTxs.where((t) => t.type == 'purchase_credit');
                    final agencyPaid = creditTxs.fold<double>(
                        0, (double s, TransactionModel t) => s + t.paidAmount);
                    final agencyDue = creditTxs.fold<double>(
                        0,
                        (double s, TransactionModel t) =>
                            s + t.remainingAmount);
                    final name = agencyTxs.first.agencyName ?? 'Unknown';
                    data.add([
                      code,
                      name,
                      agencyTxs.length.toString(),
                      fmtCurr.format(agencyTotal),
                      fmtCurr.format(agencyPaid),
                      fmtCurr.format(agencyDue)
                    ]);
                  }
                  await CsvExportService.generateAndOpenCsv(
                    title: 'Agency-wise Purchase Report',
                    subtitle: _dateRange != null
                        ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                        : 'All Time',
                    headers: [
                      'Code',
                      'Agency',
                      'Bills',
                      'Total',
                      'Paid',
                      'Due'
                    ],
                    data: data,
                    totalAmountLabel: 'Grand Total:',
                    totalAmount: fmtCurr.format(grandTotal),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: agencyCodes.length,
                itemBuilder: (ctx, idx) {
                  final code = agencyCodes[idx];
                  final agencyTxs = byAgency[code]!;
                  final agencyTotal = agencyTxs.fold<double>(
                      0, (double s, TransactionModel t) => s + t.totalAmount);
                  final creditTxs =
                      agencyTxs.where((t) => t.type == 'purchase_credit');
                  final agencyPaid = creditTxs.fold<double>(
                      0, (double s, TransactionModel t) => s + t.paidAmount);
                  final agencyDue = creditTxs.fold<double>(0,
                      (double s, TransactionModel t) => s + t.remainingAmount);
                  final name = agencyTxs.first.agencyName ?? 'Unknown';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                          left: BorderSide(color: AppColors.primary, width: 3)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.business_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      title: Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Code: $code  •  ${agencyTxs.length} bill(s)',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text('Total: ${fmtCurr.format(agencyTotal)}',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          if (agencyPaid > 0 || agencyDue > 0)
                            Row(
                              children: [
                                if (agencyPaid > 0)
                                  Text('Paid: ${fmtCurr.format(agencyPaid)}  ',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600)),
                                if (agencyDue > 0)
                                  Text('Due: ${fmtCurr.format(agencyDue)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.danger),
                        tooltip: 'Generate PDF for $name',
                        onPressed: () async {
                          final data = agencyTxs
                              .map<List<String>>((TransactionModel t) => [
                                    fmtDate.format(DateTime.parse(t.date)),
                                    t.billNo ?? '-',
                                    t.type == 'purchase_cash'
                                        ? 'Cash'
                                        : 'Credit',
                                    fmtCurr.format(t.totalAmount),
                                    t.type == 'purchase_credit'
                                        ? fmtCurr.format(t.paidAmount)
                                        : '-',
                                    t.type == 'purchase_credit'
                                        ? fmtCurr.format(t.remainingAmount)
                                        : '-',
                                  ])
                              .toList();
                          await PdfService.generateAndPrintPdf(
                            title: 'Purchase Report — $name ($code)',
                            subtitle: _dateRange != null
                                ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                                : 'All Time',
                            headers: [
                              'Date',
                              'Bill No',
                              'Type',
                              'Amount',
                              'Paid',
                              'Due'
                            ],
                            data: data,
                            totalAmountLabel: 'Total for $name:',
                            totalAmount: fmtCurr.format(agencyTotal),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
