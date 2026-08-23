import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfBytes,
    this.title = 'PDF Preview',
  }) : super(Key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blueGrey,
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'service_log_report.pdf',
      ),
    );
  }
}
