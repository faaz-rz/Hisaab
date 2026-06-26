import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../main.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isProcessing = false;
  String? _autoBackupPath;

  @override
  void initState() {
    super.initState();
    _loadAutoBackupPath();
  }

  Future<void> _loadAutoBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackupPath = prefs.getString('auto_backup_path');
    });
  }

  Future<void> _setAutoBackupFolder() async {
    final String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Auto-Backup Folder',
    );
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_backup_path', selectedDirectory);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _disableAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auto_backup_path');
    setState(() {
      _autoBackupPath = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Auto-backup disabled.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isProcessing = true);
    try {
      final dbPath = await DatabaseService.instance.getDatabaseFilePath();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Folder to Save Backup',
      );

      if (selectedDirectory != null) {
        final savePath = '$selectedDirectory\\pharmacy_backup_$dateStr.db';
        final dbFile = File(dbPath);
        await dbFile.copy(savePath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved to:\n$savePath'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
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
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'WARNING: Restoring a backup will OVERWRITE your current database entirely. '
              'Any changes made since this backup was created will be permanently lost.\n\n'
              'Are you sure you want to proceed?'
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Restore'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final dbPath = await DatabaseService.instance.getDatabaseFilePath();
          final backupFile = File(backupPath);
          await backupFile.copy(dbPath);

          if (mounted) {
             showDialog(
               context: context,
               barrierDismissible: false,
               builder: (ctx) => AlertDialog(
                 title: Text('Restore Successful', style: GoogleFonts.inter(color: AppColors.success)),
                 content: const Text('The database has been restored successfully.\n\nPLEASE RESTART THE APPLICATION to load the restored data.'),
                 actions: [
                   FilledButton(
                     onPressed: () => exit(0),
                     child: const Text('Close Application'),
                   ),
                 ],
               )
             );
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Backup & Sync'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    child: const Icon(Icons.cloud_sync_rounded, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Local Cloud Backup',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export your database to a secure location such as OneDrive or Google Drive.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),

                // ─── Auto Backup ───
                Text('Daily Auto-Backup', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _autoBackupPath != null ? AppColors.success.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _autoBackupPath != null ? AppColors.success.withOpacity(0.3) : AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_autoBackupPath != null ? AppColors.success : AppColors.warning).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _autoBackupPath != null ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              color: _autoBackupPath != null ? AppColors.success : AppColors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _autoBackupPath != null ? 'Auto-Backup Enabled' : 'Auto-Backup Disabled',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: _autoBackupPath != null ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _autoBackupPath != null 
                          ? 'Backing up daily to:\n$_autoBackupPath'
                          : 'Select a synced folder. The app will automatically save a backup every day.',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_autoBackupPath != null)
                            TextButton(
                              onPressed: _disableAutoBackup,
                              child: Text('Disable', style: GoogleFonts.inter(color: AppColors.danger)),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _setAutoBackupFolder,
                            icon: const Icon(Icons.folder_open_rounded, size: 18),
                            label: Text(_autoBackupPath != null ? 'Change Folder' : 'Set Folder'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 36),
                Text('Manual Actions', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 12),

                // ─── Export ───
                _ActionCard(
                  icon: Icons.upload_file_rounded,
                  iconColor: AppColors.info,
                  title: 'Export Backup',
                  subtitle: 'Save a copy of your database to your PC or Cloud folder.',
                  onTap: _isProcessing ? null : _exportBackup,
                ),
                const SizedBox(height: 12),

                // ─── Restore ───
                _ActionCard(
                  icon: Icons.restore_rounded,
                  iconColor: AppColors.warning,
                  title: 'Restore Backup',
                  subtitle: 'Replace your current database with a saved backup file.',
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
          border: Border.all(color: _isHovered ? widget.iconColor.withOpacity(0.3) : AppColors.divider),
          boxShadow: _isHovered
              ? [BoxShadow(color: widget.iconColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]
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
                      color: widget.iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(widget.subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withOpacity(0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
