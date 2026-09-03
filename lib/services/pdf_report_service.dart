import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../models/triage_models.dart';

class PdfReportService {
  static const _reportVersion = 'v2';
  static const _purple = PdfColor.fromInt(0xFF512DA8);
  static const _darkText = PdfColor.fromInt(0xFF202124);
  static const _mutedText = PdfColor.fromInt(0xFF667085);
  static const _lightSurface = PdfColor.fromInt(0xFFF7F5FB);
  static const _border = PdfColor.fromInt(0xFFE4E0EC);

  static Future<File> reportFileFor(TriageResult result) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = result.timestamp.toLocal();
    final condition = (result.detectedDisease ?? 'analysis')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final filePath =
        '${directory.path}/felivet_scan_report_${condition}_${stamp.year.toString().padLeft(4, '0')}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}_$_reportVersion.pdf';
    return File(filePath);
  }

  static Future<File> generateScanReport(TriageResult result) async {
    final file = await reportFileFor(result);
    final pdf = pw.Document();
    final scanTime = result.timestamp.toLocal();
    final date = _date(scanTime);
    final time = _time(scanTime);
    final condition = result.detectedDisease ?? 'No disease detected';
    final confidence = result.confidence == null
        ? 'N/A'
        : '${(result.confidence! * 100).toStringAsFixed(0)}%';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 40),
        header: (_) => _header(date, time),
        footer: (context) => _footer(context),
        build: (context) => [
          _sectionTitle('Pet Information'),
          _card(
            child: pw.Row(
              children: [
                pw.Expanded(child: _field('Pet Name', 'My Cat')),
                pw.Expanded(child: _field('Scan Date', date)),
                pw.Expanded(child: _field('Scan Time', time)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Scan Summary'),
          _card(
            background: _lightSurface,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: _summaryValue(
                    'Overall Urgency',
                    result.urgency.label,
                    valueColor: _urgencyColor(result.urgency),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: _summaryValue('Detected Condition', condition),
                ),
                pw.Expanded(
                  flex: 1,
                  child: _summaryValue('Confidence', confidence),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Detected Skin Condition'),
          _card(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(condition, style: _body(fontSize: 12, bold: true)),
                if (result.detectedDisease != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Detection confidence: $confidence  |  Evidence: ${result.evidenceStrength.label}  |  Areas detected: ${result.detectionCount}',
                    style: _body(fontSize: 9, color: _mutedText),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Reported Symptoms'),
          if (result.selectedSymptoms.isEmpty)
            _card(child: pw.Text('No symptoms selected', style: _body()))
          else
            ...result.selectedSymptoms.map(
              (symptom) => _symptomCard(
                _symptomTitle(symptom),
                _symptomDescription(symptom),
              ),
            ),
          pw.SizedBox(height: 18),
          _sectionTitle('Recommendation'),
          _card(
            background: _lightSurface,
            borderColor: _purple,
            child: pw.Text(result.recommendation, style: _body(fontSize: 12)),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Analysis'),
          _card(child: pw.Text(result.reasoning, style: _body(fontSize: 12))),
          pw.SizedBox(height: 22),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'FeliVet Insight is intended as a screening and informational tool and does not replace professional veterinary diagnosis or treatment. Consult a licensed veterinarian for medical concerns.',
              style: _body(fontSize: 8.5, color: _mutedText),
            ),
          ),
        ],
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _header(String date, String time) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                'FeliVet Insight',
                style: pw.TextStyle(
                  color: _purple,
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'Pet Health Scan Report',
              style: _body(fontSize: 10, color: _mutedText),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Scanned $date at $time',
          style: _body(fontSize: 9, color: _mutedText),
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 1.2, color: _purple),
        pw.SizedBox(height: 18),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      children: [
        pw.Container(height: 0.8, color: _border),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'FeliVet Insight  |  Pet Health Screening Report',
                style: _body(fontSize: 8, color: _mutedText),
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: _body(fontSize: 8, color: _mutedText),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: _purple,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _card({
    required pw.Widget child,
    PdfColor background = PdfColors.white,
    PdfColor borderColor = _border,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border.all(color: borderColor, width: 0.8),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: child,
    );
  }

  static pw.Widget _field(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: _body(fontSize: 8, color: _mutedText)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: _body(fontSize: 10, bold: true)),
      ],
    );
  }

  static pw.Widget _summaryValue(
    String label,
    String value, {
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(right: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: _body(fontSize: 8, color: _mutedText)),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: _body(
              fontSize: 11,
              bold: true,
              color: valueColor ?? _darkText,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _symptomCard(String title, String description) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _lightSurface,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _body(fontSize: 10, bold: true)),
          pw.SizedBox(height: 3),
          pw.Text(description, style: _body(fontSize: 8.5, color: _mutedText)),
        ],
      ),
    );
  }

  static pw.TextStyle _body({
    double fontSize = 10,
    PdfColor color = _darkText,
    bool bold = false,
  }) {
    return pw.TextStyle(
      fontSize: fontSize,
      color: color,
      lineSpacing: 2,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
  }

  static PdfColor _urgencyColor(UrgencyLevel urgency) {
    switch (urgency) {
      case UrgencyLevel.high:
        return const PdfColor.fromInt(0xFFC62828);
      case UrgencyLevel.moderate:
        return const PdfColor.fromInt(0xFFB26A00);
      case UrgencyLevel.stable:
        return const PdfColor.fromInt(0xFF2E7D32);
    }
  }

  static String _symptomTitle(String symptom) {
    return symptom
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String _symptomDescription(String symptom) {
    switch (symptom) {
      case 'vomiting':
        return 'Frequent throwing up or dry heaving.';
      case 'lethargy':
        return 'Unusually tired, sleepy, or unresponsive.';
      case 'loss_of_appetite':
        return 'Ignoring food or eating very little.';
      default:
        return 'Reported symptom from the scan intake.';
    }
  }

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
