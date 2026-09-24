import 'package:flutter/material.dart';
import '../widgets/workspace_components.dart';
import '../services/profile_scope.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cloud_sync_service.dart';
import '../services/csv_export_service.dart';
import '../services/database_service.dart';
import '../main.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

enum _CloudSetupAction { upload, download }

class _BackupScreenState extends State<BackupScreen> {
  bool _isProcessing = false;
  String? _autoBackupPath;
  CloudSyncSnapshot? _cloudSnapshot;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cloudSnapshot = await CloudSyncService.instance.getSnapshot();
    if (!mounted) return;
    setState(() {
      _autoBackupPath = prefs.getString(ProfileScope.key('auto_backup_path'));
      _cloudSnapshot = cloudSnapshot;
    });
  }

  Future<void> _setAutoBackupFolder() async {
    setState(() => _isProcessing = true);
    try {
      final String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Auto-Backup Folder',
      );
      if (selectedDirectory != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            ProfileScope.key('auto_backup_path'), selectedDirectory);
        setState(() {
          _autoBackupPath = selectedDirectory;
        });
        await DatabaseService.instance.runDailyAutoBackup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Auto-backup folder set successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted)
        _showSnack('Could not configure auto-backup: $error', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _disableAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProfileScope.key('auto_backup_path'));
    setState(() {
      _autoBackupPath = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Auto-backup disabled.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _setCloudSyncFolder() async {
    setState(() => _isProcessing = true);
    try {
      final String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Cloud Sync Folder',
      );
      if (selectedDirectory == null) return;

      final result = await CloudSyncService.instance.setFolder(
        selectedDirectory,
      );
      await _loadSettings();

      if (!result.isSuccess) {
        _showSnack(result.message, AppColors.danger);
        return;
      }

      final snapshot = await CloudSyncService.instance.getSnapshot();
      if (snapshot.cloudFileExists) {
        final action = await _chooseCloudSetupAction();
        if (action == _CloudSetupAction.download) {
          await _downloadCloudCopy(confirmFirst: true);
        } else if (action == _CloudSetupAction.upload) {
          await _uploadLocalCloudCopy(confirmFirst: true);
        } else {
          _showSnack(result.message, AppColors.info);
        }
      } else {
        final uploadResult = await CloudSyncService.instance.uploadLocalCopy();
        await _loadSettings();
        _showSnack(
          uploadResult.message,
          uploadResult.isSuccess ? AppColors.success : AppColors.danger,
        );
      }
    } catch (e) {
      _showSnack('Cloud sync error: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _disableCloudSync() async {
    await CloudSyncService.instance.disable();
    await _loadSettings();
    _showSnack('Cloud sync disconnected.', AppColors.warning);
  }

  Future<void> _syncNow() async {
    setState(() => _isProcessing = true);
    try {
      final result = await CloudSyncService.instance.syncNow();
      await _loadSettings();
      _showSnack(
        result.message,
        result.isSuccess ? AppColors.success : AppColors.danger,
      );
      if (result.needsRestart) _showRestartDialog();
    } catch (e) {
      _showSnack('Cloud sync error: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _uploadLocalCloudCopy({bool confirmFirst = true}) async {
    if (confirmFirst) {
      final confirmed = await _confirmCloudAction(
        title: 'Upload This Device?',
        message:
            'This will replace the cloud copy with the database on this device.',
        confirmLabel: 'Upload',
      );
      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);
    try {
      final result = await CloudSyncService.instance.uploadLocalCopy();
      await _loadSettings();
      _showSnack(
        result.message,
        result.isSuccess ? AppColors.success : AppColors.danger,
      );
    } catch (e) {
      _showSnack('Cloud upload error: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadCloudCopy({bool confirmFirst = true}) async {
    if (confirmFirst) {
      final confirmed = await _confirmCloudAction(
        title: 'Download Cloud Copy?',
        message:
            'This will replace the database on this device with the cloud copy.',
        confirmLabel: 'Download',
        danger: true,
      );
      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);
    try {
      final result = await CloudSyncService.instance.downloadCloudCopy();
      await _loadSettings();
      _showSnack(
        result.message,
        result.isSuccess ? AppColors.success : AppColors.danger,
      );
      if (result.needsRestart) _showRestartDialog();
    } catch (e) {
      _showSnack('Cloud download error: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<_CloudSetupAction?> _chooseCloudSetupAction() {
    return showDialog<_CloudSetupAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cloud Data Found'),
        content: const Text(
          'This folder already has HISAAB cloud data. Choose whether this '
          'device should use that cloud copy or replace it with this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Decide Later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _CloudSetupAction.upload),
            child: const Text('Upload This Device'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _CloudSetupAction.download),
            child: const Text('Use Cloud Copy'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmCloudAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showRestartDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cloud Sync Complete',
          style: GoogleFonts.inter(color: AppColors.success),
        ),
        content: const Text(
          'Cloud data has replaced the local database.\n\n'
          'Please restart the application to load the synced data.',
        ),
        actions: [
          FilledButton(
            onPressed: () => exit(0),
            child: const Text('Close Application'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatSyncDate(DateTime? value) {
    if (value == null) return 'Not available';
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  Future<void> _exportBackup() async {
    setState(() => _isProcessing = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Folder to Save Backup',
      );

      if (selectedDirectory != null) {
        final savePath = p.join(selectedDirectory,
            '${ProfileScope.filePrefix('pharmacy_backup')}_$dateStr.db');
        await DatabaseService.instance.copyDatabaseTo(savePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved to:\n$savePath'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _csvValue(Object? value) => value?.toString() ?? '';

  Future<void> _sharedLedgerBackup(bool restore) async {
    setState(() => _isProcessing = true);
    try {
      if (restore) {
        final picked = await FilePicker.pickFiles(
            dialogTitle: 'Select a HISAAB ledger or profile backup',
            type: FileType.custom,
            allowedExtensions: ['db']);
        final path = picked?.files.single.path;
        if (path == null || !mounted) return;
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Restore ledger for ALL profiles?'),
                  content: const Text(
                      'This replaces the common bank ledger and bank accounts for every profile. Private sales, purchases and expenses stay unchanged. A recovery copy is saved first. Continue?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restore shared ledger'))
                  ],
                ));
        if (confirmed != true) return;
        await DatabaseService.instance.restoreSharedLedger(path);
        if (mounted) {
          await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                    title: const Text('Shared ledger restored'),
                    content: const Text(
                        'Restart HISAAB to refresh the ledger in all screens.'),
                    actions: [
                      FilledButton(
                          onPressed: () => exit(0),
                          child: const Text('Close Application'))
                    ],
                  ));
        }
      } else {
        final folder = await FilePicker.getDirectoryPath(
            dialogTitle: 'Save shared bank ledger');
        if (folder == null) return;
        final path = p.join(folder,
            'hisaab_shared_ledger_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.db');
        await DatabaseService.instance.exportSharedLedger(path);
        _showSnack('Shared ledger backup saved to $path', AppColors.success);
      }
    } catch (error) {
      _showSnack('Could not complete the ledger backup operation: $error',
          AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportCsvSnapshot() async {
    setState(() => _isProcessing = true);
    try {
      final db = await DatabaseService.instance.database;
      final rows = <List<String>>[];

      final transactions = await db.query('transactions', orderBy: 'date DESC');
      for (final tx in transactions) {
        rows.add([
          'Transaction',
          _csvValue(tx['date']),
          _csvValue(tx['type']),
          _csvValue(tx['agency_name']),
          _csvValue(tx['bill_no'] ?? tx['original_bill_no']),
          _csvValue(tx['payment_method']),
          _csvValue(tx['total_amount']),
          _csvValue(tx['adjustment_details']),
        ]);
      }

      final expenses = await db.rawQuery('''
        SELECT e.date, c.name AS category_name, e.subcategory, e.item,
               e.payment_method, e.amount, e.note
        FROM expenses e
        LEFT JOIN expense_categories c ON c.id = e.category_id
        ORDER BY e.date DESC
      ''');
      for (final expense in expenses) {
        rows.add([
          'Expense',
          _csvValue(expense['date']),
          _csvValue(expense['subcategory']),
          _csvValue(expense['category_name']),
          _csvValue(expense['item']),
          _csvValue(expense['payment_method']),
          _csvValue(expense['amount']),
          _csvValue(expense['note']),
        ]);
      }

      final ledger = await DatabaseService.instance.ledgerDatabase;
      final ledgerEntries =
          await ledger.query('bank_ledger', orderBy: 'date DESC');
      for (final entry in ledgerEntries) {
        rows.add([
          'Bank Ledger',
          _csvValue(entry['date']),
          _csvValue(entry['type']),
          _csvValue(entry['bank_name']),
          _csvValue(entry['account_no']),
          _csvValue(entry['bank_code']),
          _csvValue(entry['amount']),
          _csvValue(entry['purpose']),
        ]);
      }

      await CsvExportService.generateAndOpenCsv(
        title: 'Hisaab Data Export',
        subtitle:
            'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        headers: [
          'Section',
          'Date',
          'Type/Class',
          'Name',
          'Reference',
          'Payment/Code',
          'Amount',
          'Notes',
        ],
        data: rows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('CSV export created successfully.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _isProcessing = true);
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Select Backup Database File',
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final backupPath = result.files.single.path!;

        if (!backupPath.endsWith('.db')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Invalid file. Please select a .db file.'),
                backgroundColor: AppColors.danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        if (!mounted) return;
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Restore'),
            content: const Text(
                'This replaces this profile’s private records with the backup. '
                'Other profiles and the shared bank ledger are not changed. '
                'To restore the bank ledger, use Restore shared ledger separately. '
                'A recovery copy of the current records will be kept.\n\n'
                'Are you sure you want to proceed?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Restore'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await DatabaseService.instance.replaceDatabaseFromFile(backupPath);

          if (mounted) {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                      title: Text('Restore Successful',
                          style: GoogleFonts.inter(color: AppColors.success)),
                      content: const Text(
                          'The database has been restored successfully.\n\nPLEASE RESTART THE APPLICATION to load the restored data.'),
                      actions: [
                        FilledButton(
                          onPressed: () => exit(0),
                          child: const Text('Close Application'),
                        ),
                      ],
                    ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudSnapshot = _cloudSnapshot;
    final cloudEnabled = cloudSnapshot?.isEnabled ?? false;

    return PopScope(
        canPop: !_isProcessing,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: const PageHeading(
                title: 'Backup & Sync',
                subtitle: 'Protect your records & manage recovery copies'),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Shared bank ledger',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text(
                                    'The bank ledger is common to all profiles on this computer. Profile exports, daily backups and cloud uploads include a snapshot of it. Restoring or downloading a profile does not overwrite the shared ledger; restore it explicitly here if needed.'),
                                const SizedBox(height: 12),
                                Wrap(spacing: 12, runSpacing: 8, children: [
                                  OutlinedButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : () => _sharedLedgerBackup(false),
                                      icon: const Icon(Icons.download),
                                      label:
                                          const Text('Export shared ledger')),
                                  OutlinedButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : () => _sharedLedgerBackup(true),
                                      icon: const Icon(Icons.restore),
                                      label:
                                          const Text('Restore shared ledger')),
                                ]),
                              ],
                            ))),
                    const SizedBox(height: 20),
                    // ─── Header ───
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded,
                            size: 48, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Local Cloud Backup',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Export your database to a secure location such as OneDrive or Google Drive.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 36),

                    // ─── Cloud Sync ───
                    Text('Cloud Sync',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cloudEnabled
                            ? AppColors.info.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cloudEnabled
                              ? AppColors.info.withValues(alpha: 0.3)
                              : AppColors.divider,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (cloudEnabled
                                          ? AppColors.info
                                          : AppColors.warning)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  cloudEnabled
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_off_rounded,
                                  color: cloudEnabled
                                      ? AppColors.info
                                      : AppColors.warning,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cloudEnabled
                                      ? 'Cloud Sync Connected'
                                      : 'Cloud Sync Not Connected',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: cloudEnabled
                                        ? AppColors.info
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cloudEnabled
                                ? 'This device syncs with:\n${cloudSnapshot?.folderPath ?? ''}'
                                : 'Choose a folder inside iCloud Drive, OneDrive, Google Drive, Dropbox, or another synced location.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (cloudEnabled) ...[
                            const SizedBox(height: 14),
                            _SyncDetailRow(
                              label: 'Cloud file',
                              value: cloudSnapshot?.cloudFileExists == true
                                  ? CloudSyncService.cloudDatabaseFileName
                                  : 'No cloud database yet',
                            ),
                            _SyncDetailRow(
                              label: 'Local updated',
                              value:
                                  _formatSyncDate(cloudSnapshot?.localModified),
                            ),
                            _SyncDetailRow(
                              label: 'Cloud updated',
                              value:
                                  _formatSyncDate(cloudSnapshot?.cloudModified),
                            ),
                            _SyncDetailRow(
                              label: 'Last sync',
                              value: cloudSnapshot?.lastMessage ??
                                  _formatSyncDate(cloudSnapshot?.lastSync),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (cloudEnabled)
                                TextButton(
                                  onPressed:
                                      _isProcessing ? null : _disableCloudSync,
                                  child: Text('Disconnect',
                                      style: GoogleFonts.inter(
                                          color: AppColors.danger)),
                                ),
                              if (cloudEnabled)
                                OutlinedButton.icon(
                                  onPressed: _isProcessing ? null : _syncNow,
                                  icon:
                                      const Icon(Icons.sync_rounded, size: 18),
                                  label: const Text('Sync Now'),
                                ),
                              FilledButton.icon(
                                onPressed:
                                    _isProcessing ? null : _setCloudSyncFolder,
                                icon: const Icon(Icons.folder_open_rounded,
                                    size: 18),
                                label: Text(
                                  cloudEnabled ? 'Change Folder' : 'Connect',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (cloudEnabled) ...[
                      const SizedBox(height: 12),
                      _ActionCard(
                        icon: Icons.cloud_upload_rounded,
                        iconColor: AppColors.info,
                        title: 'Upload This Device',
                        subtitle:
                            'Replace the cloud copy with this device database.',
                        onTap: _isProcessing
                            ? null
                            : () => _uploadLocalCloudCopy(),
                      ),
                      const SizedBox(height: 12),
                      _ActionCard(
                        icon: Icons.cloud_download_rounded,
                        iconColor: AppColors.accent,
                        title: 'Download Cloud Copy',
                        subtitle:
                            'Use the cloud database on this device, then restart.',
                        onTap:
                            _isProcessing ? null : () => _downloadCloudCopy(),
                      ),
                    ],
                    const SizedBox(height: 36),

                    // ─── Auto Backup ───
                    Text('Daily Auto-Backup',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _autoBackupPath != null
                            ? AppColors.success.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _autoBackupPath != null
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_autoBackupPath != null
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _autoBackupPath != null
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  color: _autoBackupPath != null
                                      ? AppColors.success
                                      : AppColors.warning,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _autoBackupPath != null
                                    ? 'Auto-Backup Enabled'
                                    : 'Auto-Backup Disabled',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: _autoBackupPath != null
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _autoBackupPath != null
                                ? 'Backing up daily to:\n$_autoBackupPath'
                                : 'Select a synced folder. The app will automatically save a backup every day.',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_autoBackupPath != null)
                                TextButton(
                                  onPressed: _disableAutoBackup,
                                  child: Text('Disable',
                                      style: GoogleFonts.inter(
                                          color: AppColors.danger)),
                                ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _setAutoBackupFolder,
                                icon: const Icon(Icons.folder_open_rounded,
                                    size: 18),
                                label: Text(_autoBackupPath != null
                                    ? 'Change Folder'
                                    : 'Set Folder'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),
                    Text('Manual Actions',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 12),

                    // ─── Export ───
                    _ActionCard(
                      icon: Icons.upload_file_rounded,
                      iconColor: AppColors.info,
                      title: 'Export Backup',
                      subtitle:
                          'Save a copy of your database to your PC or Cloud folder.',
                      onTap: _isProcessing ? null : _exportBackup,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.table_view_rounded,
                      iconColor: AppColors.accent,
                      title: 'Export CSV',
                      subtitle:
                          'Create a portable spreadsheet snapshot of transactions, expenses, and ledger entries.',
                      onTap: _isProcessing ? null : _exportCsvSnapshot,
                    ),
                    const SizedBox(height: 12),

                    // ─── Restore ───
                    _ActionCard(
                      icon: Icons.restore_rounded,
                      iconColor: AppColors.warning,
                      title: 'Restore Backup',
                      subtitle:
                          'Replace your current database with a saved backup file.',
                      onTap: _isProcessing ? null : _restoreBackup,
                    ),
                  ],
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ));
  }
}

class _SyncDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _SyncDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.3)
                  : AppColors.divider),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                      color: widget.iconColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(widget.subtitle,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
