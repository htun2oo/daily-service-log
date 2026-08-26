import 'dart:convert';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'main.dart';

class CustomFieldConfig {
  String name;
  String type; // Text, Number, Date, Selection
  bool isRequired;
  List<String> options;

  CustomFieldConfig({
    required this.name,
    this.type = 'Text',
    this.isRequired = false,
    List<String>? options,
  }) : options = options ?? [];
}

class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  List<Map<String, dynamic>> _logs = [];

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

  // MS Access Style Form Builder & Dynamic Data Entry Screen
  void _showAccessFormBuilder() {
    List<CustomFieldConfig> formFields = [
      CustomFieldConfig(name: 'Title / Subject', type: 'Text', isRequired: true),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 5,
      builder: (builderContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_chart_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'MS Access Style - Create Form',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. Design Form Fields (Data Schema):',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 10),

                          // Field Builder List
                          ...formFields.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var field = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            decoration: const InputDecoration(
                                              labelText: 'Field Name',
                                              isDense: true,
                                            ),
                                            controller: TextEditingController(
                                                text: field.name)
                                              ..selection = TextSelection
                                                  .fromPosition(TextPosition(
                                                      offset:
                                                          field.name.length)),
                                            onChanged: (val) =>
                                                field.name = val,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        DropdownButton<String>(
                                          value: field.type,
                                          items: ['Text', 'Number', 'Date']
                                              .map((t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(t),
                                                  ))
                                              .toList(),
                                          onChanged: (val) {
                                            setModalState(() {
                                              field.type = val ?? 'Text';
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            field.isRequired
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: field.isRequired
                                                ? Colors.orange
                                                : Colors.grey,
                                          ),
                                          tooltip: 'Toggle Required Field',
                                          onPressed: () {
                                            setModalState(() {
                                              field.isRequired =
                                                  !field.isRequired;
                                            });
                                          },
                                        ),
                                        if (formFields.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () {
                                              setModalState(() {
                                                formFields.removeAt(idx);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),

                          OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                formFields.add(CustomFieldConfig(
                                    name: 'Field ${formFields.length + 1}',
                                    type: 'Text'));
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Field Schema'),
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            '2. Open Generated Form to Input Data:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.article),
                              label: const Text('Open & Fill Form'),
                              onPressed: () {
                                Navigator.pop(context);
                                _openFilledFormDialog(formFields);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Generated Form view (Data Input)
  void _openFilledFormDialog(List<CustomFieldConfig> schema) {
    Map<String, TextEditingController> controllers = {
      for (var s in schema) s.name: TextEditingController()
    };

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment, color: Colors.blue),
              SizedBox(width: 8),
              Text('Access Entry Form'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: schema.map((field) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[field.name],
                    keyboardType: field.type == 'Number'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText:
                          '${field.name}${field.isRequired ? " *" : ""}',
                      border: const OutlineInputBorder(),
                      suffixIcon: field.type == 'Date'
                          ? IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                DateTime? picked = await showDatePicker(
                                  context: dialogCtx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  controllers[field.name]!.text =
                                      picked.toString().split(' ')[0];
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String mainTitle = controllers.values.first.text;
                if (mainTitle.isEmpty) {
                  mainTitle = 'Access Record (${DateTime.now().toString().substring(0, 10)})';
                }

                Map<String, String> dataResult = {};
                controllers.forEach((key, ctrl) {
                  dataResult[key] = ctrl.text;
                });

                Map<String, dynamic> fullData = {
                  'type': 'Access_Form',
                  'custom_fields': dataResult,
                };

                await DBHelper.insertLog({
                  'title': mainTitle,
                  'description': jsonEncode(fullData),
                  'date': DateTime.now().toString(),
                });

                if (mounted) Navigator.pop(dialogCtx);
                _refreshLogs();
              },
              child: const Text('Submit Record'),
            ),
          ],
        );
      },
    );
  }

  // Display Subtitle Parsing
  Widget _buildLogSubtitle(String rawDesc) {
    try {
      Map<String, dynamic> data = jsonDecode(rawDesc);
      Map<String, dynamic> customFields = data['custom_fields'] ?? {};

      List<Widget> children = [];
      customFields.forEach((key, value) {
        if (value.toString().isNotEmpty) {
          children.add(Text('$key: $value',
              style: const TextStyle(fontWeight: FontWeight.w500)));
        }
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.isEmpty ? [Text(rawDesc)] : children,
      );
    } catch (e) {
      return Text(rawDesc);
    }
  }

  // Settings Dialog
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
              if (value == 'create_form') {
                _showAccessFormBuilder();
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
                value: 'create_form',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Create Form (Access Style)'),
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
                  subtitle:
                      _buildLogSubtitle(_logs[index]['description'] ?? ''),
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
        onPressed: () => _showAccessFormBuilder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
