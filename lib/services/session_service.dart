import 'package:flutter/foundation.dart';
import 'account_service.dart';
import 'database_service.dart';

class SessionService extends ChangeNotifier {
  static final instance = SessionService();
  LocalProfile? current;
  bool busy = false;
  int activeSaves = 0;
  late Future<void> Function() initializeProfile;

  Future<void> signIn(LocalProfile profile, String password) async {
    if (busy || current != null || activeSaves > 0) {
      throw const AccountException(
          'Please wait for the current operation to finish.');
    }
    busy = true;
    notifyListeners();
    try {
      if (!await AccountService.instance.verify(profile.id, password)) {
        throw const AccountException('Incorrect password. Please try again.');
      }
      await DatabaseService.instance.selectProfile(profile.id);
      await initializeProfile();
      current = profile;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (busy) {
      throw const AccountException(
          'Please wait for the current operation to finish.');
    }
    if (activeSaves > 0) {
      throw const AccountException(
          'An entry is still being saved. Please wait before switching profiles.');
    }
    busy = true;
    current = null;
    notifyListeners();
    try {
      await DatabaseService.instance.close();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<T> runMutation<T>(Future<T> Function() operation) async {
    if (busy) {
      throw const AccountException('Please wait before changing records.');
    }
    activeSaves++;
    try {
      return await operation();
    } finally {
      activeSaves--;
    }
  }

  void updateCurrent(LocalProfile profile) {
    current = profile;
    notifyListeners();
  }
}
