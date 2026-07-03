import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/month_year_picker.dart';

mixin DateFilterMixin<T extends StatefulWidget> on State<T> {
  DateTimeRange? dateRange;

  Future<void> pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: dateRange,
    );
    if (range != null && mounted) {
      setState(() => dateRange = range);
    }
  }

  void clearDateRange() {
    setState(() => dateRange = null);
  }

  Future<void> pickMonth() async {
    final date = await showMonthYearPicker(context, onlyYear: false);
    if (date != null && mounted) {
      setState(() {
        dateRange = DateTimeRange(
          start: DateTime(date.year, date.month, 1),
          end: DateTime(date.year, date.month + 1, 0),
        );
      });
    }
  }

  Future<void> pickYear() async {
    final date = await showMonthYearPicker(context, onlyYear: true);
    if (date != null && mounted) {
      setState(() {
        dateRange = DateTimeRange(
          start: DateTime(date.year, 1, 1),
          end: DateTime(date.year, 12, 31),
        );
      });
    }
  }

  void setPresetDateRange(String preset) {
    final now = DateTime.now();
    DateTime start;
    final end = now;

    if (preset == 'week') {
      start = now.subtract(Duration(days: now.weekday - 1));
    } else if (preset == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else if (preset == 'year') {
      start = DateTime(now.year, 1, 1);
    } else {
      clearDateRange();
      return;
    }

    setState(() => dateRange = DateTimeRange(start: start, end: end));
  }

  Future<void> handleDateFilterSelection(String value) async {
    if (value == 'custom') {
      await pickDateRange();
    } else if (value == 'pick_month') {
      await pickMonth();
    } else if (value == 'pick_year') {
      await pickYear();
    } else {
      setPresetDateRange(value);
    }
  }

  bool isWithinRange(String dateStr) {
    if (dateRange == null) return true;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    return date.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
        date.isBefore(dateRange!.end.add(const Duration(days: 1)));
  }

  String periodLabel(DateFormat fmtDate, {String allLabel = 'All Time'}) {
    if (dateRange == null) return allLabel;

    final start = dateRange!.start;
    final end = dateRange!.end;
    final monthEnd = DateTime(start.year, start.month + 1, 0);
    final isFullMonth = start.day == 1 &&
        start.year == end.year &&
        start.month == end.month &&
        end.day == monthEnd.day;
    if (isFullMonth) return DateFormat('MMMM yyyy').format(start);

    final isFullYear = start.month == 1 &&
        start.day == 1 &&
        end.year == start.year &&
        end.month == 12 &&
        end.day == 31;
    if (isFullYear) return start.year.toString();

    return '${fmtDate.format(start)} - ${fmtDate.format(end)}';
  }

  List<PopupMenuEntry<String>> buildFilterMenu({
    String allLabel = 'All Time',
  }) {
    return [
      PopupMenuItem(value: 'all', child: Text(allLabel)),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'week', child: Text('This Week')),
      const PopupMenuItem(value: 'month', child: Text('This Month')),
      const PopupMenuItem(value: 'year', child: Text('This Year')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'pick_month', child: Text('Select Month...')),
      const PopupMenuItem(value: 'pick_year', child: Text('Select Year...')),
      const PopupMenuItem(value: 'custom', child: Text('Custom Date Range...')),
    ];
  }
}
