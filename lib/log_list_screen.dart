import 'dart:convert';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'main.dart';

class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  List<Map<String, dynamic>> _logs = [];
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // Dynamic Custom Fields စီမံရန် List
  final List<Map<String, TextEditingController>> _customFields = [];

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

  // Blank Custom Field သစ်တစ်ခု ထည့်သွင်းခြင်း
  void _addCustomField() {
    setState(() {
      _customFields.add({
        'label': TextEditingController(),
        'value': TextEditingController(),
      });
    });
  }

  // Custom Field ပြန်ဖျက်ခြင်း
  void _removeCustomField(int index) {
    setState(() {
      _customFields[index]['label']?.dispose();
      _customFields[index]['value']?.dispose();
      _customFields.removeAt(index);
    });
  }

  // Create New Log Form (Blank & Custom Fields Allowed)
  void _showForm(int? id) async {
    _titleController.clear();
    _descController.clear();
    _customFields.clear();

    // Form စဖွင့်ချိန်တွင် Blank Custom Field (၁) ခု အလိုအလျောက် ထည့်သွင်းပေးထားခြင်း
    _addCustomField();

    showModalBottomSheet(
      context: context,
      elevation: 5,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(
              top: 15,
              left: 15,
              right: 15,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Log Form',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title (Optional)',
                      hintText: 'Leave blank for auto title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Description / Note (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Custom Fields',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),

                  // Dynamic Blank Custom Fields List Display
                  ..._customFields.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var controllers = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: controllers['label'],
                              decoration: const InputDecoration(
                                labelText: 'Field Name',
                                hintText: 'e.g. Phone, Price',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: controllers['value'],
                              decoration: const InputDecoration(
                                labelText: 'Value',
                                hintText: 'Enter details',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setModalState(() {
                                _removeCustomField(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // Add Custom Field Button
                  OutlinedButton.icon(
                    onPressed: () {
                      setModalState(() {
                        _addCustomField();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Blank Field'),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Log'),
                      onPressed: () async {
                        // Custom fields များကို Map အဖြစ် စုစည်းခြင်း
                        Map<String, String> extraData = {};
                        for (var field in _customFields) {
                          if (field['label']!.text.trim().isNotEmpty) {
                            extraData[field['label']!.text.trim()] =
                                field['value']!.text.trim();
                          }
                        }

                        // Title မဖြည့်ထားပါက Auto Title သတ်မှတ်ခြင်း
                        String finalTitle = _titleController.text.trim();
                        if (finalTitle.isEmpty) {
                          finalTitle =
                              'Log Record (${DateTime.now().toString().substring(0, 16)})';
                        }

                        // Description JSON Format ပြင်ဆင်ခြင်း
                        Map<String, dynamic> fullDesc = {
                          'note': _descController.text.trim(),
                          'custom_fields': extraData,
                        };

                        await DBHelper.insertLog({
                          'title': finalTitle,
                          'description': jsonEncode(fullDesc),
                          'date': DateTime.now().toString(),
                        });

                        _titleController.clear();
                        _descController.clear();
                        _customFields.clear();

                        if (mounted) Navigator.of(context).pop();
                        _refreshLogs();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Saved Log Display Parsing
  Widget _buildLogSubtitle(String rawDesc) {
    try {
      Map<String, dynamic> data = jsonDecode(rawDesc);
      String note = data['note'] ?? '';
      Map<String, dynamic> customFields = data['custom_fields'] ?? {};

      List<Widget> children = [];
      if (note.isNotEmpty) {
        children.add(Text(note));
      }
      customFields.forEach((key, value) {
        children.add(Text('$key: $value',
            style: const TextStyle(fontWeight: FontWeight.w500)));
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    } catch (e) {
      return Text(rawDesc);
    }
  }

  // Theme Settings Dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final currentMode = MyApp.of(context).currentTheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('System Default'),
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    onChanged: (val) {
                      if (val != null) {
                        MyApp.of(context).changeTheme(val);
                        Navigator.of(ctx).pop();
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Theme'),
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    onChanged: (val) {
                      if (val != null) {
                        MyApp.of(context).changeTheme(val);
                        Navigator.of(ctx).pop();
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Theme'),
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    onChanged: (val) {
                      if (val != null) {
                        MyApp.of(context).changeTheme(val);
                        Navigator.of(ctx).pop();
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Service Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Menu Options',
            onSelected: (String value) {
              if (value == 'add_log') {
                _showForm(null);
              } else if (value == 'settings') {
                _showSettingsDialog();
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
                    Text('Create New Log Form'),
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
                  subtitle: _buildLogSubtitle(_logs[index]['description'] ?? ''),
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
