import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmacy_management/main.dart';
import 'package:pharmacy_management/services/account_service.dart';
import 'package:pharmacy_management/services/database_service.dart';
import 'package:pharmacy_management/services/session_service.dart';
import 'package:pharmacy_management/widgets/profile_gate.dart';

class _TestPaths extends PathProviderPlatform {
  final String directory;
  _TestPaths(this.directory);
  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

void main() {
  testWidgets(
      'first launch explains legacy records and validates profile setup',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProfileGate());
    await tester.pumpAndSettle();
    expect(find.text('Set up your existing profile'), findsOneWidget);
    expect(
        find.textContaining('Your transactions, expenses and ledger will stay'),
        findsOneWidget);
    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets(
      'login gates records; switching destroys the old router and section access',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final originalPaths = PathProviderPlatform.instance;
    final directory = Directory.systemTemp.createTempSync('hisaab-login-ui-');
    PathProviderPlatform.instance = _TestPaths(directory.path);
    final session = SessionService.instance;
    session.initializeProfile = initializeProfile;
    final accounts = AccountService.instance;
    late LocalProfile first;
    late LocalProfile second;
    await tester.runAsync(() async {
      await accounts.load();
      first = await accounts.create('Original business', 'first-password');
      second = await accounts.create('Second business', 'second-password');
    });
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.runAsync(() => DatabaseService.instance.close());
      session.current = null;
      PathProviderPlatform.instance = originalPaths;
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(const ProfileGate());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    await tester.runAsync(() async {
      await expectLater(session.signIn(first, 'wrong-password'),
          throwsA(isA<AccountException>()));
    });
    expect(session.current, isNull);
    await tester.runAsync(() => session.signIn(first, 'first-password'));
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Original business'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    await tester.tap(find.text('Original business'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Original business'), findsOneWidget);
    expect(find.text('Add profile'), findsOneWidget);
    await tester.runAsync(() => session.signOut());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Signed in as Original business'), findsNothing);
    await tester.runAsync(() => session.signIn(second, 'second-password'));
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Second business'), findsOneWidget);
    expect(find.text('Original business'), findsNothing);
    await tester.tap(find.text('Bank Ledger'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
