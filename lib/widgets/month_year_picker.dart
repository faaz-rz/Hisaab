import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<DateTime?> showMonthYearPicker(BuildContext context, {bool onlyYear = false}) async {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(onlyYear ? 'Select Year' : 'Select Month'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Year: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<int>(
                        value: selectedYear,
                        isExpanded: true,
                        items: List.generate(20, (i) => DateTime.now().year - i)
                            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                            .toList(),
                        onChanged: (val) => setState(() => selectedYear = val!),
                      ),
                    ),
                  ],
                ),
                if (!onlyYear) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Month: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text(DateFormat('MMMM').format(DateTime(2020, m)))))
                              .toList(),
                          onChanged: (val) => setState(() => selectedMonth = val!),
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, DateTime(selectedYear, selectedMonth, 1)),
                  child: const Text('Select')),
            ],
          );
        },
      );
    },
  );
}
