import 'package:sqflite/sqflite.dart';

class DuplicateEntryException implements Exception {
  final int existingId;
  final String date;
  const DuplicateEntryException(this.existingId, {required this.date});

  @override
  String toString() => 'Sales have already been recorded for $date. '
      'Open the existing sale and edit the daily amount instead of adding another entry.';
}

class EntrySaveException implements Exception {
  final String message;
  const EntrySaveException(this.message);
  @override
  String toString() => message;
}

/// Checks and writes within one SQLite transaction, including bill settlement.
/// Existing records are never deduplicated or deleted automatically.
class EntryService {
  static const _tables = {'transactions', 'expenses', 'bank_ledger'};

  static Future<int> save(
    Database db,
    String table,
    Map<String, dynamic> values, {
    bool allowDuplicate = false,
    int? linkedBillId,
  }) async {
    if (!_tables.contains(table)) throw ArgumentError.value(table, 'table');
    final id = values['id'] as int?;
    return db.transaction((txn) async {
      if (table == 'transactions' && values['type'] == 'sale') {
        final date = (values['date'] as String).substring(0, 10);
        // An edit on its original day does not introduce another daily sale.
        // This also keeps old entries editable if a legacy file has duplicates.
        final original = id == null
            ? <Map<String, Object?>>[]
            : await txn.query(table,
                columns: ['type', 'date'], where: 'id = ?', whereArgs: [id]);
        final sameDayEdit = original.isNotEmpty &&
            original.single['type'] == 'sale' &&
            (original.single['date'] as String).substring(0, 10) == date;
        if (!sameDayEdit) {
          final matches = await txn.query(table,
              columns: ['id'],
              where:
                  "type = 'sale' AND SUBSTR(date, 1, 10) = ?${id == null ? '' : ' AND id != ?'}",
              whereArgs: [date, if (id != null) id],
              limit: 1);
          if (matches.isNotEmpty) {
            throw DuplicateEntryException(matches.single['id'] as int,
                date: date);
          }
        }
      }

      if (linkedBillId != null) {
        if (table != 'transactions' ||
            id != null ||
            !['credit_payment', 'credit_note'].contains(values['type'])) {
          throw const EntrySaveException('Invalid bill payment.');
        }
        final amount = values['total_amount'] as num;
        final bills = await txn.query('transactions',
            where: "id = ? AND type = 'purchase_credit'",
            whereArgs: [linkedBillId],
            limit: 1);
        if (bills.isEmpty) {
          throw const EntrySaveException(
              'This bill no longer exists. Reopen the form.');
        }
        final bill = bills.first;
        final remaining = (bill['total_amount'] as num) -
            ((bill['paid_amount'] as num?) ?? 0);
        if (amount <= 0 || amount > remaining) {
          throw const EntrySaveException(
              'The bill balance has changed. Reopen the form and check the remaining amount.');
        }
        await txn.rawUpdate(
            'UPDATE transactions SET paid_amount = COALESCE(paid_amount, 0) + ? WHERE id = ?',
            [amount, linkedBillId]);
      }

      final data = Map<String, dynamic>.from(values)..remove('id');
      if (id == null) return txn.insert(table, data);
      if (table == 'transactions') {
        // A purchase editor must not overwrite a balance updated by a payment
        // after the form opened. Only settlement operations change paid_amount.
        data.remove('paid_amount');
      }
      final count =
          await txn.update(table, data, where: 'id = ?', whereArgs: [id]);
      if (count != 1) {
        throw const EntrySaveException(
            'This entry no longer exists. Refresh the list.');
      }
      return id;
    });
  }
}
