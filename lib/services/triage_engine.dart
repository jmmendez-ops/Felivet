import 'dart:io';

import '../config/detection_config.dart';
import '../models/triage_models.dart';

double? extractConfidence(Map res) {
  try {
    final box = res['box'] as List?;
    if (box != null && box.length > 4) {
      final v = (box[4] as num).toDouble();
      if (v >= 0.0 && v <= 1.0) return v;
    }
  } catch (_) {}
  try {
    if (res['confidence'] != null) {
      final v = (res['confidence'] as num).toDouble();
      if (v >= 0.0 && v <= 1.0) return v;
    }
  } catch (_) {}
  return null;
}

TriageResult runExpertSystem({
  required List<DiseaseEvidence> evidenceList,
  required int symptomCount,
  File? image,
}) {
  final sorted = [...evidenceList]
    ..sort((a, b) {
      final c = b.bestConfidence.compareTo(a.bestConfidence);
      if (c != 0) return c;
      final d = b.detectionCount.compareTo(a.detectionCount);
      if (d != 0) return d;
      return a.disease.compareTo(b.disease);
    });

  if (sorted.isEmpty) {
    if (symptomCount >= 3) {
      return TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.high,
        confidence: null,
        confidenceLevel: null,
        diseaseRisk: null,
        detectionCount: 0,
        symptomCount: symptomCount,
        isAmbiguous: false,
        reasoning:
            'No supported skin condition was visually detected. However, three or more systemic symptoms were reported. A negative visual result does not rule out internal illness, early-stage disease, or conditions outside this model\'s training classes.',
        recommendation:
            'NO VISUAL DISEASE DETECTED — SYMPTOMS REQUIRE ATTENTION. Seek veterinary care promptly to evaluate the reported symptoms.',
        timestamp: DateTime.now(),
        image: image,
      );
    } else if (symptomCount >= 1) {
      return TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.moderate,
        confidence: null,
        confidenceLevel: null,
        diseaseRisk: null,
        detectionCount: 0,
        symptomCount: symptomCount,
        isAmbiguous: false,
        reasoning:
            'No supported skin condition was visually detected. ${symptomCount == 1 ? 'One systemic symptom was' : 'Two systemic symptoms were'} reported; ${symptomCount == 1 ? 'it' : 'they'} may be unrelated to a skin condition, but a reported symptom should still be addressed rather than left unchecked.',
        recommendation:
            'Consult a vet to evaluate the reported symptom(s) — please don\'t wait, even though no skin condition was visually detected.',
        timestamp: DateTime.now(),
        image: image,
      );
    } else {
      return TriageResult(
        presenceStatus: DiseasePresenceStatus.notDetected,
        detectedDisease: null,
        evidenceStrength: EvidenceStrength.insufficient,
        urgency: UrgencyLevel.stable,
        confidence: null,
        confidenceLevel: null,
        diseaseRisk: null,
        detectionCount: 0,
        symptomCount: 0,
        isAmbiguous: false,
        reasoning:
            'The model did not find sufficient visual evidence of any of the supported skin conditions, and no systemic symptoms were reported. This does not confirm the cat is completely healthy — it only reflects the absence of detectable evidence for this model\'s specific disease classes.',
        recommendation:
            'NO SUPPORTED SKIN DISEASE DETECTED. Continue routine monitoring and schedule regular vet check-ups.',
        timestamp: DateTime.now(),
        image: image,
      );
    }
  }

  final top = sorted.first;
  final second = sorted.length > 1 ? sorted[1] : null;

  final DiseaseRiskLevel riskLevel =
      DetectionConfig.diseaseRisk[top.disease] ?? DiseaseRiskLevel.moderate;
  final ConfidenceLevel confLevel = confidenceLevelFor(top.bestConfidence);

  final bool isAmbiguous =
      second != null &&
      (top.bestConfidence - second.bestConfidence) <
          DetectionConfig.ambiguityMargin;

  EvidenceStrength strength;
  DiseasePresenceStatus presence;

  if (top.bestConfidence >= DetectionConfig.strongEvidenceConfidence &&
      top.detectionCount >= DetectionConfig.strongEvidenceMinDetections) {
    strength = EvidenceStrength.strong;
    presence = DiseasePresenceStatus.detected;
  } else if (top.bestConfidence >= DetectionConfig.moderateEvidenceConfidence &&
      top.detectionCount >= DetectionConfig.moderateEvidenceMinDetections) {
    strength = EvidenceStrength.moderate;
    presence = DiseasePresenceStatus.likelyDetected;
  } else if (top.bestConfidence >= DetectionConfig.minDetectionConfidence) {
    strength = EvidenceStrength.weak;
    presence = DiseasePresenceStatus.uncertain;
  } else {
    strength = EvidenceStrength.insufficient;
    presence = DiseasePresenceStatus.notDetected;
  }

  if (isAmbiguous && presence != DiseasePresenceStatus.notDetected) {
    presence = DiseasePresenceStatus.uncertain;
  }

  UrgencyLevel urgency;
  String reasoning;
  String recommendation;

  if (presence == DiseasePresenceStatus.notDetected) {
    if (symptomCount >= 3) {
      urgency = UrgencyLevel.high;
    } else if (symptomCount >= 1) {
      urgency = UrgencyLevel.moderate;
    } else {
      urgency = UrgencyLevel.stable;
    }
    reasoning =
        'Visual confidence (${(top.bestConfidence * 100).toStringAsFixed(0)}%) for ${top.disease} fell below the threshold needed to establish disease presence. This does not confirm the cat is healthy — the image may be unclear, poorly lit, or the condition may be very early-stage.';
    recommendation = symptomCount > 0
        ? 'Visual evidence is insufficient to confidently classify a condition. Consider retaking the photo with better lighting and a clearer view, and have the reported symptom(s) evaluated — please don\'t wait.'
        : 'Visual evidence is insufficient to confidently classify a condition. Consider retaking the photo with better lighting and a clearer view.';
  } else if (presence == DiseasePresenceStatus.uncertain) {
    urgency = symptomCount >= 2 ? UrgencyLevel.high : UrgencyLevel.moderate;
    if (isAmbiguous) {
      reasoning =
          'The model detected evidence that may correspond to more than one supported skin condition (${top.disease} vs ${second.disease}, scores within ${(DetectionConfig.ambiguityMargin * 100).toStringAsFixed(0)}% of each other). The visual result is inconclusive.${symptomCount >= 2 ? ' Multiple systemic symptoms were also reported alongside this suspected skin condition, which escalates the case regardless of the inconclusive visual result.' : ''}';
      recommendation = symptomCount >= 2
          ? 'CRITICAL: Uncertain Visual Classification with multiple systemic symptoms — seek veterinary care promptly. The visual result is inconclusive between candidate conditions, but the combination with multiple symptoms warrants urgency.'
          : 'Uncertain Visual Classification — the result is inconclusive between candidate conditions. A vet visit is recommended for a clear diagnosis.';
    } else {
      reasoning =
          'Weak visual evidence for ${top.disease} (${(top.bestConfidence * 100).toStringAsFixed(0)}% confidence, ${top.detectionCount} detection(s)). Evidence is too limited to confidently establish disease presence. ${top.disease} is a ${riskLevel.label.toLowerCase()} condition — low confidence does not mean the condition, if present, would be minor.${symptomCount >= 2 ? ' Multiple systemic symptoms were also reported, which escalates this case even though visual confidence is low.' : ''}';
      recommendation = symptomCount >= 2
          ? 'CRITICAL: Possible ${top.disease} with multiple systemic symptoms — seek veterinary care promptly. Confidence in the visual finding is low, but the combination with multiple symptoms warrants urgency.'
          : 'Possible ${top.disease} — Low Confidence. Consider retaking the photo with better lighting and a clearer view of the affected area, and don\'t assume the condition is mild just because confidence is low.';
    }
  } else {
    final bool broadVisualSpread =
        top.detectionCount >= DetectionConfig.strongEvidenceMinDetections;

    if (strength == EvidenceStrength.strong &&
        riskLevel == DiseaseRiskLevel.high) {
      urgency = UrgencyLevel.high;
      reasoning =
          '${top.disease} is a high-clinical-risk condition, and visual evidence is ${strength.label.toLowerCase()} (${top.detectionCount} detection(s), ${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence). Because the suspected disease itself carries significant risk, this is treated as urgent regardless of symptom count or affected-area size.';
      recommendation =
          'CRITICAL: ${top.disease} is a high-risk condition with strong visual evidence. Seek veterinary care promptly, even without other symptoms.';
    } else if (symptomCount >= 2) {
      urgency = UrgencyLevel.high;
      reasoning =
          '${top.disease} evidence is ${strength.label.toLowerCase()} (${top.detectionCount} detection(s), ${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, ${riskLevel.label.toLowerCase()}), and multiple systemic symptoms were reported. The combination of visual and systemic evidence indicates the condition is actively affecting overall health.';
      recommendation =
          'CRITICAL: Seek veterinary care immediately — visual findings and systemic symptoms both point to an actively worsening condition.';
    } else if (symptomCount == 1) {
      urgency = UrgencyLevel.moderate;
      reasoning =
          '${top.disease} evidence is ${strength.label.toLowerCase()} (${top.detectionCount} detection(s), ${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, ${riskLevel.label.toLowerCase()}). One systemic symptom was also reported; it may or may not be related to the skin condition and should be evaluated separately.';
      recommendation =
          'Consult a vet soon. ${top.disease} appears to be present and the reported symptom warrants a closer look, even if the two are unrelated.';
    } else if (broadVisualSpread && strength == EvidenceStrength.strong) {
      urgency = UrgencyLevel.moderate;
      reasoning =
          '${top.disease} shows ${strength.label.toLowerCase()} across ${top.detectionCount} distinct detected area(s) (${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, ${riskLevel.label.toLowerCase()}), with no systemic symptoms reported. Wide visual spread alone warrants attention even without other symptoms.';
      recommendation =
          'The affected area appears widespread. Please consult a vet soon even though your cat isn\'t showing other symptoms.';
    } else {
      urgency = UrgencyLevel.moderate;
      reasoning =
          '${top.disease} evidence is ${strength.label.toLowerCase()} (${top.detectionCount} detection(s), ${(top.bestConfidence * 100).toStringAsFixed(0)}% best confidence, ${riskLevel.label.toLowerCase()}), with no systemic symptoms reported. A small affected area does not rule out a condition that still needs treatment.';
      recommendation =
          'AI detected a likely localized case of ${top.disease}. This skin condition is contagious and requires medical treatment. Please consult a vet soon.';
    }
  }

  return TriageResult(
    presenceStatus: presence,
    detectedDisease: presence == DiseasePresenceStatus.notDetected
        ? null
        : top.disease,
    evidenceStrength: strength,
    urgency: urgency,
    confidence: top.bestConfidence,
    confidenceLevel: confLevel,
    diseaseRisk: presence == DiseasePresenceStatus.notDetected
        ? null
        : riskLevel,
    detectionCount: top.detectionCount,
    symptomCount: symptomCount,
    isAmbiguous: isAmbiguous,
    reasoning: reasoning,
    recommendation: recommendation,
    timestamp: DateTime.now(),
    image: image,
  );
}
