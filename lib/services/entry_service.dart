import 'package:sqflite/sqflite.dart';

class DuplicateEntryException implements Exception {
  final int existingId;
  const DuplicateEntryException(this.existingId);

  @override
  String toString() => 'An entry with the same details already exists '
      '(record #$existingId). Check it before saving another copy.';
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
  static const _fields = {
    'transactions': [
      'type',
      'date',
      'total_amount',
      'upi_amount',
      'agency_name',
      'agency_code',
      'bill_no',
      'original_bill_no',
      'profit',
      'discount',
      'adjustment_details',
      'bill_date',
      'payment_method',
      'receipt_no',
    ],
    'expenses': [
      'category_id',
      'amount',
      'date',
      'subcategory',
      'item',
      'payment_method',
      'note',
      'staff_name',
    ],
    'bank_ledger': [
      'type',
      'bank_name',
      'bank_code',
      'account_no',
      'amount',
      'date',
      'purpose',
    ],
  };
  static const _numbers = {
    'total_amount',
    'upi_amount',
    'profit',
    'discount',
    'amount',
    'category_id',
  };

  static Future<int> save(
    Database db,
    String table,
    Map<String, dynamic> values, {
    bool allowDuplicate = false,
    int? linkedBillId,
  }) async {
    final fields = _fields[table];
    if (fields == null) throw ArgumentError.value(table, 'table');
    final id = values['id'] as int?;
    return db.transaction((txn) async {
      if (!allowDuplicate) {
        final clauses = <String>[];
        final arguments = <Object?>[];
        for (final field in fields) {
          final value = values[field];
          if (_numbers.contains(field)) {
            clauses.add('COALESCE($field, 0) = ?');
            arguments.add(value ?? 0);
          } else if (field == 'date' || field == 'bill_date') {
            // Entry forms display calendar dates, not the hidden time of day.
            clauses.add("SUBSTR(COALESCE($field, ''), 1, 10) = ?");
            final date = (value as String?) ?? '';
            arguments.add(date.length > 10 ? date.substring(0, 10) : date);
          } else {
            clauses.add("LOWER(TRIM(COALESCE($field, ''))) = LOWER(?)");
            arguments.add((value as String?)?.trim() ?? '');
          }
        }
        if (id != null) {
          clauses.add('id != ?');
          arguments.add(id);
        }
        final matches = await txn.query(table,
            columns: ['id'],
            where: clauses.join(' AND '),
            whereArgs: arguments,
            limit: 1);
        if (matches.isNotEmpty) {
          throw DuplicateEntryException(matches.first['id'] as int);
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
