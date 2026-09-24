import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_scope.dart';

/// Manages user-created passwords for protected sections (Bank Ledger, Sales).
/// Passwords are stored locally using SharedPreferences.
class PasswordService {
  static final PasswordService instance = PasswordService._();
  PasswordService._();

  // SharedPreferences keys
  static String get _ledgerPasswordKey => ProfileScope.key('ledger_password');
  static String get _salesPasswordKey => ProfileScope.key('sales_password');
  static const String _hashPrefix = 'sha256:';

  String _hashPassword(String password) {
    final digest = sha256.convert(utf8.encode(password));
    return '$_hashPrefix$digest';
  }

  bool _isHashed(String storedPassword) {
    return storedPassword.startsWith(_hashPrefix);
  }

  Future<void> _setPassword(String key, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, _hashPassword(password));
  }

  Future<bool> _verifyPassword(String key, String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);
    if (stored == null || stored.isEmpty) return false;

    if (_isHashed(stored)) {
      return stored == _hashPassword(input);
    }

    if (stored == input) {
      await prefs.setString(key, _hashPassword(input));
      return true;
    }

    return false;
  }

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
    await _setPassword(_ledgerPasswordKey, password);
  }

  Future<void> setSalesPassword(String password) async {
    await _setPassword(_salesPasswordKey, password);
  }

  // ─── Verify a password ────────────────────────────────────────

  Future<bool> verifyLedgerPassword(String input) async {
    return _verifyPassword(_ledgerPasswordKey, input);
  }

  Future<bool> verifySalesPassword(String input) async {
    return _verifyPassword(_salesPasswordKey, input);
  }

  // ─── Change password (requires old password) ──────────────────

  Future<bool> changeLedgerPassword(
      String oldPassword, String newPassword) async {
    final isValid = await verifyLedgerPassword(oldPassword);
    if (!isValid) return false;
    await setLedgerPassword(newPassword);
    return true;
  }

  Future<bool> changeSalesPassword(
      String oldPassword, String newPassword) async {
    final isValid = await verifySalesPassword(oldPassword);
    if (!isValid) return false;
    await setSalesPassword(newPassword);
    return true;
  }
}
