import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_management/services/entry_service.dart';
import 'package:pharmacy_management/widgets/save_entry.dart';

void main() {
  testWidgets('purchase duplicate shows bill and agency without retrying',
      (tester) async {
    var attempts = 0;
    bool? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                    onPressed: () async {
                      saved = await saveEntry(context, (_) async {
                        attempts++;
                        throw const DuplicateEntryException.purchase(5,
                            billNo: 'INV-001', agency: 'Agency A');
                      });
                    },
                    child: const Text('Save'))))));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Bill number already recorded for this agency'),
        findsOneWidget);
    expect(find.textContaining('INV-001 already exists for Agency A'),
        findsOneWidget);
    await tester.tap(find.text('Back to purchase'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(attempts, 1);
  });
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
