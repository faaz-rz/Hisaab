import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static const databaseFileName = 'pharmacy_management_v7.db';
  static Database? _database;
  static bool _ffiInitialized = false;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(databaseFileName);
    return _database!;
  }

  Future<String> getDatabaseFilePath() async {
    final docsPath = await getApplicationDocumentsDirectory();
    final dbDirectory = Directory(join(docsPath.path, 'PharmacyManagement'));
    await dbDirectory.create(recursive: true);
    return join(dbDirectory.path, databaseFileName);
  }

  Future<void> runDailyAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupPath = prefs.getString('auto_backup_path');
      if (backupPath == null || backupPath.isEmpty) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final savePath = join(backupPath, 'pharmacy_autobackup_$dateStr.db');

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
    final docsPath = await getApplicationDocumentsDirectory();
    final dbDirectory = Directory(join(docsPath.path, 'PharmacyManagement'));
    await dbDirectory.create(recursive: true);
    final path = join(dbDirectory.path, filePath);

    final db = await _openDatabase(path);

    // Run safe migrations for new columns
    await _migrateDB(db);

    return db;
  }

  Future<Database> _openDatabase(String path) async {
    final options = OpenDatabaseOptions(
      version: 1,
      onCreate: _createDB,
    );

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        _ffiInitialized = true;
      }
      return databaseFactoryFfi.openDatabase(path, options: options);
    }

    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// Safely add new columns that may not exist in older databases.
  Future<void> _migrateDB(Database db) async {
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
    Database db, {
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

    if (!await File(sourcePath).exists()) {
      await database;
    }

    await _prepareForFileCopy();

    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    await File(sourcePath).copy(destinationPath);
  }

  Future<void> replaceDatabaseFromFile(String sourcePath) async {
    await close();

    final destinationPath = await getDatabaseFilePath();
    final normalizedSource = normalize(absolute(sourcePath));
    final normalizedDestination = normalize(absolute(destinationPath));
    if (normalizedSource == normalizedDestination) {
      _database = null;
      return;
    }

    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    await _deleteSQLiteSidecars(destinationPath);
    await File(sourcePath).copy(destinationPath);
    _database = null;
  }

  Future<void> _prepareForFileCopy() async {
    final db = _database;
    if (db == null) return;

    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (e) {
      debugPrint('SQLite checkpoint skipped: $e');
    }

    await close();
  }

  Future<void> _deleteSQLiteSidecars(String databasePath) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
