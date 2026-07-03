import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static const databaseFileName = 'pharmacy_management_v7.db';
  static Database? _database;

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

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );

    // Run safe migrations for new columns
    await _migrateDB(db);

    return db;
  }

  /// Safely add new columns that may not exist in older databases.
  /// ALTER TABLE ADD COLUMN is a no-op if the column already exists (we catch the error).
  Future<void> _migrateDB(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN paid_amount REAL DEFAULT 0');
      debugPrint('Migration: added paid_amount column to transactions');
    } catch (e) {
      debugPrint('Migration skipped (expected): $e');
    }
    try {
      await db
          .execute('ALTER TABLE transactions ADD COLUMN payment_method TEXT');
      debugPrint('Migration: added payment_method column to transactions');
    } catch (e) {
      debugPrint('Migration skipped (expected): $e');
    }
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN receipt_no TEXT');
      debugPrint('Migration: added receipt_no column to transactions');
    } catch (e) {
      debugPrint('Migration skipped (expected): $e');
    }
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN subcategory TEXT');
      debugPrint('Migration: added subcategory column to expenses');
    } catch (e) {
      debugPrint('Migration skipped (expected): $e');
    }
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN item TEXT');
      debugPrint('Migration: added item column to expenses');
    } catch (e) {
      debugPrint('Migration skipped (expected): $e');
    }
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN payment_method TEXT');
      debugPrint('Migration: added expense payment_method column');
    } catch (e) {
      debugPrint('Migration skipped (expected): $e');
    }
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
