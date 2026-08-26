import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'db_helper.dart';
import 'main.dart';

class CustomFieldConfig {
  String name;
  String type; // Short Text, Long Text, Number, Long Number, Date, Photo, Attachment
  bool isRequired;

  CustomFieldConfig({
    required this.name,
    this.type = 'Short Text',
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
        type: json['type'] ?? 'Short Text',
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
  final List<Map<String, dynamic>> _savedForms = [];

  final List<String> _dataTypes = [
    'Short Text',
    'Long Text',
    'Number',
    'Long Number',
    'Date',
    'Photo',
    'Attachment',
  ];

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

  // Permission တောင်းဆိုရန်
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted || await Permission.manageExternalStorage.request().isGranted;
    }
    return true;
  }

  // Export to Excel Function
  Future<void> _exportToExcel() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No log data to export.')),
      );
      return;
    }

    await _requestPermission();

    var excel = excel_lib.Excel.createExcel();
    excel_lib.Sheet sheetObject = excel['Daily Service Logs'];
    excel.delete('Sheet1');

    // Header
    sheetObject.appendRow([
      excel_lib.TextCellValue('ID'),
      excel_lib.TextCellValue('Title'),
      excel_lib.TextCellValue('Details'),
      excel_lib.TextCellValue('Date')
    ]);

    // Data Rows
    for (var log in _logs) {
      sheetObject.appendRow([
        excel_lib.TextCellValue(log['id'].toString()),
        excel_lib.TextCellValue(log['title']?.toString() ?? ''),
        excel_lib.TextCellValue(log['description']?.toString() ?? ''),
        excel_lib.TextCellValue(log['date']?.toString() ?? ''),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      Directory? directory = await getExternalStorageDirectory();
      String path = directory?.path ?? (await getApplicationDocumentsDirectory()).path;
      String filePath = "$path/Daily_Service_Logs_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to Excel: $filePath')),
        );
      }
    }
  }

  // Export & Print PDF Function
  Future<void> _exportToPDF() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No log data to export.')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, // cross နေရာတွင် crossAxisAlignment ဟု ပြောင်းပါ
            children: [
              pw.Text('Daily Service Logs Report',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['ID', 'Title', 'Date'],
                data: _logs
                    .map((log) => [
                          log['id'].toString(),
                          log['title']?.toString() ?? '',
                          log['date']?.toString().substring(0, 10) ?? ''
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  
  // Database Tools Dialog (Clear / Reset Data)
  void _showDatabaseToolsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Database Tools'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Refresh Data'),
              subtitle: const Text('Reload logs from database'),
              onTap: () {
                Navigator.pop(ctx);
                _refreshLogs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Logs'),
              subtitle: const Text('Permanently delete all logs'),
              onTap: () async {
                Navigator.pop(ctx);
                for (var log in _logs) {
                  await DBHelper.deleteLog(log['id']);
                }
                _refreshLogs();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All logs cleared.')),
                  );
                }
              },
            ),
          ],
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

  // Form Builder
  void _showAccessFormBuilder({Map<String, dynamic>? existingForm, int? editIndex}) {
    TextEditingController formNameController = TextEditingController(
        text: existingForm != null ? existingForm['title'] : 'New Form Template');

    List<CustomFieldConfig> formFields = [];
    if (existingForm != null && existingForm['fields'] != null) {
      List<dynamic> rawFields = existingForm['fields'];
      formFields = rawFields
          .map((f) => CustomFieldConfig.fromJson(Map<String, dynamic>.from(f)))
          .toList();
    } else {
      formFields = [
        CustomFieldConfig(name: 'Title', type: 'Short Text', isRequired: true),
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 5,
      builder: (builderContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.design_services, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            existingForm != null ? 'Edit Form' : 'Create New Form',
                            style: const TextStyle(
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
                      const Text(
                        'Design Form Fields:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: formFields.length,
                          itemBuilder: (context, idx) {
                            var field = formFields[idx];
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
                                      value: _dataTypes.contains(field.type)
                                          ? field.type
                                          : 'Short Text',
                                      items: _dataTypes
                                          .map((t) => DropdownMenuItem(
                                                value: t,
                                                child: Text(t),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setModalState(() {
                                          field.type = val ?? 'Short Text';
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
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            formFields.add(CustomFieldConfig(
                                name: 'Field ${formFields.length + 1}',
                                type: 'Short Text'));
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Field Schema'),
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
                          label: Text(existingForm != null
                              ? 'Update Form Template'
                              : 'Save Form Template'),
                          onPressed: () {
                            setState(() {
                              Map<String, dynamic> updatedFormData = {
                                'id': existingForm != null
                                    ? existingForm['id']
                                    : DateTime.now().millisecondsSinceEpoch,
                                'title': formNameController.text,
                                'fields':
                                    formFields.map((f) => f.toJson()).toList(),
                              };

                              if (editIndex != null && editIndex >= 0) {
                                _savedForms[editIndex] = updatedFormData;
                              } else {
                                _savedForms.add(updatedFormData);
                              }
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Form "${formNameController.text}" Saved!'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Saved Form Entry Dialog
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
      useSafeArea: true,
      builder: (dialogCtx) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(formTemplate['title'] ?? 'Form Entry'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: schema.length,
                        itemBuilder: (context, index) {
                          var field = schema[index];

                          if (field.type == 'Photo') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () {
                                  controllers[field.name]!.text = '[Photo Attached]';
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: Text('Attach ${field.name} (Photo)'),
                              ),
                            );
                          }

                          if (field.type == 'Attachment') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () {
                                  controllers[field.name]!.text = '[File Attached]';
                                },
                                icon: const Icon(Icons.attach_file),
                                label: Text('Upload ${field.name} (File)'),
                              ),
                            );
                          }

                          bool isLongText = field.type == 'Long Text';
                          bool isNumber = field.type == 'Number' || field.type == 'Long Number';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: controllers[field.name],
                              maxLines: isLongText ? 10 : 1, // Long Text ကို maxLines: 10 သို့ ပြောင်းထားသည်
                              keyboardType: isNumber
                                  ? TextInputType.number
                                  : TextInputType.multiline,
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
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSelectOrEditFormDialog({bool isEditMode = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isEditMode ? Icons.edit_document : Icons.folder_special,
                color: Colors.blue),
            const SizedBox(width: 8),
            Text(isEditMode ? 'Select Form to Edit' : 'Saved Form Templates'),
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
                      trailing: isEditMode
                          ? IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAccessFormBuilder(
                                  existingForm: item,
                                  editIndex: index,
                                );
                              },
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _savedForms.removeAt(index);
                                    });
                                    Navigator.pop(ctx);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios,
                                      size: 16),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openFilledFormDialog(item);
                                  },
                                ),
                              ],
                            ),
                      onTap: isEditMode
                          ? () {
                              Navigator.pop(ctx);
                              _showAccessFormBuilder(
                                existingForm: item,
                                editIndex: index,
                              );
                            }
                          : null,
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
              } else if (value == 'edit_form') {
                _showSelectOrEditFormDialog(isEditMode: true);
              } else if (value == 'saved_forms') {
                _showSelectOrEditFormDialog(isEditMode: false);
              } else if (value == 'export_excel') {
                _exportToExcel();
              } else if (value == 'export_pdf') {
                _exportToPDF();
              } else if (value == 'db_tools') {
                _showDatabaseToolsDialog();
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
                value: 'edit_form',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Edit Form'),
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
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'export_excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export to Excel'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export / Print PDF'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'db_tools',
                child: Row(
                  children: [
                    Icon(Icons.storage, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Database Tools'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_savedForms.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
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
                            width: 130,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccessFormBuilder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
