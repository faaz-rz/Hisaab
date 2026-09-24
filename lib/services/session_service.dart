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
    if (!await AccountService.instance.verify(profile.id, password)) {
      throw const AccountException('Incorrect password. Please try again.');
    }
    busy = true;
    notifyListeners();
    try {
      await DatabaseService.instance.selectProfile(profile.id);
      await initializeProfile();
      current = profile;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
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

  void updateCurrent(LocalProfile profile) {
    current = profile;
    notifyListeners();
  }
}
