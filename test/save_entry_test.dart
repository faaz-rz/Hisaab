import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_management/services/entry_service.dart';
import 'package:pharmacy_management/widgets/save_entry.dart';

void main() {
  testWidgets(
      'duplicate warning cancels without another save; confirmation retries once',
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
                          throw const DuplicateEntryException(12);
                        }
                      });
                    },
                    child: const Text('Save'))))));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Possible duplicate entry'), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(attempts, [false]);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save another copy'));
    await tester.pumpAndSettle();
    expect(saved, true);
    expect(attempts, [false, false, true]);
  });
}
