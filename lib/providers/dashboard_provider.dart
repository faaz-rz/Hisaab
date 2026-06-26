import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'transaction_provider.dart';
import 'ledger_provider.dart';

final dashboardDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final dashboardOverallRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

class DashboardMetrics {
  final double dateSales;
  final double datePurchases;
  final double totalSales;
  final double totalPurchases;
  final double totalCashPurchases;
  final double totalCreditPurchases;
  final double bankBalance;

  DashboardMetrics({
    required this.dateSales,
    required this.datePurchases,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalCashPurchases,
    required this.totalCreditPurchases,
    required this.bankBalance,
  });
}

final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final txAsync = ref.watch(transactionsProvider);
  final ledgerAsync = ref.watch(ledgerProvider);
  final selectedDate = ref.watch(dashboardDateProvider);
  final overallRange = ref.watch(dashboardOverallRangeProvider);

  if (txAsync.isLoading || ledgerAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (txAsync.hasError || ledgerAsync.hasError) {
    return AsyncValue.error('Error loading metrics', StackTrace.current);
  }

  final transactions = txAsync.value ?? [];
  final ledgers = ledgerAsync.value ?? [];

  final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

  double dSales = 0;
  double dPurchases = 0;
  double tSales = 0;
  double tPurchases = 0;
  double tCashPurchases = 0;
  double tCreditPurchases = 0;
  double balance = 0;

  for (var tx in transactions) {
    final txDate = DateTime.parse(tx.date);
    final txDateStr = DateFormat('yyyy-MM-dd').format(txDate);
    
    bool isWithinOverallRange = true;
    if (overallRange != null) {
      isWithinOverallRange = txDate.isAfter(overallRange.start.subtract(const Duration(days: 1))) && 
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
        }
      }
      if (txDateStr == selectedDateStr) dPurchases += tx.totalAmount;
    }
  }

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
    bankBalance: balance,
  ));
});
