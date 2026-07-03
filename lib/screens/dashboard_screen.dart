import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/month_year_picker.dart';
import '../main.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final selectedDate = ref.watch(dashboardDateProvider);
    final overallRange = ref.watch(dashboardOverallRangeProvider);
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final isToday = selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;
    final dateLabel =
        isToday ? "Today" : DateFormat('MMM dd').format(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: metricsAsync.when(
        data: (metrics) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Greeting Header ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy')
                              .format(DateTime.now()),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    // Date Picker
                    Row(
                      children: [
                        if (!isToday)
                          _ActionChip(
                            label: 'Today',
                            icon: Icons.restore,
                            onTap: () => ref
                                .read(dashboardDateProvider.notifier)
                                .state = DateTime.now(),
                          ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          label: dateLabel,
                          icon: Icons.calendar_today_rounded,
                          isActive: !isToday,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              ref.read(dashboardDateProvider.notifier).state =
                                  date;
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ─── Daily Metrics Section ───
                _SectionLabel(label: 'Daily Activity — $dateLabel'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'Sales',
                        value: fmt.format(metrics.dateSales),
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        title: 'Purchases',
                        value: fmt.format(metrics.datePurchases),
                        icon: Icons.shopping_cart_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        title: 'Expenses',
                        value: fmt.format(metrics.dateExpenses),
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ─── Overall Totals Section ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionLabel(
                      label: overallRange == null
                          ? 'Overall Totals'
                          : 'Totals — ${DateFormat('MMM yyyy').format(overallRange.start)}',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.tune_rounded,
                          color: AppColors.textSecondary, size: 20),
                      tooltip: 'Filter Totals',
                      onSelected: (value) async {
                        if (value == 'all') {
                          ref
                              .read(dashboardOverallRangeProvider.notifier)
                              .state = null;
                        } else if (value == 'month') {
                          final date = await showMonthYearPicker(context,
                              onlyYear: false);
                          if (date != null) {
                            ref
                                    .read(dashboardOverallRangeProvider.notifier)
                                    .state =
                                DateTimeRange(
                                    start: DateTime(date.year, date.month, 1),
                                    end:
                                        DateTime(date.year, date.month + 1, 0));
                          }
                        } else if (value == 'year') {
                          final date = await showMonthYearPicker(context,
                              onlyYear: true);
                          if (date != null) {
                            ref
                                    .read(dashboardOverallRangeProvider.notifier)
                                    .state =
                                DateTimeRange(
                                    start: DateTime(date.year, 1, 1),
                                    end: DateTime(date.year, 12, 31));
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'all', child: Text('All Time')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'month', child: Text('Select Month...')),
                        const PopupMenuItem(
                            value: 'year', child: Text('Select Year...')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'Total Sales',
                        value: fmt.format(metrics.totalSales),
                        icon: Icons.stacked_line_chart_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        title: 'Total Purchases',
                        value: fmt.format(metrics.totalPurchases),
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'Total Expenses',
                        value: fmt.format(metrics.totalExpenses),
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        title:
                            metrics.netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                        value: fmt.format(metrics.netProfit.abs()),
                        icon: metrics.netProfit >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: metrics.netProfit >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'Cash Purchases',
                        value: fmt.format(metrics.totalCashPurchases),
                        icon: Icons.payments_rounded,
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        title: 'Credit Purchases',
                        value: fmt.format(metrics.totalCreditPurchases),
                        icon: Icons.credit_card_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'Credit Outstanding',
                        value: fmt.format(metrics.totalCreditOutstanding),
                        icon: Icons.pending_actions_rounded,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        title: 'Bank Balance',
                        value: fmt.format(metrics.bankBalance),
                        icon: Icons.account_balance_rounded,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─── Metric Tile Widget ────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─── Action Chip ───────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.accent.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
