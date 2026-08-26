import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_helper.dart';
import 'main.dart';

class CustomFieldConfig {
  String name;
  String type;
  bool isRequired;

  CustomFieldConfig({
    required this.name,
    this.type = 'Text',
    this.isRequired = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'isRequired': isRequired,
      };

  factory CustomFieldConfig.fromJson(Map<String, dynamic> json) =>
      CustomFieldConfig(
        name: json['name'] ?? '',
        type: json['type'] ?? 'Text',
        isRequired: json['isRequired'] ?? false,
      );
}

class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _savedForms = [];

  @override
  void initState() {
    super.initState();
    _refreshLogs();
    _loadSavedForms();
  }

  void _refreshLogs() async {
    final data = await DBHelper.getLogs();
    setState(() {
      _logs = data;
    });
  }

  // Saved Forms များကို SharedPreferences မှ ပြန်လည်ဖတ်ယူခြင်း
  void _loadSavedForms() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedFormsString = prefs.getString('saved_forms_templates');
    if (savedFormsString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedFormsString);
        setState(() {
          _savedForms = decoded.cast<Map<String, dynamic>>();
        });
      } catch (e) {
        debugPrint('Error loading saved forms: $e');
      }
    }
  }

  // Saved Forms များကို SharedPreferences သို့ သိမ်းဆည်းခြင်း
  Future<void> _saveFormsToStorage(List<Map<String, dynamic>> forms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_forms_templates', jsonEncode(forms));
  }

  // Access Style Create New Form Builder
  void _showAccessFormBuilder() {
    TextEditingController formNameController =
        TextEditingController(text: 'New Form Template');
    List<CustomFieldConfig> formFields = [
      CustomFieldConfig(name: 'Title', type: 'Text', isRequired: true),
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
                      const Icon(Icons.design_services, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Create New Form (Access Style)',
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
                  TextField(
                    controller: formNameController,
                    decoration: const InputDecoration(
                      labelText: 'Form Title / Template Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Design Form Fields:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 10),
                          ...formFields.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var field = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
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
                                                  offset: field.name.length)),
                                        onChanged: (val) => field.name = val,
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
                                      onPressed: () {
                                        setModalState(() {
                                          field.isRequired = !field.isRequired;
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Form Template to Desktop'),
                      onPressed: () async {
                        final updatedList = List<Map<String, dynamic>>.from(_savedForms);
                        updatedList.add({
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'title': formNameController.text,
                          'fields': formFields
                              .map((f) => f.toJson())
                              .toList(),
                        });

                        await _saveFormsToStorage(updatedList);

                        setState(() {
                          _savedForms = updatedList;
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Form "${formNameController.text}" Saved to Desktop!'),
                            ),
                          );
                        }
                      },
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

  // Saved Form ဖြည့်စွက်ရန် Dialog
  void _openFilledFormDialog(Map<String, dynamic> formTemplate) {
    List<dynamic> rawFields = formTemplate['fields'] ?? [];
    List<CustomFieldConfig> schema = rawFields
        .map((f) => CustomFieldConfig.fromJson(Map<String, dynamic>.from(f)))
        .toList();

    Map<String, TextEditingController> controllers = {
      for (var s in schema) s.name: TextEditingController()
    };

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(formTemplate['title'] ?? 'Access Form Entry'),
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
                  mainTitle =
                      '${formTemplate['title']} Entry (${DateTime.now().toString().substring(0, 10)})';
                }

                Map<String, String> dataResult = {};
                controllers.forEach((key, ctrl) {
                  dataResult[key] = ctrl.text;
                });

                Map<String, dynamic> fullData = {
                  'type': formTemplate['title'],
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

  // Saved Forms List Modal
  void _showSavedFormsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Colors.blue),
            SizedBox(width: 8),
            Text('Saved Form Templates'),
          ],
        ),
        content: _savedForms.isEmpty
            ? const Text('No Saved Forms found.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _savedForms.length,
                  itemBuilder: (context, index) {
                    var item = _savedForms[index];
                    return ListTile(
                      leading: const Icon(Icons.article, color: Colors.blue),
                      title: Text(item['title'] ?? 'Form'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final updatedList = List<Map<String, dynamic>>.from(_savedForms);
                              updatedList.removeAt(index);
                              await _saveFormsToStorage(updatedList);
                              setState(() {
                                _savedForms = updatedList;
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openFilledFormDialog(item);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
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
              if (value == 'create_new_form') {
                _showAccessFormBuilder();
              } else if (value == 'saved_forms') {
                _showSavedFormsDialog();
              } else if (value == 'settings') {
                _showSettingsDialog();
              } else if (value == 'all') {
                _refreshLogs();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'create_new_form',
                child: Row(
                  children: [
                    Icon(Icons.design_services, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Create New Form'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'saved_forms',
                child: Row(
                  children: [
                    Icon(Icons.folder_special, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Saved Forms'),
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
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Desktop View: Saved Form Templates Cards
            if (_savedForms.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 12, top: 12, bottom: 4),
                child: Text('Desktop - Form Shortcuts',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey)),
              ),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _savedForms.length,
                  itemBuilder: (context, index) {
                    var item = _savedForms[index];
                    return Card(
                      color: Colors.blue.shade50,
                      child: InkWell(
                        onTap: () => _openFilledFormDialog(item),
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment,
                                  color: Colors.blueAccent),
                              const SizedBox(height: 4),
                              Text(
                                item['title'] ?? 'Form',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
            ],

            // Main Service Logs List
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
              child: Text('Service Logs',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
            ),
            _logs.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(30.0),
                    child: Text('No Logs Found'),
                  ))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(_logs[index]['title'] ?? ''),
                        subtitle: _buildLogSubtitle(
                            _logs[index]['description'] ?? ''),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccessFormBuilder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
