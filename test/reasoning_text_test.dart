import 'package:flutter_test/flutter_test.dart';
import 'package:feline_detector/models/triage_models.dart';
import 'package:feline_detector/screens/result_screen.dart';

void main() {
  test('formats real reasoning text for every urgency and symptom count', () {
    for (final evidenceStrength in EvidenceStrength.values) {
      expect(evidenceStrength.label.toLowerCase(), contains('evidence'));
    }
    for (final diseaseRisk in DiseaseRiskLevel.values) {
      expect(diseaseRisk.label, isNotEmpty);
    }

    for (final urgency in UrgencyLevel.values) {
      for (final symptomCount in [0, 1, 2]) {
        final result = TriageResult(
          presenceStatus: DiseasePresenceStatus.detected,
          detectedDisease: 'Ringworm',
          evidenceStrength: EvidenceStrength.moderate,
          urgency: urgency,
          confidence: 0.72,
          confidenceLevel: ConfidenceLevel.moderate,
          diseaseRisk: urgency == UrgencyLevel.stable
              ? null
              : DiseaseRiskLevel.values[urgency.index],
          detectionCount: 1,
          symptomCount: symptomCount,
          isAmbiguous: false,
          reasoning: 'Test reasoning',
          recommendation: 'Test recommendation',
          timestamp: DateTime(2026, 1, 1),
          image: null,
        );
        final text = reasoningSupportText(result);

        expect(text, endsWith('.'));
        expect(text, isNot(contains('evidence evidence')));
        expect(text, isNot(contains('risk risk')));
        expect(text, isNot(contains('visual evidence visual evidence')));
        expect(text, isNot(contains('clinical risk clinical risk')));
        if (symptomCount == 1) {
          expect(text, contains('1 symptom was reported'));
          expect(text, isNot(contains('1 symptom were reported')));
        } else {
          expect(text, contains('$symptomCount symptoms were reported'));
          expect(text, isNot(contains('$symptomCount symptoms was reported')));
        }
      }
    }
  });

  test('formats missing confidence naturally', () {
    final result = TriageResult(
      presenceStatus: DiseasePresenceStatus.detected,
      detectedDisease: 'Ringworm',
      evidenceStrength: EvidenceStrength.moderate,
      urgency: UrgencyLevel.moderate,
      confidence: null,
      confidenceLevel: null,
      diseaseRisk: DiseaseRiskLevel.moderate,
      detectionCount: 1,
      symptomCount: 0,
      isAmbiguous: false,
      reasoning: 'Test reasoning',
      recommendation: 'Test recommendation',
      timestamp: DateTime(2026, 1, 1),
      image: null,
    );

    final text = reasoningSupportText(result);

    expect(
      text,
      contains('with moderate visual evidence (confidence unavailable)'),
    );
    expect(text, endsWith('.'));
  });
}
