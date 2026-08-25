import 'package:flutter/material.dart';
import 'db_helper.dart';

class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  List<Map<String, dynamic>> _logs = [];
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() async {
    final data = await DBHelper.getLogs();
    setState(() {
      _logs = data;
    });
  }

  // Service Log Form (Add/Create Dialog)
  void _showForm(int? id) async {
    _titleController.clear();
    _descController.clear();

    showModalBottomSheet(
      context: context,
      elevation: 5,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          top: 15,
          left: 15,
          right: 15,
          bottom: MediaQuery.of(context).viewInsets.bottom + 120,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'New Service Log Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title / Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description / Service Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Log'),
              onPressed: () async {
                if (_titleController.text.isNotEmpty) {
                  await DBHelper.insertLog({
                    'title': _titleController.text,
                    'description': _descController.text,
                    'date': DateTime.now().toString(),
                  });
                  _titleController.clear();
                  _descController.clear();
                  if (mounted) Navigator.of(context).pop();
                  _refreshLogs();
                }
              },
            )
          ],
        ),
      ),
    );
  }

  // Settings Dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text('Settings'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Database Status: Connected (Local SQLite)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Service Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // PopMenu ထဲတွင် Form တည်ဆောက်ခြင်းနှင့် Settings တို့ ထည့်သွင်းထားခြင်း
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Menu Options',
            onSelected: (String value) {
              if (value == 'add_log') {
                _showForm(null); // Service Log Form ဖွင့်ရန်
              } else if (value == 'settings') {
                _showSettingsDialog(); // Settings Dialog ဖွင့်ရန်
              } else if (value == 'all') {
                _refreshLogs();
              } else if (value == 'latest') {
                setState(() {
                  _logs.sort((a, b) => b['id'].compareTo(a['id']));
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'add_log',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Create New Log'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Show All Logs'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'latest',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Sort Newest First'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(child: Text('No Logs Found'))
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(_logs[index]['title'] ?? ''),
                  subtitle: Text(_logs[index]['description'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await DBHelper.deleteLog(_logs[index]['id']);
                      _refreshLogs();
                    },
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
