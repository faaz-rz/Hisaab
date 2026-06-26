import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_router.dart';
import 'services/database_service.dart';
import 'services/agency_service.dart';
import 'services/bank_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Run background auto-backup if configured
  await DatabaseService.instance.runDailyAutoBackup();

  // Initialize agency registry & backfill from existing data
  await AgencyService.instance.ensureTable();
  await _backfillAgencies();

  // Initialize bank registry & backfill from existing ledger
  await BankService.instance.ensureTable();
  await _backfillBanks();

  runApp(const ProviderScope(child: PharmacyApp()));
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
  } catch (_) {}
}

/// One-time backfill: scan existing bank_ledger for bank details
/// and populate the banks table so old data is covered.
Future<void> _backfillBanks() async {
  try {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT bank_name, bank_code, account_no FROM bank_ledger WHERE bank_name IS NOT NULL AND bank_name != ''");
    for (final row in rows) {
      await BankService.instance.saveBank(
        row['bank_name'] as String,
        bankCode: row['bank_code'] as String?,
        accountNo: row['account_no'] as String?,
      );
    }
  } catch (_) {}
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
    final textTheme = GoogleFonts.interTextTheme();

    return MaterialApp.router(
      title: 'HISAAB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: textTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          tertiary: AppColors.accentLight,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.divider.withOpacity(0.5)),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          labelStyle:
              GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
          hintStyle: GoogleFonts.inter(
              color: AppColors.textSecondary.withOpacity(0.6)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withOpacity(0.15),
          ),
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 0,
        ),
        dialogTheme: DialogTheme(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        chipTheme: ChipThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide.none,
          labelStyle:
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        popupMenuTheme: PopupMenuThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
        ),
      ),
      routerConfig: router,
    );
  }
}
