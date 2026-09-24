import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmacy_management/services/account_service.dart';
import 'package:pharmacy_management/services/profile_photo.dart';
import 'package:pharmacy_management/services/session_service.dart';
import 'package:pharmacy_management/widgets/profile_gate.dart';
import 'package:pharmacy_management/widgets/profile_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionService.instance.current = null;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
      'picker is responsive, passwords clear on back, and photos render',
      (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Inter');
      loader.addFont(
          rootBundle.load('assets/fonts/google_fonts/Inter-Regular.ttf'));
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final accounts = AccountService.instance;
      await accounts.load();
      await accounts.create('Personal', '1234');
      await accounts.create('Pharmacy', '', passwordRequired: false);
    });
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const RepaintBoundary(child: ProfileGate()));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileAvatar), findsNWidgets(2));
    expect(find.text('Password protected'), findsOneWidget);
    expect(find.text('Tap to open'), findsOneWidget);
    if (const bool.fromEnvironment('HISAAB_CAPTURE')) {
      await expectLater(find.byType(ProfileGate),
          matchesGoldenFile('previews/profile-picker.png'));
    }
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('login-password')), '9999');
    await tester.tap(find.text('All profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('login-password')))
            .controller!
            .text,
        isEmpty);
    if (const bool.fromEnvironment('HISAAB_CAPTURE')) {
      await expectLater(find.byType(ProfileGate),
          matchesGoldenFile('previews/profile-password.png'));
    }
    await tester.tap(find.text('All profiles'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Personal'));
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('All profiles'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add profile'));
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    expect(find.text('Require a password'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('HISAAB_CAPTURE')) {
      await expectLater(find.byType(ProfileGate),
          matchesGoldenFile('previews/profile-setup.png'));
    }
  });

  test('photo thumbnails are square, bounded, and independent of source files',
      () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 400, 200),
        ui.Paint()..color = const Color(0xFF00897B));
    final picture = recorder.endRecording();
    final image = await picture.toImage(400, 200);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final encoded = await prepareProfilePhoto(bytes!.buffer.asUint8List());
    final codec = await ui.instantiateImageCodec(base64Decode(encoded));
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 256);
    expect(frame.image.height, 256);
    frame.image.dispose();
    codec.dispose();
    image.dispose();
    picture.dispose();
    await expectLater(prepareProfilePhoto(Uint8List(5 * 1024 * 1024 + 1)),
        throwsA(isA<AccountException>()));
    await expectLater(
        prepareProfilePhoto(Uint8List.fromList([1, 2, 3])), throwsA(anything));
  });
}
