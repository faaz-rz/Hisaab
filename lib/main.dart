import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_router.dart';
import 'services/database_service.dart';
import 'services/agency_service.dart';
import 'services/bank_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/session_service.dart';
import 'widgets/profile_gate.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SessionService.instance.initializeProfile = initializeProfile;
  runApp(const ProfileGate());
}

Future<void> initializeProfile() async {
  // Preserve the installed client's records before opening or syncing them.
  await DatabaseService.instance.prepareUpgradeBackup();
  // Import all existing profiles' ledger rows once, before cloud/profile restores.
  await DatabaseService.instance.ledgerDatabase;

  // Pull or publish the latest cloud copy before opening providers.
  await CloudSyncService.instance.syncOnStartup();

  // Run background auto-backup if configured
  await DatabaseService.instance.runDailyAutoBackup();

  // Initialize agency registry & backfill from existing data
  await AgencyService.instance.ensureTable();
  await _backfillAgencies();

  // Initialize bank registry & backfill from existing ledger
  await BankService.instance.ensureTable();
  await _backfillBanks();

  // Backfills can create lookup rows, so publish them if cloud sync is enabled.
  await CloudSyncService.instance.pushLocalIfEnabled();
}

/// One-time backfill: scan existing transactions for agency_code+agency_name
/// and populate the agencies table so old data is also covered.
Future<void> _backfillAgencies() async {
  try {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT agency_code, agency_name FROM transactions WHERE agency_code IS NOT NULL AND agency_code != '' AND agency_name IS NOT NULL AND agency_name != ''");
    for (final row in rows) {
      await AgencyService.instance.saveAgency(
        row['agency_code'] as String,
        row['agency_name'] as String,
      );
    }
  } catch (e) {
    debugPrint('Backfill agency error: $e');
  }
}

/// One-time backfill: scan existing bank_ledger for bank details
/// and populate the banks table so old data is covered.
Future<void> _backfillBanks() async {
  try {
    final db = await DatabaseService.instance.ledgerDatabase;
    final rows = await db.rawQuery(
        "SELECT DISTINCT bank_name, bank_code, account_no FROM bank_ledger WHERE bank_name IS NOT NULL AND bank_name != ''");
    for (final row in rows) {
      await BankService.instance.saveBank(
        row['bank_name'] as String,
        bankCode: row['bank_code'] as String?,
        accountNo: row['account_no'] as String?,
      );
    }
  } catch (e) {
    debugPrint('Backfill bank error: $e');
  }
}

// ─── Design Tokens ───────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF1B2A4A); // Deep navy
  static const Color primaryLight = Color(0xFF2D4373); // Medium navy
  static const Color accent = Color(0xFF00897B); // Teal accent
  static const Color accentLight = Color(0xFF4DB6AC); // Light teal
  static const Color surface = Color(0xFFF5F7FA); // Off-white bg
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF059669); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFDC2626); // Red
  static const Color info = Color(0xFF2563EB); // Blue
}

class PharmacyApp extends ConsumerWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'HISAAB',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        builder: (context, opacity, _) =>
            Opacity(opacity: opacity, child: child),
      ),
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
