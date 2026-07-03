import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'transaction_provider.dart';
import 'ledger_provider.dart';
import 'expense_provider.dart';

final dashboardDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final dashboardOverallRangeProvider =
    StateProvider<DateTimeRange?>((ref) => null);

class DashboardMetrics {
  final double dateSales;
  final double datePurchases;
  final double totalSales;
  final double totalPurchases;
  final double totalCashPurchases;
  final double totalCreditPurchases;
  final double dateExpenses;
  final double totalExpenses;
  final double totalCreditOutstanding;
  final double netProfit;
  final double bankBalance;

  DashboardMetrics({
    required this.dateSales,
    required this.datePurchases,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalCashPurchases,
    required this.totalCreditPurchases,
    required this.dateExpenses,
    required this.totalExpenses,
    required this.totalCreditOutstanding,
    required this.netProfit,
    required this.bankBalance,
  });
}

final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final txAsync = ref.watch(transactionsProvider);
  final ledgerAsync = ref.watch(ledgerProvider);
  final expensesAsync = ref.watch(expensesProvider);
  final selectedDate = ref.watch(dashboardDateProvider);
  final overallRange = ref.watch(dashboardOverallRangeProvider);

  if (txAsync.isLoading || ledgerAsync.isLoading || expensesAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (txAsync.hasError || ledgerAsync.hasError || expensesAsync.hasError) {
    return AsyncValue.error('Error loading metrics', StackTrace.current);
  }

  final transactions = txAsync.value ?? [];
  final ledgers = ledgerAsync.value ?? [];
  final expenses = expensesAsync.value ?? [];

  final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

  double dSales = 0;
  double dPurchases = 0;
  double tSales = 0;
  double tPurchases = 0;
  double tCashPurchases = 0;
  double tCreditPurchases = 0;
  double dExpenses = 0;
  double tExpenses = 0;
  double tCreditOutstanding = 0;
  double balance = 0;

  for (var tx in transactions) {
    final txDate = DateTime.parse(tx.date);
    final txDateStr = DateFormat('yyyy-MM-dd').format(txDate);

    bool isWithinOverallRange = true;
    if (overallRange != null) {
      isWithinOverallRange = txDate
              .isAfter(overallRange.start.subtract(const Duration(days: 1))) &&
          txDate.isBefore(overallRange.end.add(const Duration(days: 1)));
    }

    if (tx.type == 'sale') {
      if (isWithinOverallRange) tSales += tx.totalAmount;
      if (txDateStr == selectedDateStr) dSales += tx.totalAmount;
    } else if (tx.type.startsWith('purchase')) {
      if (isWithinOverallRange) {
        tPurchases += tx.totalAmount;
        if (tx.type == 'purchase_cash') {
          tCashPurchases += tx.totalAmount;
        } else if (tx.type == 'purchase_credit') {
          tCreditPurchases += tx.totalAmount;
          if (!tx.isPaid) tCreditOutstanding += tx.remainingAmount;
        }
      }
      if (txDateStr == selectedDateStr) dPurchases += tx.totalAmount;
    }
  }

  for (var expense in expenses) {
    final expenseDate = DateTime.parse(expense.date);
    final expenseDateStr = DateFormat('yyyy-MM-dd').format(expenseDate);

    bool isWithinOverallRange = true;
    if (overallRange != null) {
      isWithinOverallRange = expenseDate
              .isAfter(overallRange.start.subtract(const Duration(days: 1))) &&
          expenseDate.isBefore(overallRange.end.add(const Duration(days: 1)));
    }

    if (isWithinOverallRange) tExpenses += expense.amount;
    if (expenseDateStr == selectedDateStr) dExpenses += expense.amount;
  }

  final netProfit = tSales - tPurchases - tExpenses;

  for (var l in ledgers) {
    if (l.type == 'deposit') {
      balance += l.amount;
    } else if (l.type == 'withdrawal') {
      balance -= l.amount;
    }
  }

  return AsyncValue.data(DashboardMetrics(
    dateSales: dSales,
    datePurchases: dPurchases,
    totalSales: tSales,
    totalPurchases: tPurchases,
    totalCashPurchases: tCashPurchases,
    totalCreditPurchases: tCreditPurchases,
    dateExpenses: dExpenses,
    totalExpenses: tExpenses,
    totalCreditOutstanding: tCreditOutstanding,
    netProfit: netProfit,
    bankBalance: balance,
  ));
});
