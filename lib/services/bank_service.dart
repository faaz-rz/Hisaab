import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Manages bank registry — stores bank_name, bank_code, account_no.
/// Auto-fills bank details when a name or code is entered.
class BankService {
  static final BankService instance = BankService._();
  BankService._();

  /// Ensure the banks table exists (called on app start).
  Future<void> ensureTable() async {
    final db = await DatabaseService.instance.ledgerDatabase;
    final existing = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'banks'",
    );

    if (existing.isEmpty) {
      await _createBanksTable(db);
    } else {
      final createSql = ((existing.first['sql'] as String?) ?? '')
          .toLowerCase()
          .replaceAll(' ', '');
      if (createSql.contains('unique(bank_name)')) {
        await _migrateToMultiAccountBanksTable(db);
      }
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_banks_name ON banks(bank_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_banks_code ON banks(bank_code)',
    );
  }

  Future<void> _createBanksTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS banks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_name TEXT NOT NULL,
        bank_code TEXT,
        account_no TEXT,
        UNIQUE(bank_name, account_no)
      )
    ''');
  }

  Future<void> _migrateToMultiAccountBanksTable(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE banks RENAME TO banks_old');
      await _createBanksTable(txn);
      await txn.execute('''
        INSERT OR IGNORE INTO banks (bank_name, bank_code, account_no)
        SELECT
          TRIM(bank_name) AS bank_name,
          MAX(NULLIF(TRIM(COALESCE(bank_code, '')), '')) AS bank_code,
          NULLIF(TRIM(COALESCE(account_no, '')), '') AS account_no
        FROM banks_old
        WHERE TRIM(COALESCE(bank_name, '')) != ''
        GROUP BY
          TRIM(bank_name),
          NULLIF(TRIM(COALESCE(account_no, '')), '')
      ''');
      await txn.execute('DROP TABLE banks_old');
    });
  }

  /// Get bank details by name. Returns null if not found.
  Future<Map<String, dynamic>?> getBankByName(String name) async {
    if (name.trim().isEmpty) return null;
    final db = await DatabaseService.instance.ledgerDatabase;
    final results = await db.query(
      'banks',
      where: 'bank_name = ?',
      whereArgs: [name.trim()],
      orderBy: '''
        CASE
          WHEN account_no IS NULL OR TRIM(account_no) = '' THEN 1
          ELSE 0
        END,
        account_no COLLATE NOCASE ASC
      ''',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get bank details by code. Returns null if not found.
  Future<Map<String, dynamic>?> getBankByCode(String code) async {
    if (code.trim().isEmpty) return null;
    final db = await DatabaseService.instance.ledgerDatabase;
    final results = await db.query(
      'banks',
      where: 'bank_code = ?',
      whereArgs: [code.trim()],
      orderBy: 'bank_name COLLATE NOCASE ASC, account_no COLLATE NOCASE ASC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Save or update bank details.
  Future<void> saveBank(String bankName,
      {String? bankCode, String? accountNo}) async {
    if (bankName.trim().isEmpty) return;
    final db = await DatabaseService.instance.ledgerDatabase;
    final normalizedName = bankName.trim();
    final normalizedCode = bankCode?.trim();
    final normalizedAccount = accountNo?.trim();
    final accountKey = normalizedAccount ?? '';

    final existing = await db.query(
      'banks',
      where: "bank_name = ? AND COALESCE(account_no, '') = ?",
      whereArgs: [normalizedName, accountKey],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('banks', {
        'bank_name': normalizedName,
        'bank_code': normalizedCode?.isEmpty == true ? null : normalizedCode,
        'account_no':
            normalizedAccount?.isEmpty == true ? null : normalizedAccount,
      });
    } else {
      // Update with non-null values
      final updates = <String, dynamic>{};
      if (normalizedCode != null && normalizedCode.isNotEmpty) {
        updates['bank_code'] = normalizedCode;
      }
      if (normalizedAccount != null && normalizedAccount.isNotEmpty) {
        updates['account_no'] = normalizedAccount;
      }
      if (updates.isNotEmpty) {
        await db.update(
          'banks',
          updates,
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    }
  }

  /// Get all banks (for dropdowns).
  Future<List<Map<String, dynamic>>> getAllBanks() async {
    final db = await DatabaseService.instance.ledgerDatabase;
    return await db.rawQuery('''
      SELECT
        bank_name,
        MAX(NULLIF(TRIM(COALESCE(bank_code, '')), '')) AS bank_code,
        COUNT(DISTINCT NULLIF(TRIM(COALESCE(account_no, '')), '')) AS account_count
      FROM banks
      WHERE TRIM(COALESCE(bank_name, '')) != ''
      GROUP BY bank_name
      ORDER BY bank_name COLLATE NOCASE ASC
    ''');
  }

  /// Get all stored accounts for a selected bank.
  Future<List<Map<String, dynamic>>> getAccountsForBank(String bankName) async {
    if (bankName.trim().isEmpty) return [];
    final db = await DatabaseService.instance.ledgerDatabase;
    return await db.query(
      'banks',
      where: 'bank_name = ?',
      whereArgs: [bankName.trim()],
      orderBy: '''
        CASE
          WHEN account_no IS NULL OR TRIM(account_no) = '' THEN 1
          ELSE 0
        END,
        account_no COLLATE NOCASE ASC
      ''',
    );
  }
}
