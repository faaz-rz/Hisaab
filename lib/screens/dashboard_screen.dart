import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/month_year_picker.dart';
import '../widgets/workspace_components.dart';
import '../main.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final selectedDate = ref.watch(dashboardDateProvider);
    final range = ref.watch(dashboardOverallRangeProvider);
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(selectedDate, now);
    final day =
        isToday ? 'Today' : DateFormat('MMM dd, yyyy').format(selectedDate);
    final totalsPeriod = range == null
        ? 'All time'
        : range.start.month == 1 && range.end.month == 12
            ? DateFormat('yyyy').format(range.start)
            : DateFormat('MMM yyyy').format(range.start);
    return Scaffold(
        backgroundColor: AppColors.surface,
        body: metrics.when(
          data: (value) => LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                    padding:
                        EdgeInsets.all(constraints.maxWidth < 600 ? 20 : 28),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdaptiveSummaryRow(
                            summary: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getGreeting(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge),
                                  const SizedBox(height: 8),
                                  Text(
                                      DateFormat('EEEE, MMMM d, yyyy')
                                          .format(now),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textSecondary)),
                                ]),
                            actions: Wrap(spacing: 8, runSpacing: 8, children: [
                              if (!isToday)
                                TextButton.icon(
                                    onPressed: () => ref
                                        .read(dashboardDateProvider.notifier)
                                        .state = now,
                                    icon: const Icon(Icons.today_outlined,
                                        size: 16),
                                    label: const Text('Today')),
                              OutlinedButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: now);
                                    if (date != null)
                                      ref
                                          .read(dashboardDateProvider.notifier)
                                          .state = date;
                                  },
                                  icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16),
                                  label: Text(day)),
                            ]),
                          ),
                          const SizedBox(height: 32),
                          SectionHeading('Daily Activity — $day',
                              subtitle: 'A clear view of your day'),
                          const SizedBox(height: 16),
                          MetricGrid(maxColumns: 3, children: [
                            MetricCard(
                                label: 'Sales',
                                value: fmt.format(value.dateSales),
                                icon: Icons.trending_up_rounded,
                                color: AppColors.success,
                                prominent: true,
                                caption: 'Daily sales amount'),
                            MetricCard(
                                label: 'Purchases',
                                value: fmt.format(value.datePurchases),
                                icon: Icons.shopping_bag_outlined,
                                color: AppColors.warning,
                                caption: 'Cash and credit purchases'),
                            MetricCard(
                                label: 'Expenses',
                                value: fmt.format(value.dateExpenses),
                                icon: Icons.receipt_long_outlined,
                                color: AppColors.danger,
                                caption: 'Expenses for the selected date'),
                          ]),
                          const SizedBox(height: 32),
                          SectionHeading('Overall Totals',
                              subtitle: totalsPeriod,
                              action: PopupMenuButton<String>(
                                  tooltip: 'Filter Totals',
                                  onSelected: (choice) async {
                                    if (choice == 'all') {
                                      ref
                                          .read(dashboardOverallRangeProvider
                                              .notifier)
                                          .state = null;
                                      return;
                                    }
                                    final date = await showMonthYearPicker(
                                        context,
                                        onlyYear: choice == 'year');
                                    if (date == null) return;
                                    ref
                                        .read(dashboardOverallRangeProvider
                                            .notifier)
                                        .state = choice ==
                                            'year'
                                        ? DateTimeRange(
                                            start: DateTime(date.year, 1, 1),
                                            end: DateTime(date.year, 12, 31))
                                        : DateTimeRange(
                                            start: DateTime(
                                                date.year, date.month, 1),
                                            end: DateTime(
                                                date.year, date.month + 1, 0));
                                  },
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'all',
                                            child: Text('All Time')),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                            value: 'month',
                                            child: Text('Select Month...')),
                                        PopupMenuItem(
                                            value: 'year',
                                            child: Text('Select Year...')),
                                      ],
                                  child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.tune_rounded,
                                                size: 17,
                                                color: AppColors.textSecondary),
                                            SizedBox(width: 8),
                                            Text('Filter totals')
                                          ])))),
                          const SizedBox(height: 16),
                          MetricGrid(children: [
                            MetricCard(
                                label: 'Total Sales',
                                value: fmt.format(value.totalSales),
                                icon: Icons.stacked_line_chart_rounded,
                                color: AppColors.accent),
                            MetricCard(
                                label: 'Total Purchases',
                                value: fmt.format(value.totalPurchases),
                                icon: Icons.inventory_2_outlined,
                                color: AppColors.warning),
                            MetricCard(
                                label: 'Total Expenses',
                                value: fmt.format(value.totalExpenses),
                                icon: Icons.receipt_long_outlined,
                                color: AppColors.danger),
                            MetricCard(
                                label: value.netProfit >= 0
                                    ? 'Net Profit'
                                    : 'Net Loss',
                                value: fmt.format(value.netProfit.abs()),
                                icon: value.netProfit >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: value.netProfit >= 0
                                    ? AppColors.success
                                    : AppColors.danger),
                            MetricCard(
                                label: 'Cash Purchases',
                                value: fmt.format(value.totalCashPurchases),
                                icon: Icons.payments_outlined,
                                color: const Color(0xFFE67E22)),
                            MetricCard(
                                label: 'Credit Purchases',
                                value: fmt.format(value.totalCreditPurchases),
                                icon: Icons.credit_card_outlined,
                                color: AppColors.danger),
                            MetricCard(
                                label: 'Credit Outstanding',
                                value: fmt.format(value.totalCreditOutstanding),
                                icon: Icons.pending_actions_outlined,
                                color: Colors.deepOrange),
                            MetricCard(
                                label: 'Bank Balance',
                                value: fmt.format(value.bankBalance),
                                icon: Icons.account_balance_outlined,
                                color: AppColors.info,
                                caption: 'Shared across profiles · all time'),
                          ]),
                        ]),
                  )),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $error'))),
        ));
  }
}
