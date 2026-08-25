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
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(hintText: 'Description'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
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
              child: const Text('Add Log'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Service Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
