import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndPrintPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    String? subtitle,
    String? totalAmountLabel,
    String? totalAmount,
  }) async {
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(title, subtitle),
            pw.SizedBox(height: 20),
            _buildTable(headers, data),
            if (totalAmountLabel != null && totalAmount != null) ...[
              pw.SizedBox(height: 20),
              _buildFooter(totalAmountLabel, totalAmount),
            ]
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    
    final directory = await getApplicationDocumentsDirectory();
    final filename = '${title.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${directory.path}/$filename');
    
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }

  static pw.Widget _buildHeader(String title, String? subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
        ],
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildTable(List<String> headers, List<List<String>> data) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 30,
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: i == headers.length - 1 ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      },
      cellPadding: const pw.EdgeInsets.all(8),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static pw.Widget _buildFooter(String label, String amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          amount,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
        ),
      ],
    );
  }
}
