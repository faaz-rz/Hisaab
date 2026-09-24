import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_ledger.dart';
import '../services/database_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/entry_service.dart';
import '../services/session_service.dart';

final ledgerProvider =
    StateNotifierProvider<LedgerNotifier, AsyncValue<List<BankLedger>>>((ref) {
  return LedgerNotifier();
});

class LedgerNotifier extends StateNotifier<AsyncValue<List<BankLedger>>> {
  LedgerNotifier() : super(const AsyncValue.loading()) {
    loadLedger();
  }

  Future<void> loadLedger() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final db = await DatabaseService.instance.ledgerDatabase;
      final maps = await db.query('bank_ledger', orderBy: 'date DESC');
      final items = maps.map((e) => BankLedger.fromMap(e)).toList();
      if (mounted) state = AsyncValue.data(items);
    } catch (e, stack) {
      if (mounted) state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addLedgerEntry(BankLedger entry,
      {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.ledgerDatabase;
    await EntryService.save(db, 'bank_ledger', entry.toMap(),
        allowDuplicate: allowDuplicate);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadLedger();
  }

  Future<void> updateLedgerEntry(BankLedger entry,
      {bool allowDuplicate = false}) async {
    final db = await DatabaseService.instance.ledgerDatabase;
    await EntryService.save(db, 'bank_ledger', entry.toMap(),
        allowDuplicate: allowDuplicate);
    await CloudSyncService.instance.pushLocalIfEnabled();
    await loadLedger();
  }

  Future<void> deleteLedgerEntry(int id) async {
    await SessionService.instance.runMutation(() async {
      final db = await DatabaseService.instance.ledgerDatabase;
      await db.delete('bank_ledger', where: 'id = ?', whereArgs: [id]);
      await CloudSyncService.instance.pushLocalIfEnabled();
      await loadLedger();
    });
  }
}
