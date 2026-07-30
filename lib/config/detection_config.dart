import '../models/triage_models.dart';

class DetectionConfig {
  static const double minDetectionConfidence = 0.40;
  static const double iouThreshold = 0.45;

  static const double strongEvidenceConfidence = 0.70;
  static const double moderateEvidenceConfidence = 0.55;
  static const int strongEvidenceMinDetections = 3;
  static const int moderateEvidenceMinDetections = 2;

  static const double ambiguityMargin = 0.08;

  static const List<String> knownDiseases = [
    'Scabies',
    'ringworms',
    'Flee Allergy',
  ];

  static const Map<String, DiseaseRiskLevel> diseaseRisk = {
    'Scabies': DiseaseRiskLevel.high,
    'ringworms': DiseaseRiskLevel.high,
    'Flee Allergy': DiseaseRiskLevel.moderate,
  };
}
