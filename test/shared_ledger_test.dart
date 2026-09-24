import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pharmacy_management/services/database_service.dart';
import 'package:pharmacy_management/services/entry_service.dart';

void main() {
  const second = '0123456789abcdef0123456789abcdef';
  late Directory directory;
  late DatabaseService service;
  Map<String, Object?> entry(int id, double amount) => {
        'id': id,
        'type': 'deposit',
        'bank_name': 'Client bank',
        'bank_code': 'CB',
        'account_no': '00123',
        'amount': amount,
        'date': '2026-09-24',
        'purpose': 'Opening',
      };
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hisaab-shared-');
    service = DatabaseService.forTesting(directory.path);
  });
  tearDown(() async {
    await service.close();
    await directory.delete(recursive: true);
  });

  test('migration preserves all ledger rows with colliding IDs and runs once',
      () async {
    var private = await service.database;
    await private.insert('bank_ledger', entry(7, 100));
    await private.insert('transactions',
        {'type': 'sale', 'total_amount': 75, 'date': '2026-09-24'});
    final primaryPath = await service.getDatabaseFilePath();
    await service.selectProfile(second);
    private = await service.database;
    // Even identical legacy rows must not be silently thrown away.
    await private.insert('bank_ledger', entry(7, 100));
    await private.insert('bank_ledger', entry(8, 200));
    await private.insert(
        'expenses', {'category_id': 1, 'amount': 25, 'date': '2026-09-24'});
    final secondaryPath = await service.getDatabaseFilePath();
    await service.close();
    final originals = {
      for (final path in [primaryPath, secondaryPath])
        path: await File(path).readAsBytes()
    };
    var shared = await service.ledgerDatabase;
    final rows = await shared.query('bank_ledger', orderBy: 'id');
    expect(rows.length, 3);
    expect(rows.first['id'], 7);
    expect(rows.map((row) => row['amount']), [100, 100, 200]);
    expect((await shared.query('banks')).length, 1);
    for (final path in originals.keys) {
      expect(await File(path).readAsBytes(), originals[path]);
      expect(await File('$path.before_shared_ledger_v1.db').exists(), true);
    }
    await service.selectProfile('primary');
    shared = await service.ledgerDatabase;
    expect(await shared.query('bank_ledger', orderBy: 'id'), rows);
    expect((await (await service.database).query('transactions')).length, 1);
    expect(await (await service.database).query('expenses'), isEmpty);
    await service.selectProfile(second);
    expect(await (await service.database).query('transactions'), isEmpty);
    expect((await (await service.database).query('expenses')).length, 1);
    shared = await service.ledgerDatabase;
    await expectLater(
        EntryService.save(
            shared, 'bank_ledger', {...entry(7, 100), 'id': null}),
        throwsA(isA<DuplicateEntryException>()));
    await shared.update('bank_ledger', {'amount': 150},
        where: 'id = ?', whereArgs: [7]);
    await service.selectProfile('primary');
    shared = await service.ledgerDatabase;
    expect(
        (await shared.query('bank_ledger', where: 'id = ?', whereArgs: [7]))
            .single['amount'],
        150);
    await shared.delete('bank_ledger', where: 'id = ?', whereArgs: [7]);
    await service.selectProfile(second);
    expect(
        (await (await service.ledgerDatabase).query('bank_ledger')).length, 2);
  });

  test(
      'profile backups include shared snapshot but restore cannot rewind shared ledger',
      () async {
    await service.database;
    var shared = await service.ledgerDatabase;
    await shared.insert('bank_ledger', entry(1, 100));
    final backup = '${directory.path}/profile.db';
    await service.copyDatabaseTo(backup);
    final snapshot = await databaseFactoryFfi.openDatabase(backup,
        options: OpenDatabaseOptions(readOnly: true));
    expect((await snapshot.query('bank_ledger')).single['amount'], 100);
    expect(
        (await snapshot.query('hisaab_shared_snapshot')).single['version'], 1);
    await snapshot.close();
    await shared.insert('bank_ledger', entry(2, 200));
    await service.replaceDatabaseFromFile(backup);
    shared = await service.ledgerDatabase;
    expect((await shared.query('bank_ledger')).length, 2);
    // A separate explicit ledger restore is allowed and affects both profiles.
    await service.restoreSharedLedger(backup);
    await service.selectProfile(second);
    shared = await service.ledgerDatabase;
    expect((await shared.query('bank_ledger')).single['amount'], 100);
    expect(
        await directory.list(recursive: true).any((f) =>
            f.path.contains('hisaab_shared_ledger_v1.db.before_restore_')),
        true);
    final ledgerBackup = '${directory.path}/ledger.db';
    await service.exportSharedLedger(ledgerBackup);
    await shared.delete('bank_ledger');
    await service.restoreSharedLedger(ledgerBackup);
    expect((await shared.query('bank_ledger')).length, 1);
    final corrupt = File('${directory.path}/bad.db');
    await corrupt.writeAsString('not a database');
    await expectLater(
        service.restoreSharedLedger(corrupt.path), throwsA(anything));
    expect((await shared.query('bank_ledger')).length, 1);
  });
}
