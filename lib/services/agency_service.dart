import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Manages the agency registry — each agency_code maps to exactly one agency_name.
/// This prevents duplicate agencies due to spelling mistakes.
class AgencyService {
  static final AgencyService instance = AgencyService._();
  AgencyService._();

  /// Ensure the agencies table exists (called on app start).
  Future<void> ensureTable() async {
    final db = await DatabaseService.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS agencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL
      )
    ''');
    debugPrint('AgencyService: agencies table ensured.');
  }

  /// Look up agency name by code. Returns null if not found.
  Future<String?> getNameByCode(String code) async {
    if (code.trim().isEmpty) return null;
    final db = await DatabaseService.instance.database;
    final results = await db.query(
      'agencies',
      columns: ['name'],
      where: 'code = ?',
      whereArgs: [code.trim().toUpperCase()],
    );
    if (results.isNotEmpty) {
      return results.first['name'] as String;
    }
    return null;
  }

  /// Save or update agency mapping.
  /// If the code already exists, update the name. Otherwise insert.
  Future<void> saveAgency(String code, String name) async {
    if (code.trim().isEmpty || name.trim().isEmpty) return;
    final db = await DatabaseService.instance.database;
    final normalizedCode = code.trim().toUpperCase();
    final normalizedName = name.trim();

    final existing = await db.query('agencies', where: 'code = ?', whereArgs: [normalizedCode]);
    if (existing.isEmpty) {
      await db.insert('agencies', {'code': normalizedCode, 'name': normalizedName});
    } else {
      await db.update('agencies', {'name': normalizedName}, where: 'code = ?', whereArgs: [normalizedCode]);
    }
  }

  /// Get all agencies (for dropdowns, reports, etc.)
  Future<List<Map<String, dynamic>>> getAllAgencies() async {
    final db = await DatabaseService.instance.database;
    return await db.query('agencies', orderBy: 'name ASC');
  }
}
