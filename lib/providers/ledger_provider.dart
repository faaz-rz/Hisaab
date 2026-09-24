import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_ledger.dart';
import '../services/database_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/entry_service.dart';

final ledgerProvider =
    StateNotifierProvider<LedgerNotifier, AsyncValue<List<BankLedger>>>((ref) {
  return LedgerNotifier();
});

class LedgerNotifier extends StateNotifier<AsyncValue<List<BankLedger>>> {
  LedgerNotifier() : super(const AsyncValue.loading()) {
    loadLedger();
  }

  Future<void> loadLedger() async {
    state = const AsyncValue.loading();
    try {
      final db = await DatabaseService.instance.database;
      final maps = await db.query('bank_ledger', orderBy: 'date DESC');
      final items = maps.map((e) => BankLedger.fromMap(e)).toList();
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addLedgerEntry(BankLedger entry, {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.database;
    await EntryService.save(db, 'bank_ledger', entry.toMap(),
        allowDuplicate: allowDuplicate);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadLedger();
  }

  Future<void> updateLedgerEntry(BankLedger entry, {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.database;
    await EntryService.save(db, 'bank_ledger', entry.toMap(),
        allowDuplicate: allowDuplicate);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadLedger();
  }

  Future<void> deleteLedgerEntry(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('bank_ledger', where: 'id = ?', whereArgs: [id]);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadLedger();
  }
}
