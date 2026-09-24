import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_management/services/entry_service.dart';
import 'package:pharmacy_management/widgets/save_entry.dart';

void main() {
  testWidgets('same-date sales message does not retry or offer an override',
      (tester) async {
    final attempts = <bool>[];
    bool? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                    onPressed: () async {
                      saved = await saveEntry(context, (allowDuplicate) async {
                        attempts.add(allowDuplicate);
                        if (!allowDuplicate) {
                          throw const DuplicateEntryException(12,
                              date: '2026-09-24');
                        }
                      });
                    },
                    child: const Text('Save'))))));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Sales already recorded for this date'), findsOneWidget);
    expect(find.text('Save another copy'), findsNothing);
    await tester.tap(find.text('Back to sale'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(attempts, [false]);
  });
}
