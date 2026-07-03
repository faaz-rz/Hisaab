import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CsvExportService {
  static Future<void> generateAndOpenCsv({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    String? subtitle,
    String? totalAmountLabel,
    String? totalAmount,
  }) async {
    final rows = <List<String>>[];
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      rows.add([title]);
      rows.add([subtitle]);
      rows.add([]);
    }
    rows.add(headers);
    rows.addAll(data);
    if (totalAmountLabel != null && totalAmount != null) {
      rows.add([]);
      rows.add([totalAmountLabel, totalAmount]);
    }

    final csv = rows.map(_encodeRow).join('\n');
    final directory = await getApplicationDocumentsDirectory();
    final filename =
        '${_safeFilename(title)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File(p.join(directory.path, filename));

    await file.writeAsString(csv, encoding: utf8);
    await OpenFilex.open(file.path);
  }

  static String _encodeRow(List<String> row) {
    return row.map(_encodeCell).join(',');
  }

  static String _encodeCell(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final escaped = normalized.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static String _safeFilename(String title) {
    final normalized =
        title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
