import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/agency_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/entry_service.dart';
import '../services/session_service.dart';

final transactionsProvider = StateNotifierProvider<TransactionNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionNotifier();
});

class TransactionNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  static const _transactionOrder = '''
    CASE
      WHEN type IN ('purchase_cash', 'purchase_credit')
      THEN COALESCE(bill_date, date)
      ELSE date
    END DESC,
    id DESC
  ''';

  TransactionNotifier() : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final db = await DatabaseService.instance.database;
      final maps = await db.query('transactions', orderBy: _transactionOrder);
      final txs = maps.map((e) => TransactionModel.fromMap(e)).toList();
      if (mounted) state = AsyncValue.data(txs);
    } catch (e, stack) {
      if (mounted) state = AsyncValue.error(e, stack);
    }
  }

  /// Save agency code→name mapping if present
  Future<void> _saveAgencyIfPresent(TransactionModel tx) async {
    if (tx.agencyCode != null &&
        tx.agencyCode!.isNotEmpty &&
        tx.agencyName != null &&
        tx.agencyName!.isNotEmpty) {
      await AgencyService.instance.saveAgency(tx.agencyCode!, tx.agencyName!);
    }
  }

  Future<void> addTransaction(TransactionModel tx,
      {bool allowDuplicate = false, int? linkedBillId}) async {
    final db = await DatabaseService.instance.database;
    await EntryService.save(db, 'transactions', tx.toMap(),
        allowDuplicate: allowDuplicate, linkedBillId: linkedBillId);
    await _saveAgencyIfPresent(tx);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel tx,
      {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.database;
    await EntryService.save(db, 'transactions', tx.toMap(),
        allowDuplicate: allowDuplicate);
    await _saveAgencyIfPresent(tx);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await SessionService.instance.runMutation(() async {
      final db = await DatabaseService.instance.database;
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await CloudSyncService.instance.pushLocalIfEnabled();
      await loadTransactions();
    });
  }

  /// Get unpaid credit purchase bills for a given agency (by code or name).
  /// Returns bills where paid_amount < total_amount.
  static Future<List<TransactionModel>> getCreditPurchasesByAgency({
    String? agencyCode,
    String? agencyName,
  }) async {
    final db = await DatabaseService.instance.database;

    String whereClause =
        "type = 'purchase_credit' AND paid_amount < total_amount";
    List<dynamic> whereArgs = [];

    if (agencyCode != null && agencyCode.isNotEmpty) {
      whereClause += ' AND agency_code = ?';
      whereArgs.add(agencyCode);
    } else if (agencyName != null && agencyName.isNotEmpty) {
      whereClause += ' AND agency_name = ?';
      whereArgs.add(agencyName);
    } else {
      return [];
    }

    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'COALESCE(bill_date, date) DESC, id DESC',
    );

    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Get all payment/credit-note entries linked to a purchase bill.
  static Future<List<TransactionModel>> getPaymentHistoryForBill(
      String billNo) async {
    final normalizedBillNo = billNo.trim();
    if (normalizedBillNo.isEmpty) return [];

    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'transactions',
      where: '''
        type IN (?, ?)
        AND (
          original_bill_no = ?
          OR (type = ? AND bill_no = ?)
        )
      ''',
      whereArgs: [
        'credit_payment',
        'credit_note',
        normalizedBillNo,
        'credit_note',
        normalizedBillNo,
      ],
      orderBy: 'date DESC',
    );

    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Apply a payment amount to a specific credit purchase bill.
  /// Increments paid_amount by the given amount.
  Future<void> applyPaymentToBill(int billId, double amount) async {
    final db = await DatabaseService.instance.database;
    await db.rawUpdate(
      'UPDATE transactions SET paid_amount = paid_amount + ? WHERE id = ?',
      [amount, billId],
    );
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadTransactions();
  }
}
