import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

enum DiseasePresenceStatus { detected, likelyDetected, uncertain, notDetected }

enum EvidenceStrength { strong, moderate, weak, insufficient }

enum UrgencyLevel { stable, moderate, high }

enum DiseaseRiskLevel { low, moderate, high }

enum ConfidenceLevel { low, moderate, high }

enum ScanComparisonTrend { improved, worsened, noChange }

extension DiseasePresenceStatusX on DiseasePresenceStatus {
  String get label => switch (this) {
    DiseasePresenceStatus.detected => 'Detected',
    DiseasePresenceStatus.likelyDetected => 'Likely Detected',
    DiseasePresenceStatus.uncertain => 'Uncertain',
    DiseasePresenceStatus.notDetected => 'Not Detected',
  };
}

extension EvidenceStrengthX on EvidenceStrength {
  String get label => switch (this) {
    EvidenceStrength.strong => 'Strong Visual Evidence',
    EvidenceStrength.moderate => 'Moderate Visual Evidence',
    EvidenceStrength.weak => 'Weak Visual Evidence',
    EvidenceStrength.insufficient => 'Insufficient Evidence',
  };
}

extension UrgencyLevelX on UrgencyLevel {
  String get label => switch (this) {
    UrgencyLevel.stable => 'STABLE',
    UrgencyLevel.moderate => 'MODERATE URGENCY',
    UrgencyLevel.high => 'HIGH URGENCY',
  };

  String get icon => switch (this) {
    UrgencyLevel.stable => '✅',
    UrgencyLevel.moderate => '⚠️',
    UrgencyLevel.high => '🚨',
  };

  Color get color => switch (this) {
    UrgencyLevel.stable => const Color(0xFF3FA85C),
    UrgencyLevel.moderate => const Color(0xFFF2A93B),
    UrgencyLevel.high => const Color(0xFFE0402C),
  };
}

extension ScanComparisonTrendX on ScanComparisonTrend {
  String get label => switch (this) {
    ScanComparisonTrend.improved => 'Improved',
    ScanComparisonTrend.worsened => 'Worsened',
    ScanComparisonTrend.noChange => 'No Change',
  };
}

extension DiseaseRiskLevelX on DiseaseRiskLevel {
  String get label => switch (this) {
    DiseaseRiskLevel.high => 'High Clinical Risk',
    DiseaseRiskLevel.moderate => 'Moderate Clinical Risk',
    DiseaseRiskLevel.low => 'Low Clinical Risk',
  };
}

extension ConfidenceLevelX on ConfidenceLevel {
  String get label => switch (this) {
    ConfidenceLevel.high => 'High Confidence',
    ConfidenceLevel.moderate => 'Moderate Confidence',
    ConfidenceLevel.low => 'Low Confidence',
  };
}

class DiseaseEvidence {
  final String disease;
  final double bestConfidence;
  final double avgConfidence;
  final int detectionCount;

  const DiseaseEvidence({
    required this.disease,
    required this.bestConfidence,
    required this.avgConfidence,
    required this.detectionCount,
  });
}

class TriageResult {
  final DiseasePresenceStatus presenceStatus;
  final String? detectedDisease;
  final EvidenceStrength evidenceStrength;
  final UrgencyLevel urgency;
  final double? confidence;
  final ConfidenceLevel? confidenceLevel;
  final DiseaseRiskLevel? diseaseRisk;
  final int detectionCount;
  final int symptomCount;
  final bool isAmbiguous;
  final String reasoning;
  final String recommendation;
  final DateTime timestamp;
  final File? image;
  final String? catId;
  final List<String> selectedSymptoms;
  final ScanComparisonTrend? comparisonTrend;
  final String? comparisonSummary;
  final bool isLowQuality;

  const TriageResult({
    required this.presenceStatus,
    required this.detectedDisease,
    required this.evidenceStrength,
    required this.urgency,
    required this.confidence,
    required this.confidenceLevel,
    required this.diseaseRisk,
    required this.detectionCount,
    required this.symptomCount,
    required this.isAmbiguous,
    required this.reasoning,
    required this.recommendation,
    required this.timestamp,
    required this.image,
    this.catId,
    this.selectedSymptoms = const [],
    this.comparisonTrend,
    this.comparisonSummary,
    this.isLowQuality = false,
  });

  TriageResult copyWith({
    String? reasoning,
    File? image,
    String? catId,
    List<String>? selectedSymptoms,
    ScanComparisonTrend? comparisonTrend,
    String? comparisonSummary,
    bool? isLowQuality,
  }) {
    return TriageResult(
      presenceStatus: presenceStatus,
      detectedDisease: detectedDisease,
      evidenceStrength: evidenceStrength,
      urgency: urgency,
      confidence: confidence,
      confidenceLevel: confidenceLevel,
      diseaseRisk: diseaseRisk,
      detectionCount: detectionCount,
      symptomCount: symptomCount,
      isAmbiguous: isAmbiguous,
      reasoning: reasoning ?? this.reasoning,
      recommendation: recommendation,
      timestamp: timestamp,
      image: image ?? this.image,
      catId: catId ?? this.catId,
      selectedSymptoms: selectedSymptoms ?? this.selectedSymptoms,
      comparisonTrend: comparisonTrend ?? this.comparisonTrend,
      comparisonSummary: comparisonSummary ?? this.comparisonSummary,
      isLowQuality: isLowQuality ?? this.isLowQuality,
    );
  }

  ScanComparisonTrend compareToPrevious(TriageResult previous) {
    final currentRank = _urgencyRank(urgency);
    final previousRank = _urgencyRank(previous.urgency);

    if (currentRank < previousRank) return ScanComparisonTrend.improved;
    if (currentRank > previousRank) return ScanComparisonTrend.worsened;

    if (confidence != null && previous.confidence != null) {
      if (confidence! > previous.confidence! + 0.06) {
        return ScanComparisonTrend.improved;
      }
      if (confidence! < previous.confidence! - 0.06) {
        return ScanComparisonTrend.worsened;
      }
    }

    return ScanComparisonTrend.noChange;
  }

  int _urgencyRank(UrgencyLevel level) => switch (level) {
    UrgencyLevel.stable => 0,
    UrgencyLevel.moderate => 1,
    UrgencyLevel.high => 2,
  };

  Map<String, dynamic> toJson() => {
    'presenceStatus': presenceStatus.name,
    'detectedDisease': detectedDisease,
    'evidenceStrength': evidenceStrength.name,
    'urgency': urgency.name,
    'confidence': confidence,
    'confidenceLevel': confidenceLevel?.name,
    'diseaseRisk': diseaseRisk?.name,
    'detectionCount': detectionCount,
    'symptomCount': symptomCount,
    'isAmbiguous': isAmbiguous,
    'reasoning': reasoning,
    'recommendation': recommendation,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': image?.path,
    'catId': catId,
    'selectedSymptoms': selectedSymptoms,
    'comparisonTrend': comparisonTrend?.name,
    'comparisonSummary': comparisonSummary,
    'isLowQuality': isLowQuality,
  };

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    final imagePath = json['imagePath'] as String?;
    return TriageResult(
      presenceStatus: DiseasePresenceStatus.values.byName(
        json['presenceStatus'] as String,
      ),
      detectedDisease: json['detectedDisease'] as String?,
      evidenceStrength: EvidenceStrength.values.byName(
        json['evidenceStrength'] as String,
      ),
      urgency: UrgencyLevel.values.byName(json['urgency'] as String),
      confidence: (json['confidence'] as num?)?.toDouble(),
      confidenceLevel: json['confidenceLevel'] != null
          ? ConfidenceLevel.values.byName(json['confidenceLevel'] as String)
          : null,
      diseaseRisk: json['diseaseRisk'] != null
          ? DiseaseRiskLevel.values.byName(json['diseaseRisk'] as String)
          : null,
      detectionCount: json['detectionCount'] as int,
      symptomCount: json['symptomCount'] as int,
      isAmbiguous: json['isAmbiguous'] as bool,
      reasoning: json['reasoning'] as String,
      recommendation: json['recommendation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      image: (imagePath != null && imagePath.isNotEmpty)
          ? File(imagePath)
          : null,
      catId: json['catId'] as String?,
      selectedSymptoms: List<String>.from(json['selectedSymptoms'] ?? const []),
      comparisonTrend: json['comparisonTrend'] != null
          ? ScanComparisonTrend.values.byName(json['comparisonTrend'] as String)
          : null,
      comparisonSummary: json['comparisonSummary'] as String?,
      isLowQuality: json['isLowQuality'] as bool? ?? false,
    );
  }
}

ConfidenceLevel confidenceLevelFor(double conf) {
  if (conf >= 0.70) return ConfidenceLevel.high;
  if (conf >= 0.55) return ConfidenceLevel.moderate;
  return ConfidenceLevel.low;
}

String encodeHistory(List<TriageResult> history) =>
    jsonEncode(history.map((result) => result.toJson()).toList());
