import 'package:flutter_test/flutter_test.dart';
import 'package:feline_detector/models/triage_models.dart';
import 'package:feline_detector/services/triage_engine.dart';

void main() {
  group('TriageResult comparison', () {
    test('returns a daily care tip for the dashboard', () {
      final tip = buildDailyCareTip(
        scanCount: 1,
        latestUrgency: UrgencyLevel.moderate,
        date: DateTime(2024, 1, 2),
      );

      expect(tip, isNotEmpty);
      expect(tip.toLowerCase(), contains('care'));
    });

    test('reports improved when urgency becomes less severe', () {
      final previous = TriageResult(
        presenceStatus: DiseasePresenceStatus.detected,
        detectedDisease: 'Scabies',
        evidenceStrength: EvidenceStrength.strong,
        urgency: UrgencyLevel.high,
        confidence: 0.82,
        confidenceLevel: ConfidenceLevel.high,
        diseaseRisk: DiseaseRiskLevel.high,
        detectionCount: 4,
        symptomCount: 2,
        isAmbiguous: false,
        reasoning: 'Earlier result',
        recommendation: 'Seek care',
        timestamp: DateTime(2024, 1, 1),
        image: null,
      );

      final current = TriageResult(
        presenceStatus: DiseasePresenceStatus.detected,
        detectedDisease: 'Scabies',
        evidenceStrength: EvidenceStrength.moderate,
        urgency: UrgencyLevel.stable,
        confidence: 0.61,
        confidenceLevel: ConfidenceLevel.moderate,
        diseaseRisk: DiseaseRiskLevel.high,
        detectionCount: 2,
        symptomCount: 1,
        isAmbiguous: false,
        reasoning: 'Updated result',
        recommendation: 'Monitor',
        timestamp: DateTime(2024, 1, 2),
        image: null,
      );

      expect(current.compareToPrevious(previous), ScanComparisonTrend.improved);
    });
  });
}
