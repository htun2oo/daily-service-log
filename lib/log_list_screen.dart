import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'export_helper.dart';
import 'pdf_helper.dart';
import 'pdf_preview_screen.dart';
import 'date_range_dialog.dart';

class LogListScreen extends StatefulWidget {
  const LogListScreen({Key? key}) : super(key: key);

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  // Database ထဲမှ log စာရင်းများကို ပြန်လည်ဆွဲယူခြင်း
  Future<void> _refreshLogs() async {
    setState(() => _isLoading = true);
    final data = await DBHelper.instance.queryAllRows();
    setState(() {
      _logs = data;
      _isLoading = false;
    });
  }

  // Log အသစ်ထည့်ခြင်း သို့မဟုတ် ပြင်ဆင်ခြင်းအတွက် Dialog
  void _showFormDialog({Map<String, dynamic>? log}) {
    final titleController = TextEditingController(
        text: log != null ? (log['customer_name'] ?? log['title'] ?? '') : '');
    final descController = TextEditingController(
        text: log != null ? (log['service_type'] ?? log['description'] ?? '') : '');
    final amountController = TextEditingController(
        text: log != null ? (log['amount']?.toString() ?? '') : '');
    final remarksController = TextEditingController(
        text: log != null ? (log['remarks'] ?? '') : '');
    String selectedDate = log != null
        ? (log['date'] ?? log['created_at'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()))
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(log == null ? 'Add Service Log' : 'Edit Service Log'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(selectedDate),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(selectedDate) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Customer / Title'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Service Type / Description'),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                final rowData = {
                  'customer_name': titleController.text.trim(),
                  'title': titleController.text.trim(),
                  'service_type': descController.text.trim(),
                  'description': descController.text.trim(),
                  'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                  'remarks': remarksController.text.trim(),
                  'date': selectedDate,
                  'created_at': selectedDate,
                };

                if (log == null) {
                  await DBHelper.instance.insertItem(rowData);
                } else {
                  rowData['id'] = log['id'];
                  await DBHelper.instance.updateItem(rowData);
                }

                if (mounted) {
                  Navigator.of(ctx).pop();
                  _refreshLogs();
                }
              },
              child: Text(log == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Data ဖျက်ခြင်း
  Future<void> _deleteLog(int id) async {
    await DBHelper.instance.deleteItem(id);
    _refreshLogs();
  }

  // PDF Export ပြုလုပ်ရန် Function
  Future<void> _handlePdfExport() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => const DateRangeDialog(),
    );

    if (result != null) {
      final startDate = result['startDate'];
      final endDate = result['endDate'];

      final filteredLogs = _logs.where((item) {
        final dateStr = item['date'] ?? item['created_at'];
        if (dateStr == null) return false;
        final d = DateTime.tryParse(dateStr);
        if (d == null) return false;
        return d.isAfter(startDate!.subtract(const Duration(days: 1))) &&
            d.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();

      final pdfBytes = await PdfHelper.generatePdf(
        logs: filteredLogs.isNotEmpty ? filteredLogs : _logs,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              title: 'Service Log Report',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Service Logs'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _handlePdfExport,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: () async {
              if (_logs.isNotEmpty) {
                await ExportHelper.exportToCSV(_logs);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No records to export.')),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No service logs found. Tap + to add.'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (ctx, index) {
                    final item = _logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(
                          item['customer_name'] ?? item['title'] ?? 'No Title',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Service: ${item['service_type'] ?? item['description'] ?? '-'}'),
                            Text('Date: ${item['date'] ?? item['created_at'] ?? '-'}'),
                            if (item['remarks'] != null && item['remarks'].toString().isNotEmpty)
                              Text('Remarks: ${item['remarks']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item['amount'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showFormDialog(log: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteLog(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.blueGrey,
        child: const Icon(Icons.add),
      ),
    );
  }
}
