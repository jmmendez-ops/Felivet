import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feline_detector/models/triage_models.dart';
import 'package:feline_detector/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pathProviderChannel = const MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('felivet_pdf_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDirectory.path;
          }
          return null;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('generates a non-empty PDF report without layout exceptions', () async {
    final result = TriageResult(
      presenceStatus: DiseasePresenceStatus.detected,
      detectedDisease: 'Dermatitis',
      evidenceStrength: EvidenceStrength.strong,
      urgency: UrgencyLevel.moderate,
      confidence: 0.87,
      confidenceLevel: ConfidenceLevel.high,
      diseaseRisk: DiseaseRiskLevel.moderate,
      detectionCount: 3,
      symptomCount: 3,
      isAmbiguous: false,
      reasoning:
          'The scan shows visible irritation consistent with dermatitis.',
      recommendation:
          'Monitor the area and consult a veterinarian if symptoms persist.',
      timestamp: DateTime(2026, 10, 8, 11, 6),
      image: null,
      selectedSymptoms: ['vomiting', 'lethargy', 'loss_of_appetite'],
    );

    File? file;
    try {
      file = await PdfReportService.generateScanReport(result);
      final bytes = await file.readAsBytes();

      expect(bytes, isNotEmpty);
    } finally {
      if (file != null && await file.exists()) {
        await file.delete();
      }
    }
  });
}
