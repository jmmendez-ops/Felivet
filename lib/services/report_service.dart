import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/triage_models.dart';
import 'pdf_report_service.dart';

class ReportFile {
  final String path;
  final String displayName;
  final DateTime date;
  final UrgencyLevel urgency;
  final String? diseaseName;
  final String? catId;

  const ReportFile({
    required this.path,
    required this.displayName,
    required this.date,
    required this.urgency,
    this.diseaseName,
    this.catId,
  });

  File get file => File(path);

  Map<String, dynamic> toJson() => {
        'path': path,
        'displayName': displayName,
        'date': date.toIso8601String(),
        'urgency': urgency.name,
        'diseaseName': diseaseName,
        'catId': catId,
      };

  factory ReportFile.fromJson(Map<String, dynamic> json) => ReportFile(
        path: json['path'] as String,
        displayName: json['displayName'] as String,
        date: DateTime.parse(json['date'] as String),
        urgency: UrgencyLevel.values.byName(json['urgency'] as String),
        diseaseName: json['diseaseName'] as String?,
        catId: json['catId'] as String?,
      );
}

class ReportService {
  static const _indexKey = 'felivet_report_index_v1';

  static Future<Directory> _reportsDirectory() async {
    final root = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    if (root == null) {
      throw StateError('A writable reports directory is unavailable.');
    }
    final directory = Directory('${root.path}${Platform.pathSeparator}Reports');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<ReportFile> exportReport(TriageResult result) async {
    final directory = await _reportsDirectory();
    final date = DateTime.now();
    final disease = _safePart(result.detectedDisease ?? 'Result');
    final stamp = _stamp(date);
    var file = File(
      '${directory.path}${Platform.pathSeparator}'
      'FeliVet_Report_${disease}_$stamp.pdf',
    );
    var suffix = 2;
    while (await file.exists()) {
      file = File(
        '${directory.path}${Platform.pathSeparator}'
        'FeliVet_Report_${disease}_${stamp}_$suffix.pdf',
      );
      suffix++;
    }

    await PdfReportService.generateScanReport(result, outputFile: file);
    final report = ReportFile(
      path: file.path,
      displayName: file.uri.pathSegments.last,
      date: date,
      urgency: result.urgency,
      diseaseName: result.detectedDisease,
      catId: result.catId,
    );
    final reports = await _readIndex();
    reports.removeWhere((entry) => entry.path == report.path);
    reports.add(report);
    await _writeIndex(reports);
    return report;
  }

  static Future<List<ReportFile>> listReports() async {
    final reports = await _readIndex();
    final existing = reports.where((report) => report.file.existsSync()).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (existing.length != reports.length) await _writeIndex(existing);
    return existing;
  }

  static Future<void> deleteReport(ReportFile report) async {
    if (await report.file.exists()) await report.file.delete();
    final reports = await _readIndex()
      ..removeWhere((entry) => entry.path == report.path);
    await _writeIndex(reports);
  }

  static Future<OpenResult> openReport(ReportFile report) {
    return OpenFilex.open(report.path, type: 'application/pdf');
  }

  static Future<void> shareReport(ReportFile report) async {
    await Share.shareXFiles(
      [XFile(report.path, mimeType: 'application/pdf')],
      subject: report.displayName,
    );
  }

  static Future<List<ReportFile>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_indexKey) ?? const [];
    final reports = <ReportFile>[];
    for (final value in raw) {
      try {
        reports.add(ReportFile.fromJson(jsonDecode(value) as Map<String, dynamic>));
      } catch (_) {
        // Invalid historical entries are discarded when the index is rewritten.
      }
    }
    return reports;
  }

  static Future<void> _writeIndex(List<ReportFile> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _indexKey,
      reports.map((report) => jsonEncode(report.toJson())).toList(),
    );
  }

  static String _safePart(String value) {
    final safe = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return safe.isEmpty ? 'Result' : safe;
  }

  static String _stamp(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}_'
      '${date.hour.toString().padLeft(2, '0')}'
      '${date.minute.toString().padLeft(2, '0')}'
      '${date.second.toString().padLeft(2, '0')}';
}
