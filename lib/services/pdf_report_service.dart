import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/triage_models.dart';

class PdfReportService {
  static Future<File> generateScanReport(TriageResult result) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FeliVet Insight Scan Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Date: ${result.timestamp.toLocal().toString()}'),
            pw.SizedBox(height: 8),
            pw.Text('Urgency: ${result.urgency.label}'),
            pw.SizedBox(height: 8),
            pw.Text(
              'Detected disease: ${result.detectedDisease ?? 'No disease detected'}',
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Confidence: ${result.confidence != null ? '${(result.confidence! * 100).toStringAsFixed(0)}%' : 'N/A'}',
            ),
            pw.SizedBox(height: 12),
            pw.Text('Selected symptoms:'),
            pw.SizedBox(height: 4),
            pw.Bullet(
              text: result.selectedSymptoms.isEmpty
                  ? 'No symptoms selected'
                  : result.selectedSymptoms.join(', '),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Recommendation:'),
            pw.SizedBox(height: 4),
            pw.Text(result.recommendation),
            pw.SizedBox(height: 12),
            pw.Text('Reasoning:'),
            pw.SizedBox(height: 4),
            pw.Text(result.reasoning),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final stamp = result.timestamp.toLocal();
    final condition = (result.detectedDisease ?? 'analysis')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final filePath =
        '${directory.path}/felivet_scan_report_${condition}_${stamp.year.toString().padLeft(4, '0')}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
