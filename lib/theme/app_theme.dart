import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

/// Shared visual rules; all existing HISAAB palette values are retained.
ThemeData buildAppTheme() {
  final text = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
  final rounded =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        tertiary: AppColors.accentLight,
        surface: AppColors.cardBg),
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: text.copyWith(
      headlineLarge: GoogleFonts.inter(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
          color: AppColors.textPrimary),
      headlineSmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
          color: AppColors.textPrimary),
      titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          color: AppColors.textPrimary),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, height: 1.5, color: AppColors.textPrimary),
      labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cardBg,
      foregroundColor: AppColors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 86,
      titleSpacing: 24,
      titleTextStyle: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
          color: AppColors.textPrimary),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 21),
      actionsIconTheme:
          const IconThemeData(color: AppColors.textSecondary, size: 21),
      shape: const Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.divider))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger)),
      labelStyle:
          GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
      hintStyle:
          GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
      helperStyle: GoogleFonts.inter(
          fontSize: 11, height: 1.4, color: AppColors.textSecondary),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 46),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: rounded,
            textStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(44, 42),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: rounded,
            textStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(44, 44),
            side: const BorderSide(color: AppColors.divider),
            shape: rounded,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            shape: rounded,
            textStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        hoverElevation: 4,
        focusElevation: 3,
        shape: rounded,
        extendedTextStyle:
            GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textSecondary,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
          color: AppColors.accent.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(10)),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: .12),
        labelTextStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500))),
    dividerTheme: const DividerThemeData(
        color: AppColors.divider, thickness: 1, space: 1),
    dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.divider)),
        titleTextStyle: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
        contentTextStyle: GoogleFonts.inter(
            fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
    chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
    popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.divider)),
        elevation: 5),
    tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 400),
        textStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: rounded,
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
