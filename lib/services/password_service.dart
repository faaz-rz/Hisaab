import 'package:shared_preferences/shared_preferences.dart';

/// Manages user-created passwords for protected sections (Bank Ledger, Sales).
/// Passwords are stored locally using SharedPreferences.
class PasswordService {
  static final PasswordService instance = PasswordService._();
  PasswordService._();

  // SharedPreferences keys
  static const String _ledgerPasswordKey = 'ledger_password';
  static const String _salesPasswordKey = 'sales_password';

  // ─── Check if a password has been set ─────────────────────────

  Future<bool> isLedgerPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    final pwd = prefs.getString(_ledgerPasswordKey);
    return pwd != null && pwd.isNotEmpty;
  }

  Future<bool> isSalesPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    final pwd = prefs.getString(_salesPasswordKey);
    return pwd != null && pwd.isNotEmpty;
  }

  // ─── Create a new password (first-time setup) ─────────────────

  Future<void> setLedgerPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ledgerPasswordKey, password);
  }

  Future<void> setSalesPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_salesPasswordKey, password);
  }

  // ─── Verify a password ────────────────────────────────────────

  Future<bool> verifyLedgerPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_ledgerPasswordKey);
    return stored != null && stored == input;
  }

  Future<bool> verifySalesPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_salesPasswordKey);
    return stored != null && stored == input;
  }

  // ─── Change password (requires old password) ──────────────────

  Future<bool> changeLedgerPassword(String oldPassword, String newPassword) async {
    final isValid = await verifyLedgerPassword(oldPassword);
    if (!isValid) return false;
    await setLedgerPassword(newPassword);
    return true;
  }

  Future<bool> changeSalesPassword(String oldPassword, String newPassword) async {
    final isValid = await verifySalesPassword(oldPassword);
    if (!isValid) return false;
    await setSalesPassword(newPassword);
    return true;
  }
}
