import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'profile_scope.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static const databaseFileName = 'pharmacy_management_v7.db';
  String _profileId = 'primary';
  String get activeDatabaseFileName => _profileId == 'primary'
      ? databaseFileName
      : 'pharmacy_profile_$_profileId.db';
  Database? _database;
  Future<Database>? _opening;
  final String? _documentsPath;
  static bool _ffiInitialized = false;

  DatabaseService._init() : _documentsPath = null;

  @visibleForTesting
  DatabaseService.forTesting(String documentsPath)
      : _documentsPath = documentsPath;

  Future<String> _getDocumentsPath() async =>
      _documentsPath ?? (await getApplicationDocumentsDirectory()).path;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_opening != null) return _opening!;
    final opening = _initDB(activeDatabaseFileName);
    _opening = opening;
    try {
      _database = await opening;
      return _database!;
    } finally {
      _opening = null;
    }
  }

  Future<String> getDatabaseFilePath() async {
    final dbDirectory =
        Directory(join(await _getDocumentsPath(), 'PharmacyManagement'));
    await dbDirectory.create(recursive: true);
    return join(dbDirectory.path, activeDatabaseFileName);
  }

  Future<void> selectProfile(String id) async {
    if (!RegExp(r'^(primary|[0-9a-f]{32})$').hasMatch(id)) {
      throw ArgumentError.value(id, 'profile id');
    }
    if (_opening != null) await _opening;
    await close();
    _profileId = id;
    ProfileScope.id = id;
  }

  Future<void> runDailyAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupPath = prefs.getString(ProfileScope.key('auto_backup_path'));
      if (backupPath == null || backupPath.isEmpty) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final savePath = join(backupPath,
          '${ProfileScope.filePrefix('pharmacy_autobackup')}_$dateStr.db');

      final backupFile = File(savePath);

      if (!await backupFile.exists()) {
        await copyDatabaseTo(savePath);
        debugPrint('Auto-backup completed: $savePath');
      }
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbDirectory =
        Directory(join(await _getDocumentsPath(), 'PharmacyManagement'));
    await dbDirectory.create(recursive: true);
    final path = join(dbDirectory.path, filePath);

    final db = await _openDatabase(path);

    try {
      // Run safe migrations for new columns.
      await db.transaction((txn) async {
        await _ensureProfileOwnership(txn);
        await _migrateDB(txn);
      });
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  /// Runs before startup sync/migrations. VACUUM INTO includes committed WAL
  /// data and leaves the original client database in place.
  Future<void> prepareUpgradeBackup() async {
    final path = await getDatabaseFilePath();
    if (!await File(path).exists()) return;
    final backup = File('$path.before_multi_user_v1.db');
    if (await backup.exists()) return;
    final temporary =
        File('${backup.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    final db = await _openDatabase(path);
    try {
      await db.execute('VACUUM INTO ?', [temporary.path]);
      await temporary.rename(backup.path);
    } finally {
      await db.close();
    }
  }

  Future<Database> _openDatabase(String path, {bool readOnly = false}) async {
    final options = OpenDatabaseOptions(
      version: readOnly ? null : 1,
      onCreate: readOnly ? null : _createDB,
      readOnly: readOnly,
      singleInstance: !readOnly,
    );

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        _ffiInitialized = true;
      }
      return databaseFactoryFfi.openDatabase(path, options: options);
    }

    return openDatabase(path,
        version: readOnly ? null : 1,
        onCreate: readOnly ? null : _createDB,
        readOnly: readOnly,
        singleInstance: !readOnly);
  }

  Future<void> _ensureProfileOwnership(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS hisaab_profile (id TEXT NOT NULL PRIMARY KEY)');
    final rows = await db.query('hisaab_profile');
    if (rows.isEmpty) {
      await db.insert('hisaab_profile', {'id': _profileId});
    } else if (rows.length != 1 || rows.single['id'] != _profileId) {
      throw StateError('This database belongs to a different profile.');
    }
  }

  /// Safely add new columns that may not exist in older databases.
  Future<void> _migrateDB(DatabaseExecutor db) async {
    await _addColumnIfMissing(
      db,
      table: 'transactions',
      column: 'paid_amount',
      definition: 'REAL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'transactions',
      column: 'payment_method',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      table: 'transactions',
      column: 'receipt_no',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      table: 'expenses',
      column: 'subcategory',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      table: 'expenses',
      column: 'item',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      table: 'expenses',
      column: 'payment_method',
      definition: 'TEXT',
    );
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (exists) return;

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const nullableTextType = 'TEXT';
    const realType = 'REAL NOT NULL';
    const nullableRealType = 'REAL';

    // Expense Categories
    await db.execute('''
CREATE TABLE expense_categories (
  id $idType,
  name $textType UNIQUE,
  is_active INTEGER DEFAULT 1
)
''');

    // Pre-populate core categories requested strictly from handwritten note
    final defaultCategories = [
      'ELECTRICITY',
      'INTERNET',
      'MOBILE PAYMENT',
      'PHARMACY SOFTWARE PAYMENT',
      'HOTEL',
      'RENT',
      'Rafees Withdrawal',
      'MAINTENENCE FOR WHAT',
      'OTHERS',
      'SALARY - STAFF NAME'
    ];

    for (var cat in defaultCategories) {
      await db.insert('expense_categories', {'name': cat});
    }

    // Expenses Table
    await db.execute('''
CREATE TABLE expenses (
  id $idType,
  category_id INTEGER NOT NULL,
  amount $realType,
  date $textType,
  subcategory $nullableTextType,
  item $nullableTextType,
  payment_method $nullableTextType,
  note $nullableTextType,
  staff_name $nullableTextType,
  FOREIGN KEY (category_id) REFERENCES expense_categories (id)
)
''');

    // Transactions Table (Sales, Purchases, Returns)
    await db.execute('''
CREATE TABLE transactions (
  id $idType,
  type $textType, 
  date $textType,
  total_amount $realType,
  upi_amount $nullableRealType,
  agency_name $nullableTextType,
  agency_code $nullableTextType,
  bill_no $nullableTextType,
  original_bill_no $nullableTextType,
  profit $nullableRealType,
  discount $nullableRealType,
  adjustment_details $nullableTextType,
  bill_date $nullableTextType
)
''');

    // Bank Ledger Table
    await db.execute('''
CREATE TABLE bank_ledger (
  id $idType,
  type $textType,
  bank_name $textType,
  bank_code $nullableTextType,
  account_no $nullableTextType,
  amount $realType,
  date $textType,
  purpose $nullableTextType
)
''');

    // Currently we put Credit Payments directly in Transactions with type='credit_payment'.
    // Originally we had a separate credit_payments table but merged it for unified reporting/listing.
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
  }

  Future<void> copyDatabaseTo(String destinationPath) async {
    final sourcePath = await getDatabaseFilePath();
    if (normalize(absolute(sourcePath)) ==
        normalize(absolute(destinationPath))) {
      throw ArgumentError(
          'Choose a backup destination other than the active database.');
    }

    final db = await database;
    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    final temporary =
        File('$destinationPath.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      // Capture a consistent snapshot without closing a connection that the
      // dashboard or another form may still be using.
      await db.execute('VACUUM INTO ?', [temporary.path]);
      await temporary.rename(destinationPath);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> replaceDatabaseFromFile(String sourcePath) async {
    final destinationPath = await getDatabaseFilePath();
    final normalizedSource = normalize(absolute(sourcePath));
    final normalizedDestination = normalize(absolute(destinationPath));
    if (normalizedSource == normalizedDestination) {
      return;
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final staged = File('$destinationPath.incoming_$stamp.db');
    try {
      await File(sourcePath).copy(staged.path);
      final candidate = await _openDatabase(staged.path, readOnly: true);
      try {
        final integrity = await candidate.rawQuery('PRAGMA integrity_check');
        if (integrity.length != 1 || integrity.single.values.single != 'ok') {
          throw StateError(
              'The backup is damaged. Your current records were kept.');
        }
        const requiredColumns = {
          'transactions': [
            'id',
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
            'bill_date'
          ],
          'expenses': [
            'id',
            'category_id',
            'amount',
            'date',
            'note',
            'staff_name'
          ],
          'expense_categories': ['id', 'name', 'is_active'],
          'bank_ledger': [
            'id',
            'type',
            'bank_name',
            'bank_code',
            'account_no',
            'amount',
            'date',
            'purpose'
          ],
        };
        for (final entry in requiredColumns.entries) {
          final columns =
              (await candidate.rawQuery('PRAGMA table_info(${entry.key})'))
                  .map((row) => row['name'])
                  .toSet();
          if (!columns.containsAll(entry.value)) {
            throw StateError(
                'This is not a HISAAB backup. Your current records were kept.');
          }
        }
        final hasOwner = (await candidate.rawQuery(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'hisaab_profile'"))
            .isNotEmpty;
        final owners = hasOwner
            ? await candidate.query('hisaab_profile')
            : <Map<String, Object?>>[];
        if ((hasOwner &&
                (owners.length != 1 || owners.single['id'] != _profileId)) ||
            (!hasOwner && _profileId != 'primary')) {
          throw StateError(
              'This backup belongs to another profile. Switch to that profile to restore it.');
        }
      } finally {
        await candidate.close();
      }

      // Keep a consistent recovery copy before replacing any active records.
      final destination = File(destinationPath);
      File? recovery;
      if (await destination.exists()) {
        recovery = File('$destinationPath.before_restore_$stamp.db');
        await copyDatabaseTo(recovery.path);
      }
      await close();
      await _deleteSQLiteSidecars(destinationPath);
      if (await destination.exists()) await destination.delete();
      try {
        await staged.rename(destinationPath);
      } catch (_) {
        if (recovery != null) await recovery.copy(destinationPath);
        rethrow;
      }
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }

  Future<void> _deleteSQLiteSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
