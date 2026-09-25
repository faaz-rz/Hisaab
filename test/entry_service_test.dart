import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_management/models/transaction_model.dart';
import 'package:pharmacy_management/models/expense.dart';
import 'package:pharmacy_management/models/bank_ledger.dart';
import 'package:pharmacy_management/services/database_service.dart';
import 'package:pharmacy_management/services/entry_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late DatabaseService service;
  late Database db;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hisaab-entry-test-');
    service = DatabaseService.forTesting(directory.path);
    db = await service.database;
  });
  tearDown(() async {
    await service.close();
    await directory.delete(recursive: true);
  });

  Map<String, dynamic> sale(String date, {int? id, double amount = 100}) =>
      TransactionModel(id: id, type: 'sale', date: date, totalAmount: amount)
          .toMap();

  Map<String, dynamic> purchase(
          {String code = 'A',
          String name = 'Agency A',
          String bill = 'INV-001',
          String type = 'purchase_cash',
          int? id}) =>
      TransactionModel(
              id: id,
              type: type,
              date: '2026-09-24',
              totalAmount: 100,
              agencyCode: code,
              agencyName: name,
              billNo: bill)
          .toMap();

  test('same agency bill is blocked across cash/credit, dates and amounts',
      () async {
    await EntryService.save(db, 'transactions', purchase());
    await expectLater(
        EntryService.save(
            db,
            'transactions',
            {
              ...purchase(
                  code: ' a ', bill: ' inv-001 ', type: 'purchase_credit'),
              'date': '2026-09-25',
              'total_amount': 999,
            },
            allowDuplicate: true),
        throwsA(isA<DuplicateEntryException>()
            .having((e) => e.isPurchase, 'purchase warning', true)));
    expect((await db.query('transactions')).single['total_amount'], 100);
  });
  test('different agencies, bills and profiles are independent', () async {
    await EntryService.save(db, 'transactions', purchase());
    await EntryService.save(db, 'transactions', purchase(code: 'B'));
    await EntryService.save(db, 'transactions', purchase(bill: 'INV-002'));
    expect((await db.query('transactions')).length, 3);
    await service.selectProfile('0123456789abcdef0123456789abcdef');
    final otherDb = await service.database;
    await EntryService.save(otherDb, 'transactions', purchase());
    expect((await otherDb.query('transactions')).length, 1);
  });
  test('legacy agency names are matched when a code is missing', () async {
    await EntryService.save(db, 'transactions', purchase(code: ''));
    await expectLater(
        EntryService.save(db, 'transactions', purchase(name: ' agency a ')),
        throwsA(isA<DuplicateEntryException>()));
    await EntryService.save(
        db, 'transactions', purchase(code: '', name: 'Agency B'));
  });
  test('blank bill numbers or unknown agencies do not cause false duplicates',
      () async {
    for (var i = 0; i < 2; i++) {
      await EntryService.save(db, 'transactions', purchase(bill: ' '));
      await EntryService.save(db, 'transactions', purchase(code: '', name: ''));
    }
    expect((await db.query('transactions')).length, 4);
  });
  test('purchase edits preserve legacy duplicates but reject occupied keys',
      () async {
    final id = await db.insert('transactions', purchase());
    await db.insert('transactions', purchase());
    await EntryService.save(
        db, 'transactions', {...purchase(id: id), 'total_amount': 125});
    final other =
        await EntryService.save(db, 'transactions', purchase(bill: 'INV-002'));
    await expectLater(
        EntryService.save(db, 'transactions', purchase(id: other)),
        throwsA(isA<DuplicateEntryException>()));
    expect((await db.query('transactions')).length, 3);
    expect(
        (await db.query('transactions', where: 'id = ?', whereArgs: [other]))
            .single['bill_no'],
        'INV-002');
  });
  test('concurrent duplicate purchase attempts save only once', () async {
    final results = await Future.wait(List.generate(2, (_) async {
      try {
        await EntryService.save(db, 'transactions', purchase());
        return true;
      } on DuplicateEntryException {
        return false;
      }
    }));
    expect(results.where((value) => value).length, 1);
  });

  test('duplicate on same displayed date is rejected without changing rows',
      () async {
    await EntryService.save(db, 'transactions', sale('2026-09-24T09:00:00'));
    await expectLater(
        EntryService.save(
            db, 'transactions', sale('2026-09-24T18:00:00', amount: 750)),
        throwsA(isA<DuplicateEntryException>()));
    expect((await db.query('transactions')).length, 1);
    await EntryService.save(db, 'transactions', sale('2026-09-25T09:00:00'));
    expect((await db.query('transactions')).length, 2);
  });
  test('editing self succeeds, editing into another record warns', () async {
    final id = await EntryService.save(db, 'transactions', sale('2026-09-24'));
    await EntryService.save(db, 'transactions', sale('2026-09-24', id: id));
    final other =
        await EntryService.save(db, 'transactions', sale('2026-09-25'));
    await expectLater(
        EntryService.save(db, 'transactions', sale('2026-09-24', id: other)),
        throwsA(isA<DuplicateEntryException>()));
  });
  test('sales date protection cannot be bypassed', () async {
    await EntryService.save(db, 'transactions', sale('2026-09-24'));
    await expectLater(
        EntryService.save(db, 'transactions', sale('2026-09-24'),
            allowDuplicate: true),
        throwsA(isA<DuplicateEntryException>()));
    expect((await db.query('transactions')).length, 1);
  });
  test('historical same-day sales remain intact and editable', () async {
    final first =
        await db.insert('transactions', sale('2026-09-24', amount: 100));
    await db.insert('transactions', sale('2026-09-24', amount: 200));
    await EntryService.save(
        db, 'transactions', sale('2026-09-24', id: first, amount: 150));
    expect(
        (await db.query('transactions', orderBy: 'id'))
            .map((row) => row['total_amount']),
        [150, 200]);
  });
  test('concurrent duplicate saves leave only one record', () async {
    final results = await Future.wait(List.generate(2, (_) async {
      try {
        await EntryService.save(db, 'transactions', sale('2026-09-24'));
        return true;
      } on DuplicateEntryException {
        return false;
      }
    }));
    expect(results.where((saved) => saved).length, 1);
    expect((await db.query('transactions')).length, 1);
  });
  test('identical expenses are allowed', () async {
    final expense =
        Expense(categoryId: 1, amount: 50, date: '2026-09-24', item: 'Paper');
    await EntryService.save(db, 'expenses', expense.toMap());
    await EntryService.save(db, 'expenses', expense.toMap());
    await EntryService.save(db, 'expenses', {...expense.toMap(), 'amount': 75});
    expect((await db.query('expenses')).length, 3);
  });
  test('identical bank ledger entries are allowed', () async {
    final entry = BankLedger(
            type: 'deposit',
            bankName: 'Bank',
            accountNo: '123',
            amount: 50,
            date: '2026-09-24')
        .toMap();
    await EntryService.save(db, 'bank_ledger', entry);
    await EntryService.save(db, 'bank_ledger', entry);
    await EntryService.save(db, 'bank_ledger', {...entry, 'account_no': '456'});
  });
  test('repeated payments are allowed but cannot exceed the bill balance',
      () async {
    final bill = await EntryService.save(
        db,
        'transactions',
        TransactionModel(
                type: 'purchase_credit',
                date: '2026-09-24',
                totalAmount: 500,
                agencyCode: 'A',
                billNo: 'B1')
            .toMap());
    final payment = TransactionModel(
            type: 'credit_payment',
            date: '2026-09-24',
            totalAmount: 100,
            agencyCode: 'A',
            originalBillNo: 'B1')
        .toMap();
    await EntryService.save(db, 'transactions', payment, linkedBillId: bill);
    await EntryService.save(db, 'transactions', payment, linkedBillId: bill);
    expect(
        (await db.query('transactions', where: 'id = ?', whereArgs: [bill]))
            .single['paid_amount'],
        200);
    await expectLater(
        EntryService.save(db, 'transactions', {...payment, 'total_amount': 450},
            linkedBillId: bill),
        throwsA(isA<EntrySaveException>()));
    expect((await db.query('transactions')).length, 3);
  });
  test('failed payment insert rolls back bill update', () async {
    final bill = await EntryService.save(
        db,
        'transactions',
        TransactionModel(
                type: 'purchase_credit', date: '2026-09-24', totalAmount: 500)
            .toMap());
    await expectLater(
        EntryService.save(
            db,
            'transactions',
            {
              'type': 'credit_payment',
              'total_amount': 100,
              'date': null,
            },
            linkedBillId: bill),
        throwsA(isA<DatabaseException>()));
    expect((await db.query('transactions')).single['paid_amount'], 0);
  });
  test('editing a purchase cannot reset an existing paid balance', () async {
    final original = TransactionModel(
            type: 'purchase_credit',
            date: '2026-09-24',
            totalAmount: 500,
            paidAmount: 200)
        .toMap();
    final id = await EntryService.save(db, 'transactions', original);
    await EntryService.save(db, 'transactions',
        {...original, 'id': id, 'paid_amount': 0, 'total_amount': 600});
    final row = (await db.query('transactions')).single;
    expect(row['paid_amount'], 200);
    expect(row['total_amount'], 600);
  });
  test('backup is complete and leaves current database usable', () async {
    await db.execute('PRAGMA journal_mode=WAL');
    await EntryService.save(db, 'transactions', sale('2026-09-24'));
    final path = '${directory.path}/backup.db';
    await service.copyDatabaseTo(path);
    await EntryService.save(db, 'transactions', sale('2026-09-25'));
    expect((await db.query('transactions')).length, 2);
    final backup = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(readOnly: true));
    expect((await backup.query('transactions')).length, 1);
    await backup.close();
  });
  test('upgrade backup and repeated opens preserve all existing records',
      () async {
    await db.execute('PRAGMA journal_mode=WAL');
    await EntryService.save(db, 'transactions', sale('2026-09-24'));
    await db.insert('expenses',
        Expense(categoryId: 1, amount: 75, date: '2026-09-24').toMap());
    final before = await db.query('transactions');
    final expenses = await db.query('expenses');
    await service.close();
    await service.prepareUpgradeBackup();
    final backupPath =
        '${await service.getDatabaseFilePath()}.before_multi_user_v1.db';
    final originalBackup = await File(backupPath).readAsBytes();
    db = await service.database;
    expect(await db.query('transactions'), before);
    expect(await db.query('expenses'), expenses);
    await service.close();
    await service.prepareUpgradeBackup();
    expect(await File(backupPath).readAsBytes(), originalBackup);
    final backup = await databaseFactoryFfi.openDatabase(backupPath,
        options: OpenDatabaseOptions(readOnly: true));
    expect(await backup.query('transactions'), before);
    expect(
        (await backup.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok');
    await backup.close();
  });
}
