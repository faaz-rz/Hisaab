import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pharmacy_management/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: PharmacyApp()));

    // Verify that the app builds and we see the shell branding.
    expect(find.text('HISAAB'), findsOneWidget);
  });
}
