import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmacy_management/main.dart';
import 'package:pharmacy_management/services/account_service.dart';
import 'package:pharmacy_management/services/database_service.dart';
import 'package:pharmacy_management/services/session_service.dart';
import 'package:pharmacy_management/services/password_service.dart';
import 'package:pharmacy_management/widgets/add_sale_dialog.dart';
import 'package:pharmacy_management/widgets/password_auth_gate.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  testWidgets('workspace navigation, responsive dashboard and sales-date guard',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final originalPaths = PathProviderPlatform.instance;
    final directory =
        Directory.systemTemp.createTempSync('hisaab-workspace-ui-');
    PathProviderPlatform.instance = _Paths(directory.path);
    final database = DatabaseService.instance;
    final session = SessionService.instance;
    session.initializeProfile = initializeProfile;
    await tester.runAsync(() async {
      final fonts = FontLoader('Inter')
        ..addFont(
            rootBundle.load('assets/fonts/google_fonts/Inter-Regular.ttf'));
      await fonts.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      await AccountService.instance.load();
      final profile = await AccountService.instance
          .create('Sample Pharmacy', '', passwordRequired: false);
      await session.signIn(profile, '');
      await PasswordService.instance.setSalesPassword('1234');
      await PasswordService.instance.setLedgerPassword('1234');
      final db = await database.database;
      final day = DateTime.now().toIso8601String();
      await db.insert('transactions', {
        'type': 'sale',
        'date': day,
        'total_amount': 24500,
        'upi_amount': 8200,
        'profit': 4900
      });
      await db.insert('transactions', {
        'type': 'purchase_cash',
        'date': day,
        'total_amount': 7800,
        'agency_name': 'Sample Supplies',
        'agency_code': 'SS',
        'bill_no': 'INV-001'
      });
      await db.insert('transactions', {
        'type': 'purchase_credit',
        'date': day,
        'total_amount': 3200,
        'agency_name': 'Sample Supplies',
        'agency_code': 'SS',
        'bill_no': 'INV-002'
      });
      await db.insert('expenses',
          {'category_id': 1, 'date': day, 'amount': 350, 'item': 'Stationery'});
      await (await database.ledgerDatabase).insert('bank_ledger', {
        'type': 'deposit',
        'bank_name': 'Sample Bank',
        'bank_code': 'SB',
        'account_no': '00123',
        'date': day,
        'amount': 12000,
        'purpose': 'Opening balance'
      });
    });
    addTearDown(() async {
      await tester.runAsync(() => database.close());
      session.current = null;
      PathProviderPlatform.instance = originalPaths;
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    });
    Future<void> settle() async {
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      if (const bool.fromEnvironment('HISAAB_CAPTURE')) {
        await expectLater(
            find.byType(PharmacyApp), matchesGoldenFile('previews/$name.png'));
      }
    }

    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(const ProviderScope(child: PharmacyApp()));
    await settle();
    expect(find.text('Total Sales'), findsOneWidget);
    await capture('workspace-dashboard');
    for (final size in [const Size(900, 720), const Size(390, 844)]) {
      await tester.binding.setSurfaceSize(size);
      await settle();
    }
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    await settle();
    for (final section in [
      'Transactions',
      'Expenses',
      'Reports',
      'Bank Ledger'
    ]) {
      await tester.tap(find.text(section).first);
      await settle();
      if (find.byType(PasswordAuthGate).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextFormField).first, '1234');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle();
      }
      await capture('workspace-${section.toLowerCase().replaceAll(' ', '-')}');
      if (section == 'Transactions') {
        await tester.tap(find.text('Add Sale'));
        await settle();
        expect(find.byType(AddSaleDialog), findsOneWidget);
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Sales Amount'), '999');
        await capture('workspace-sale-form');
        await tester.tap(find.text('Save Sale'));
        // The underlying form remains in its saving state while this modal is open.
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(seconds: 1));
        expect(
            find.text('Sales already recorded for this date'), findsOneWidget);
        await tester.tap(find.text('Back to sale'));
        await settle();
        expect(find.text('999'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await settle();
      }
      if (section == 'Reports') {
        for (final name in [
          'Total Purchases',
          'Credit Purchases',
          'Cash Purchases',
          'Credit Payments',
          'Credit Notes',
          'Unpaid Agencies',
          'Agency-wise'
        ]) {
          await tester.ensureVisible(find.widgetWithText(Tab, name));
          await tester.tap(find.widgetWithText(Tab, name));
          await settle();
        }
      }
      await tester.binding.setSurfaceSize(const Size(900, 720));
      await settle();
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      await settle();
    }
    await tester.tap(find.text('Sample Bank'));
    await settle();
    await capture('workspace-bank-detail');
    await tester.tap(find.text('Backup & Sync'));
    await settle();
    expect(find.text('Export Backup'), findsOneWidget);
    await tester.runAsync(() async {
      final db = await database.database;
      final rows = await db.query('transactions', where: "type = 'sale'");
      expect(rows.length, 1);
      expect(rows.single['total_amount'], 24500);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
