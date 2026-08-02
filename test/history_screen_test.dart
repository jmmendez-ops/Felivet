import 'package:feline_detector/models/triage_models.dart';
import 'package:feline_detector/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates history entries when new history is provided', (
    tester,
  ) async {
    final initialResult = TriageResult(
      presenceStatus: DiseasePresenceStatus.notDetected,
      detectedDisease: null,
      evidenceStrength: EvidenceStrength.insufficient,
      urgency: UrgencyLevel.stable,
      confidence: 0.1,
      confidenceLevel: ConfidenceLevel.low,
      diseaseRisk: DiseaseRiskLevel.low,
      detectionCount: 0,
      symptomCount: 0,
      isAmbiguous: false,
      reasoning: 'Initial analysis',
      recommendation: 'Watch carefully',
      timestamp: DateTime(2024, 1, 1, 10, 0),
      image: null,
    );

    final updatedResult = TriageResult(
      presenceStatus: DiseasePresenceStatus.detected,
      detectedDisease: 'Skin Infection',
      evidenceStrength: EvidenceStrength.strong,
      urgency: UrgencyLevel.moderate,
      confidence: 0.85,
      confidenceLevel: ConfidenceLevel.high,
      diseaseRisk: DiseaseRiskLevel.high,
      detectionCount: 1,
      symptomCount: 2,
      isAmbiguous: false,
      reasoning: 'Updated analysis',
      recommendation: 'See a vet',
      timestamp: DateTime(2024, 1, 2, 11, 0),
      image: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          history: const [],
          onDelete: (_) async {},
          onClearAll: () async {},
        ),
      ),
    );

    expect(find.text('No saved analyses yet'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          history: [initialResult],
          onDelete: (_) async {},
          onClearAll: () async {},
        ),
      ),
    );

    expect(find.text('No saved analyses yet'), findsNothing);
    expect(find.text('No disease detected'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          history: [updatedResult],
          onDelete: (_) async {},
          onClearAll: () async {},
        ),
      ),
    );

    expect(find.text('Skin Infection'), findsOneWidget);
    expect(find.text('No disease detected'), findsNothing);
  });
}
