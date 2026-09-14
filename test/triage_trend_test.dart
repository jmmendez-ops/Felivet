import 'package:feline_detector/models/triage_models.dart';
import 'package:feline_detector/screens/triage_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTrendSpots', () {
    test('returns ordered spots for recent scans', () {
      final older = TriageResult(
        presenceStatus: DiseasePresenceStatus.detected,
        detectedDisease: 'Scabies',
        evidenceStrength: EvidenceStrength.strong,
        urgency: UrgencyLevel.moderate,
        confidence: 0.4,
        confidenceLevel: ConfidenceLevel.low,
        diseaseRisk: DiseaseRiskLevel.moderate,
        detectionCount: 1,
        symptomCount: 1,
        isAmbiguous: false,
        reasoning: 'Older scan',
        recommendation: 'Monitor',
        timestamp: DateTime(2024, 1, 1),
        image: null,
      );

      final newer = TriageResult(
        presenceStatus: DiseasePresenceStatus.detected,
        detectedDisease: 'Scabies',
        evidenceStrength: EvidenceStrength.strong,
        urgency: UrgencyLevel.high,
        confidence: 0.8,
        confidenceLevel: ConfidenceLevel.high,
        diseaseRisk: DiseaseRiskLevel.high,
        detectionCount: 2,
        symptomCount: 2,
        isAmbiguous: false,
        reasoning: 'Newer scan',
        recommendation: 'See a vet',
        timestamp: DateTime(2024, 1, 2),
        image: null,
      );

      final spots = buildTrendSpots([newer, older]);

      expect(spots.length, 2);
      expect(spots.first.x, 0);
      expect(spots.first.y, 2.0);
      expect(spots.last.y, 3.0);
    });

    test('keeps every point while limiting crowded date labels', () {
      expect(
        [
          shouldShowTrendDateLabel(0, 6),
          shouldShowTrendDateLabel(1, 6),
          shouldShowTrendDateLabel(2, 6),
          shouldShowTrendDateLabel(3, 6),
          shouldShowTrendDateLabel(4, 6),
          shouldShowTrendDateLabel(5, 6),
        ],
        [true, false, true, false, true, true],
      );
      expect(shouldShowTrendDateLabel(0, 1), isTrue);
      expect(shouldShowTrendDateLabel(1, 1), isFalse);
    });

    test('returns an empty list for too few scans', () {
      final single = TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.stable,
        confidence: 0.2,
        confidenceLevel: ConfidenceLevel.low,
        diseaseRisk: DiseaseRiskLevel.low,
        detectionCount: 0,
        symptomCount: 0,
        isAmbiguous: false,
        reasoning: 'Single scan',
        recommendation: 'Keep monitoring',
        timestamp: DateTime(2024, 1, 1),
        image: null,
      );

      expect(buildTrendSpots([single]), isEmpty);
    });
  });
}
