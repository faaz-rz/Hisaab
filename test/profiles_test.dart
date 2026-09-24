import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmacy_management/models/transaction_model.dart';
import 'package:pharmacy_management/services/account_service.dart';
import 'package:pharmacy_management/services/database_service.dart';
import 'package:pharmacy_management/services/cloud_sync_service.dart';
import 'package:pharmacy_management/services/password_service.dart';
import 'package:pharmacy_management/services/profile_scope.dart';
import 'package:pharmacy_management/services/entry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileScope.id = 'primary';
  });

  test('profile names, passwords, restart and password changes', () async {
    final accounts = AccountService();
    await accounts.load();
    final first = await accounts.create('Client', 'first-password');
    final second = await accounts.create('Other business', 'second-password');
    expect(first.id, 'primary');
    expect(second.id, isNot(first.id));
    expect(await accounts.verify(first.id, 'first-password'), true);
    expect(await accounts.verify(first.id, 'second-password'), false);
    expect(await accounts.verify(second.id, 'second-password'), true);
    await expectLater(accounts.create(' client ', 'another-password'),
        throwsA(isA<AccountException>()));
    await expectLater(
        accounts.create('Short', 'short'), throwsA(isA<AccountException>()));
    await expectLater(
        accounts.update(second.id, 'Renamed', 'wrong-password', null),
        throwsA(isA<AccountException>()));
    await accounts.update(
        second.id, 'Renamed', 'second-password', 'new-password');
    final restarted = AccountService();
    await restarted.load();
    expect(restarted.profiles.map((p) => p.name), ['Client', 'Renamed']);
    expect(await restarted.verify(second.id, 'second-password'), false);
    expect(await restarted.verify(second.id, 'new-password'), true);
    final stored = (await SharedPreferences.getInstance())
        .getString(AccountService.storageKey)!;
    expect(stored, isNot(contains('first-password')));
    expect(stored, isNot(contains('new-password')));
    final records = jsonDecode(stored) as List;
    expect(records[0]['salt'], isNot(records[1]['salt']));
  });

  test('invalid account registry cannot silently reset to first setup',
      () async {
    SharedPreferences.setMockInitialValues({AccountService.storageKey: '[]'});
    await expectLater(
        AccountService().load(), throwsA(isA<AccountException>()));
  });

  test('legacy passwords and backup settings stay with primary profile',
      () async {
    SharedPreferences.setMockInitialValues({
      'ledger_password': '1234',
      'sales_password': '5678',
      'auto_backup_path': 'original-backups',
      'cloud_sync_folder_path': 'original-cloud',
    });
    expect(await PasswordService.instance.verifyLedgerPassword('1234'), true);
    final legacyName = CloudSyncService.cloudDatabaseFileName;
    ProfileScope.id = '0123456789abcdef0123456789abcdef';
    expect(await PasswordService.instance.isLedgerPasswordSet(), false);
    expect(await PasswordService.instance.isSalesPasswordSet(), false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ProfileScope.key('auto_backup_path')), isNull);
    expect(prefs.getString(ProfileScope.key('cloud_sync_folder_path')), isNull);
    expect(CloudSyncService.cloudDatabaseFileName, isNot(legacyName));
    await PasswordService.instance.setLedgerPassword('9999');
    expect(await PasswordService.instance.verifyLedgerPassword('9999'), true);
    ProfileScope.id = 'primary';
    expect(await PasswordService.instance.verifyLedgerPassword('1234'), true);
    expect(await PasswordService.instance.verifyLedgerPassword('9999'), false);
    expect(prefs.getString(ProfileScope.key('auto_backup_path')),
        'original-backups');
  });

  test(
      'upgrade and switching preserve legacy rows, IDs, balances and separate backups',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('hisaab-profile-test-');
    final service = DatabaseService.forTesting(directory.path);
    addTearDown(() async {
      await service.close();
      await directory.delete(recursive: true);
    });
    var db = await service.database;
    // Reproduce the already-deployed schema, which has no profile metadata.
    await db.execute('DROP TABLE hisaab_profile');
    await db.insert(
        'transactions',
        TransactionModel(
                id: 42,
                type: 'purchase_credit',
                date: '2026-06-09T12:00:00',
                totalAmount: 1234.50,
                paidAmount: 234.50,
                agencyName: 'Existing agency',
                agencyCode: 'A',
                billNo: 'INV1')
            .toMap());
    await db.insert('expenses', {
      'id': 17,
      'category_id': 1,
      'amount': 23.50,
      'date': '2026-06-09',
      'note': 'Existing note',
      'staff_name': 'Existing staff'
    });
    await db.insert('bank_ledger', {
      'id': 9,
      'type': 'deposit',
      'bank_name': 'Existing bank',
      'bank_code': 'BANK',
      'account_no': '00123',
      'amount': 55.75,
      'date': '2026-06-09'
    });
    await db.execute(
        'CREATE TABLE agencies (id INTEGER PRIMARY KEY, code TEXT, name TEXT)');
    await db
        .insert('agencies', {'id': 6, 'code': 'A', 'name': 'Existing agency'});
    await db.execute(
        'CREATE TABLE banks (id INTEGER PRIMARY KEY, bank_name TEXT, bank_code TEXT, account_no TEXT)');
    await db.insert('banks', {
      'id': 3,
      'bank_name': 'Existing bank',
      'bank_code': 'BANK',
      'account_no': '00123'
    });
    final tables = [
      'transactions',
      'expenses',
      'expense_categories',
      'bank_ledger',
      'agencies',
      'banks'
    ];
    final before = {for (final table in tables) table: await db.query(table)};
    final originalPath = await service.getDatabaseFilePath();
    await service.close();
    await service.prepareUpgradeBackup();
    await service.selectProfile('primary');
    db = await service.database;
    for (final table in tables) {
      expect(await db.query(table), before[table], reason: table);
    }
    final primaryBackup = '${directory.path}/primary.db';
    await service.copyDatabaseTo(primaryBackup);
    await service.selectProfile('0123456789abcdef0123456789abcdef');
    expect(await service.getDatabaseFilePath(), isNot(originalPath));
    db = await service.database;
    expect(await db.query('transactions'), isEmpty);
    expect(await db.query('expenses'), isEmpty);
    expect(await db.query('bank_ledger'), isEmpty);
    // Same details in another profile are not duplicates.
    await EntryService.save(
        db,
        'transactions',
        Map<String, dynamic>.from(before['transactions']!.single)
          ..remove('id'));
    await expectLater(
        service.replaceDatabaseFromFile(primaryBackup), throwsStateError);
    expect(
        (await (await service.database).query('transactions')).single['id'], 1);
    final secondBackup = '${directory.path}/second.db';
    await service.copyDatabaseTo(secondBackup);
    await service.selectProfile('primary');
    expect(await service.getDatabaseFilePath(), originalPath);
    db = await service.database;
    for (final table in tables) {
      expect(await db.query(table), before[table], reason: table);
    }
    await expectLater(
        service.replaceDatabaseFromFile(secondBackup), throwsStateError);
    final badBackup = File('${directory.path}/invalid.db');
    await badBackup.writeAsString('not a sqlite database');
    await expectLater(
        service.replaceDatabaseFromFile(badBackup.path), throwsA(anything));
    db = await service.database;
    expect(await db.query('transactions'), before['transactions']);
    await service.replaceDatabaseFromFile(primaryBackup);
    db = await service.database;
    expect(await db.query('transactions'), before['transactions']);
    expect(
        (await directory
            .list(recursive: true)
            .where((file) => file.path.contains('.before_restore_'))
            .toList()),
        isNotEmpty);
  });
}
