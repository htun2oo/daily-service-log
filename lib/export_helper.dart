import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ExportHelper {
  /// Service log data များကို CSV ဖိုင်အဖြစ် ပြောင်းလဲပြီး Share ပြုလုပ်ပေးသည့် function
  static Future<void> exportToCSV(List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) {
      return;
    }

    // CSV Header သတ်မှတ်ခြင်း
    List<List<dynamic>> rows = [
      [
        'ID',
        'Date',
        'Customer Name',
        'Service Type',
        'Amount',
        'Remarks',
      ]
    ];

    // Data row များကို ထည့်သွင်းခြင်း
    for (var log in logs) {
      rows.add([
        log['id'] ?? '',
        log['date'] ?? '',
        log['customer_name'] ?? log['title'] ?? '',
        log['service_type'] ?? log['description'] ?? '',
        log['amount'] ?? '',
        log['remarks'] ?? '',
      ]);
    }

    // CSV format သို့ ပြောင်းလဲခြင်း
    String csvData = const ListToCsvConverter().convert(rows);

    // ဖိုင်သိမ်းဆည်းမည့် လမ်းကြောင်းကို ရယူခြင်း
    final directory = await getTemporaryDirectory();
    final String formattedDate =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String filePath = '${directory.path}/service_logs_$formattedDate.csv';

    final File file = File(filePath);
    await file.writeAsString(csvData);

    // ဖိုင်ကို Share ပြုလုပ်ခြင်း
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Daily Service Logs Export ($formattedDate)',
    );
  }
}
