import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfHelper {
  /// Service Logs data များမှ PDF Document byte data ထုတ်ပေးသည့် function
  static Future<Uint8List> generatePdf({
    required List<Map<String, dynamic>> logs,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // ရက်စွဲ format သတ်မှတ်ခြင်း
    final dateFormatter = DateFormat('yyyy-MM-dd');
    String dateRangeText = 'All Records';

    if (startDate != null && endDate != null) {
      dateRangeText =
          '${dateFormatter.format(startDate)} to ${dateFormatter.format(endDate)}';
    }

    // စုစုပေါင်း Amount တွက်ချက်ခြင်း
    double totalAmount = 0.0;
    for (var log in logs) {
      final amountVal = log['amount'];
      if (amountVal != null) {
        totalAmount += double.tryParse(amountVal.toString()) ?? 0.0;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Daily Service Log Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Date Range & Summary Info
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date Range: $dateRangeText',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Total Records: ${logs.length}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Data Table
            pw.TableHelper.fromTextArray(
              headers: [
                'No.',
                'Date',
                'Customer Name',
                'Service Type',
                'Amount',
                'Remarks'
              ],
              data: List<List<dynamic>>.generate(logs.length, (index) {
                final log = logs[index];
                return [
                  (index + 1).toString(),
                  log['date'] ?? '',
                  log['customer_name'] ?? log['title'] ?? '',
                  log['service_type'] ?? log['description'] ?? '',
                  log['amount']?.toString() ?? '0',
                  log['remarks'] ?? '',
                ];
              }),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
            ),
            pw.SizedBox(height: 16),

            // Total Amount Display
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blueGrey),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
