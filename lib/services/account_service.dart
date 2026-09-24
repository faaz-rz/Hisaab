import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalProfile {
  final String id;
  final String name;
  final bool passwordRequired;
  final String? photoBase64;
  const LocalProfile(
      {required this.id,
      required this.name,
      this.passwordRequired = true,
      this.photoBase64});
}

class AccountException implements Exception {
  final String message;
  const AccountException(this.message);
  @override
  String toString() => message;
}

Future<String> _derivePassword(Map<String, String> input) async {
  final key =
      await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 600000, bits: 256)
          .deriveKeyFromPassword(
              password: input['password']!,
              nonce: base64Decode(input['salt']!));
  return base64Encode(await key.extractBytes());
}

class AccountService {
  static final instance = AccountService();
  static const storageKey = 'hisaab_profiles_v1';
  List<Map<String, dynamic>> _records = [];
  bool _loaded = false;
  bool _writing = false;
  List<LocalProfile> get profiles => List.unmodifiable(_records.map(_profile));

  LocalProfile _profile(Map<String, dynamic> record) => LocalProfile(
      id: record['id'] as String,
      name: record['name'] as String,
      passwordRequired: record['algorithm'] != 'none',
      photoBase64: record['photo'] as String?);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      // Invalid account metadata must fail closed, never become a fresh setup.
      final decoded = jsonDecode(raw) as List;
      final records = decoded
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      if (records.isEmpty || records.first['id'] != 'primary') {
        throw const AccountException(
            'Profile settings could not be read. Your database files have not been changed.');
      }
      for (final record in records) {
        if (record['id'] is! String ||
            record['name'] is! String ||
            (record['algorithm'] != 'none' &&
                (record['salt'] is! String ||
                    record['hash'] is! String ||
                    record['algorithm'] != 'pbkdf2-sha256-600000')) ||
            (record['photo'] != null && record['photo'] is! String) ||
            !RegExp(r'^(primary|[0-9a-f]{32})$')
                .hasMatch(record['id'] as String)) {
          throw const AccountException(
              'Profile settings are invalid. Your records have not been changed.');
        }
      }
      _records = records;
    } else {
      _records = [];
    }
    _loaded = true;
  }

  String _randomId() => List.generate(16, (_) => Random.secure().nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  void _validateName(String name, {String? excludingId}) {
    if (name.trim().isEmpty || name.trim().length > 60) {
      throw const AccountException(
          'Enter a profile name between 1 and 60 characters.');
    }
    if (_records.any((record) =>
        record['id'] != excludingId &&
        (record['name'] as String).toLowerCase() ==
            name.trim().toLowerCase())) {
      throw const AccountException(
          'That profile name already exists. Choose a different name.');
    }
  }

  Future<Map<String, dynamic>> _credentials(String password) async {
    if (password.length < 4) {
      throw const AccountException(
          'Use at least 4 characters. A 4-digit PIN is also accepted.');
    }
    final random = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    final hash =
        await compute(_derivePassword, {'password': password, 'salt': salt});
    return {'salt': salt, 'hash': hash, 'algorithm': 'pbkdf2-sha256-600000'};
  }

  Future<void> _persist(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(records))) {
      throw const AccountException(
          'Could not save profile settings. Please try again.');
    }
    _records = records;
  }

  Future<LocalProfile> create(String name, String password,
      {bool passwordRequired = true, String? photoBase64}) async {
    if (!_loaded) throw StateError('Load profiles first.');
    if (_writing) {
      throw const AccountException('A profile is being saved. Please wait.');
    }
    _writing = true;
    try {
      _validateName(name);
      final credentials = passwordRequired
          ? await _credentials(password)
          : <String, dynamic>{'algorithm': 'none'};
      final profile = LocalProfile(
          id: _records.isEmpty ? 'primary' : _randomId(),
          name: name.trim(),
          passwordRequired: passwordRequired,
          photoBase64: photoBase64);
      await _persist([
        ..._records,
        {
          'id': profile.id,
          'name': profile.name,
          'photo': photoBase64,
          ...credentials
        }
      ]);
      return profile;
    } finally {
      _writing = false;
    }
  }

  Future<bool> verify(String id, String password) async {
    final matches = _records.where((record) => record['id'] == id);
    if (matches.isEmpty) return false;
    final record = matches.single;
    if (record['algorithm'] == 'none') return true;
    final hash = await compute(_derivePassword,
        {'password': password, 'salt': record['salt'] as String});
    final expected = base64Decode(record['hash'] as String);
    final actual = base64Decode(hash);
    if (expected.length != actual.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ actual[i];
    }
    return difference == 0;
  }

  Future<LocalProfile> update(
      String id, String name, String currentPassword, String? newPassword,
      {bool? passwordRequired,
      String? photoBase64,
      bool removePhoto = false}) async {
    if (_writing) {
      throw const AccountException('A profile is being saved. Please wait.');
    }
    _writing = true;
    try {
      if (!await verify(id, currentPassword)) {
        throw const AccountException('Current password is incorrect.');
      }
      _validateName(name, excludingId: id);
      final record = _records.singleWhere((record) => record['id'] == id);
      final required = passwordRequired ?? record['algorithm'] != 'none';
      if (required && record['algorithm'] == 'none' && newPassword == null) {
        throw const AccountException('Enter a password to enable protection.');
      }
      final credentials = !required
          ? <String, dynamic>{'algorithm': 'none', 'salt': null, 'hash': null}
          : newPassword == null
              ? <String, dynamic>{}
              : await _credentials(newPassword);
      await _persist(_records
          .map((record) => record['id'] == id
              ? {
                  ...record,
                  'name': name.trim(),
                  'photo': removePhoto ? null : photoBase64 ?? record['photo'],
                  ...credentials
                }
              : record)
          .toList());
      return _profile(_records.singleWhere((record) => record['id'] == id));
    } finally {
      _writing = false;
    }
  }
}
