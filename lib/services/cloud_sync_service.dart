import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'profile_scope.dart';

class CloudSyncResult {
  final bool isSuccess;
  final bool changedData;
  final bool needsRestart;
  final String message;

  const CloudSyncResult({
    required this.isSuccess,
    required this.changedData,
    required this.message,
    this.needsRestart = false,
  });
}

class CloudSyncSnapshot {
  final bool isEnabled;
  final String? folderPath;
  final String? cloudFilePath;
  final bool localFileExists;
  final bool cloudFileExists;
  final DateTime? localModified;
  final DateTime? cloudModified;
  final DateTime? lastSync;
  final String? lastMessage;

  const CloudSyncSnapshot({
    required this.isEnabled,
    required this.folderPath,
    required this.cloudFilePath,
    required this.localFileExists,
    required this.cloudFileExists,
    required this.localModified,
    required this.cloudModified,
    required this.lastSync,
    required this.lastMessage,
  });
}

class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._();

  static String get cloudDatabaseFileName => '${ProfileScope.filePrefix('hisaab_cloud')}.db';
  static String get _folderPathKey => ProfileScope.key('cloud_sync_folder_path');
  static String get _lastSyncKey => ProfileScope.key('cloud_sync_last_sync');
  static String get _lastMessageKey => ProfileScope.key('cloud_sync_last_message');
  static String get _needsSetupKey => ProfileScope.key('cloud_sync_needs_setup');
  static const _mtimeTolerance = Duration(seconds: 2);

  CloudSyncService._();

  Future<void> syncOnStartup() async {
    try {
      await syncNow(needsRestartOnDownload: false);
    } catch (e) {
      debugPrint('Cloud sync startup failed: $e');
    }
  }

  Future<CloudSyncSnapshot> getSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final folderPath = prefs.getString(_folderPathKey);
    final cloudFilePath =
        folderPath == null ? null : _cloudFilePathFor(folderPath);
    final localFile =
        File(await DatabaseService.instance.getDatabaseFilePath());
    final cloudFile = cloudFilePath == null ? null : File(cloudFilePath);

    final localExists = await localFile.exists();
    final cloudExists = cloudFile != null && await cloudFile.exists();

    return CloudSyncSnapshot(
      isEnabled: folderPath != null && folderPath.isNotEmpty,
      folderPath: folderPath,
      cloudFilePath: cloudFilePath,
      localFileExists: localExists,
      cloudFileExists: cloudExists,
      localModified: localExists ? await localFile.lastModified() : null,
      cloudModified: cloudExists ? await cloudFile.lastModified() : null,
      lastSync: _parseDate(prefs.getString(_lastSyncKey)),
      lastMessage: prefs.getString(_lastMessageKey),
    );
  }

  Future<CloudSyncResult> setFolder(String folderPath) async {
    final trimmedPath = folderPath.trim();
    if (trimmedPath.isEmpty) {
      return const CloudSyncResult(
        isSuccess: false,
        changedData: false,
        message: 'Please choose a valid cloud folder.',
      );
    }

    final directory = Directory(trimmedPath);
    await directory.create(recursive: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderPathKey, trimmedPath);

    final cloudPath = _cloudFilePathFor(trimmedPath);
    final cloudExists = await File(cloudPath).exists();
    await prefs.setBool(_needsSetupKey, cloudExists);
    final message = cloudExists
        ? 'Cloud folder connected. Existing cloud data was found.'
        : 'Cloud folder connected. Upload this device to start syncing.';
    await _recordMessage(message);

    return CloudSyncResult(
      isSuccess: true,
      changedData: false,
      message: message,
    );
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderPathKey);
    await prefs.remove(_needsSetupKey);
    await _recordMessage('Cloud sync disconnected.');
  }

  Future<CloudSyncResult> syncNow({
    bool needsRestartOnDownload = true,
  }) async {
    final folderPath = await _getFolderPath();
    if (folderPath == null) {
      return const CloudSyncResult(
        isSuccess: true,
        changedData: false,
        message: 'Cloud sync is not connected yet.',
      );
    }

    if (await _needsInitialSetup()) {
      return const CloudSyncResult(
        isSuccess: true,
        changedData: false,
        message: 'Choose Upload This Device or Download Cloud Copy first.',
      );
    }

    await Directory(folderPath).create(recursive: true);
    final cloudPath = _cloudFilePathFor(folderPath);
    final localPath = await DatabaseService.instance.getDatabaseFilePath();
    final localFile = File(localPath);
    final cloudFile = File(cloudPath);

    final cloudExists = await cloudFile.exists();
    final localExists = await localFile.exists();
    if (!localExists) {
      if (!cloudExists) {
        await DatabaseService.instance.database;
        await DatabaseService.instance.close();
        return uploadLocalCopy();
      }
      return downloadCloudCopy(needsRestart: needsRestartOnDownload);
    }

    if (!cloudExists) {
      return uploadLocalCopy();
    }

    if (await _filesMatch(localFile, cloudFile)) {
      return _recordAndReturn(
        const CloudSyncResult(
          isSuccess: true,
          changedData: false,
          message: 'Local and cloud data are already in sync.',
        ),
      );
    }

    final localModified = await localFile.lastModified();
    final cloudModified = await cloudFile.lastModified();
    if (cloudModified.isAfter(localModified.add(_mtimeTolerance))) {
      return downloadCloudCopy(needsRestart: needsRestartOnDownload);
    }

    return uploadLocalCopy();
  }

  Future<CloudSyncResult> pushLocalIfEnabled() async {
    final folderPath = await _getFolderPath();
    if (folderPath == null) {
      return const CloudSyncResult(
        isSuccess: true,
        changedData: false,
        message: 'Cloud sync is not connected yet.',
      );
    }

    if (await _needsInitialSetup()) {
      return const CloudSyncResult(
        isSuccess: true,
        changedData: false,
        message: 'Cloud sync is waiting for upload or download setup.',
      );
    }

    try {
      return await uploadLocalCopy();
    } catch (error) {
      // The local write has already committed. A cloud folder failure must
      // not make the form report that the local entry failed to save.
      const message = 'Saved on this computer. Cloud upload failed; open Backup & Sync to retry.';
      debugPrint('Cloud upload failed: $error');
      try { await _recordMessage(message); } catch (_) {}
      return const CloudSyncResult(isSuccess: false, changedData: false, message: message);
    }
  }

  Future<CloudSyncResult> uploadLocalCopy() async {
    final folderPath = await _getFolderPath();
    if (folderPath == null) {
      return const CloudSyncResult(
        isSuccess: false,
        changedData: false,
        message: 'Choose a cloud folder before uploading.',
      );
    }

    final cloudPath = _cloudFilePathFor(folderPath);
    await DatabaseService.instance.copyDatabaseTo(cloudPath);
    await _clearInitialSetup();
    return _recordAndReturn(
      const CloudSyncResult(
        isSuccess: true,
        changedData: true,
        message: 'This device has been uploaded to cloud sync.',
      ),
    );
  }

  Future<CloudSyncResult> downloadCloudCopy({bool needsRestart = true}) async {
    final folderPath = await _getFolderPath();
    if (folderPath == null) {
      return const CloudSyncResult(
        isSuccess: false,
        changedData: false,
        message: 'Choose a cloud folder before downloading.',
      );
    }

    final cloudPath = _cloudFilePathFor(folderPath);
    final cloudFile = File(cloudPath);
    if (!await cloudFile.exists()) {
      return const CloudSyncResult(
        isSuccess: false,
        changedData: false,
        message: 'No cloud database was found in this folder.',
      );
    }

    await DatabaseService.instance.replaceDatabaseFromFile(cloudPath);
    await _clearInitialSetup();
    return _recordAndReturn(
      CloudSyncResult(
        isSuccess: true,
        changedData: true,
        needsRestart: needsRestart,
        message: 'Cloud data has been downloaded to this device.',
      ),
    );
  }

  Future<String?> _getFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    final folderPath = prefs.getString(_folderPathKey)?.trim();
    return folderPath == null || folderPath.isEmpty ? null : folderPath;
  }

  Future<bool> _needsInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_needsSetupKey) ?? false;
  }

  Future<void> _clearInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_needsSetupKey, false);
  }

  String _cloudFilePathFor(String folderPath) {
    return p.join(folderPath, cloudDatabaseFileName);
  }

  Future<bool> _filesMatch(File first, File second) async {
    if (!await first.exists() || !await second.exists()) return false;
    final firstLength = await first.length();
    final secondLength = await second.length();
    if (firstLength != secondLength) return false;
    return await _digestFor(first) == await _digestFor(second);
  }

  Future<String> _digestFor(File file) async {
    final digest = await md5.bind(file.openRead()).first;
    return digest.toString();
  }

  DateTime? _parseDate(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _recordMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMessageKey, message);
  }

  Future<CloudSyncResult> _recordAndReturn(CloudSyncResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    await prefs.setString(_lastMessageKey, result.message);
    return result;
  }
}
