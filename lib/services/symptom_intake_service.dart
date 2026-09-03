import 'dart:convert';

class SymptomIntakeService {
  static const int maxFollowUpTurns = 4;

  static SymptomIntakeResult analyze({
    required String userText,
    required Set<String> selectedSymptoms,
    required int turnCount,
  }) {
    final normalizedText = userText.trim().toLowerCase();

    final redFlag = _containsRedFlag(normalizedText, selectedSymptoms);
    if (redFlag) {
      return SymptomIntakeResult(
        redFlag: true,
        confidence: 0.0,
        extractedSymptoms: _emptySymptoms(),
        missingCriticalFields: const [],
        clarifyingQuestions: const [],
        readyForExpertSystem: false,
        partialData: false,
        inferenceMode: 'rule_based',
      );
    }

    final hasExplicitDetails = _hasMeaningfulDetails(normalizedText);
    final confidence = hasExplicitDetails ? 0.72 : 0.45;

    final extractedSymptoms = _buildExtractedSymptoms(
      normalizedText,
      selectedSymptoms,
    );
    final missingCriticalFields = _collectMissingFields(extractedSymptoms);

    final needsClarification =
        confidence < 0.6 || missingCriticalFields.isNotEmpty;
    final reachedTurnLimit = turnCount >= maxFollowUpTurns;

    final readyForExpertSystem = !needsClarification || reachedTurnLimit;

    return SymptomIntakeResult(
      redFlag: false,
      confidence: confidence,
      extractedSymptoms: extractedSymptoms,
      missingCriticalFields: missingCriticalFields,
      clarifyingQuestions: needsClarification && !reachedTurnLimit
          ? [
              'Please describe the symptoms you are noticing, including how long they have lasted.',
            ]
          : const [],
      readyForExpertSystem: readyForExpertSystem,
      partialData: reachedTurnLimit && missingCriticalFields.isNotEmpty,
      inferenceMode: 'rule_based',
    );
  }

  static bool _containsRedFlag(String text, Set<String> selectedSymptoms) {
    final emergencyMarkers = [
      'blood',
      'difficulty breathing',
      'trouble breathing',
      'collapse',
      'severe',
      'sudden',
      "won't stop",
      "won't stop",
    ];

    final hasEmergencyMarker = emergencyMarkers.any(text.contains);
    final hasEmergencySymptomCombination =
        selectedSymptoms.contains('vomiting') &&
        selectedSymptoms.contains('lethargy') &&
        selectedSymptoms.contains('loss_of_appetite');

    return hasEmergencyMarker || hasEmergencySymptomCombination;
  }

  static bool _hasMeaningfulDetails(String text) {
    return text.isNotEmpty &&
        text.split(RegExp(r'\s+')).length >= 3 &&
        !text.contains('seems off') &&
        !text.contains('something is wrong');
  }

  static Map<String, SymptomField> _emptySymptoms() {
    return {
      'symptom_a': SymptomField.presentUnknown(),
      'symptom_b': SymptomField.presentUnknown(),
      'symptom_c': SymptomField.presentUnknown(),
      'symptom_d': SymptomField.presentUnknown(),
      'symptom_e': SymptomField.presentUnknown(),
      'symptom_f': SymptomField.presentUnknown(),
    };
  }

  static Map<String, SymptomField> _buildExtractedSymptoms(
    String text,
    Set<String> selectedSymptoms,
  ) {
    final symptoms = _emptySymptoms();

    if (text.contains('vomiting')) {
      symptoms['symptom_a'] = SymptomField(
        present: 'yes',
        severity: selectedSymptoms.contains('vomiting')
            ? 'moderate'
            : 'unknown',
        durationDays: 'unknown',
      );
    }
    if (text.contains('lethargy') || selectedSymptoms.contains('lethargy')) {
      symptoms['symptom_b'] = SymptomField(
        present: 'yes',
        severity: selectedSymptoms.contains('lethargy')
            ? 'moderate'
            : 'unknown',
        durationDays: 'unknown',
      );
    }
    if (text.contains('appetite') ||
        selectedSymptoms.contains('loss_of_appetite')) {
      symptoms['symptom_c'] = SymptomField(
        present: 'yes',
        severity: selectedSymptoms.contains('loss_of_appetite')
            ? 'moderate'
            : 'unknown',
        durationDays: 'unknown',
      );
    }
    if (text.contains('rash')) {
      symptoms['symptom_d'] = SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }

    return symptoms;
  }

  static List<String> _collectMissingFields(
    Map<String, SymptomField> symptoms,
  ) {
    final missing = <String>[];
    for (final entry in symptoms.entries) {
      if (entry.value.present == 'unknown') {
        missing.add('${entry.key}.present');
      }
      if (entry.value.severity == 'unknown') {
        missing.add('${entry.key}.severity');
      }
      if (entry.value.durationDays == 'unknown') {
        missing.add('${entry.key}.duration_days');
      }
    }
    return missing;
  }

  static Future<String> generateChatReply({
    required String userMessage,
    required List<String> history,
  }) async {
    final message = userMessage.trim().toLowerCase();
    final hasVomiting =
        message.contains('vomit') || message.contains('throwing up');
    final hasSleepy = message.contains('sleep') || message.contains('letharg');
    final hasAppetite =
        message.contains('appetite') || message.contains('eating');

    if (hasVomiting && hasSleepy) {
      return 'That combination can be concerning. Please monitor your cat closely and contact a veterinarian soon, especially if the vomiting continues or your cat becomes worse.';
    }

    if (hasVomiting) {
      return 'Vomiting can have many causes. If it continues for more than a day, or your cat seems weak, please contact a vet.';
    }

    if (hasSleepy) {
      return 'Lethargy can be a sign that your cat needs veterinary attention, especially if it is new or severe.';
    }

    if (hasAppetite) {
      return 'Loss of appetite can be a clue that something is wrong. If your cat is refusing food for more than a day, it is wise to contact a vet.';
    }

    if (history.isNotEmpty) {
      return 'I can help you track symptoms and decide whether veterinary advice is appropriate. Tell me more about what your cat is doing.';
    }

    return 'I can help you describe your cat\'s symptoms and suggest when veterinary care may be needed. What is happening today?';
  }

  static Future<SymptomIntakeResult> extractChecklistFromText({
    required String userText,
    required Set<String> selectedSymptoms,
    required int turnCount,
  }) async {
    final normalizedText = userText.trim();
    if (normalizedText.isEmpty) {
      return _buildConservativeChecklist('', selectedSymptoms, turnCount);
    }

    return _buildFallbackResult(
      normalizedText,
      selectedSymptoms,
      turnCount,
      'rule_based',
    );
  }

  static SymptomIntakeResult? parseStructuredIntakeResult(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final extracted = <String, SymptomField>{};
      final symptoms = decoded['extracted_symptoms'] as Map<String, dynamic>?;
      if (symptoms == null) {
        return null;
      }

      for (final entry in symptoms.entries) {
        final value = entry.value as Map<String, dynamic>?;
        if (value == null) continue;
        extracted[entry.key] = SymptomField(
          present: (value['present'] ?? 'unknown').toString(),
          severity: (value['severity'] ?? 'unknown').toString(),
          durationDays: (value['duration_days'] ?? 'unknown').toString(),
        );
      }

      return SymptomIntakeResult(
        redFlag: (decoded['red_flag'] as bool?) ?? false,
        confidence: (decoded['confidence'] as num?)?.toDouble() ?? 0.0,
        extractedSymptoms: extracted,
        missingCriticalFields: List<String>.from(
          decoded['missing_critical_fields'] ?? const [],
        ),
        clarifyingQuestions: List<String>.from(
          decoded['clarifying_questions'] ?? const [],
        ),
        readyForExpertSystem:
            (decoded['ready_for_expert_system'] as bool?) ?? false,
        partialData: (decoded['partial_data'] as bool?) ?? false,
        inferenceMode: (decoded['inference_mode'] as String?) ?? 'local_model',
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, bool> checklistFlagsFromResult(
    SymptomIntakeResult result,
  ) {
    return {
      'vomiting': result.extractedSymptoms['symptom_a']?.present == 'yes',
      'lethargy': result.extractedSymptoms['symptom_b']?.present == 'yes',
      'loss_of_appetite':
          result.extractedSymptoms['symptom_c']?.present == 'yes',
    };
  }

  static SymptomIntakeResult _buildConservativeChecklist(
    String userText,
    Set<String> selectedSymptoms,
    int turnCount,
  ) {
    final normalizedText = userText.trim().toLowerCase();
    final hasAnySymptom =
        normalizedText.contains('vomit') ||
        normalizedText.contains('throwing up') ||
        normalizedText.contains('heaving') ||
        normalizedText.contains('letharg') ||
        normalizedText.contains('sleepy') ||
        normalizedText.contains('appetite') ||
        normalizedText.contains('eating') ||
        selectedSymptoms.isNotEmpty;

    final symptoms = _emptySymptoms();
    if (normalizedText.contains('vomit') ||
        normalizedText.contains('throwing up') ||
        normalizedText.contains('heaving')) {
      symptoms['symptom_a'] = const SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }
    if (normalizedText.contains('letharg') ||
        normalizedText.contains('sleepy') ||
        normalizedText.contains('lazy')) {
      symptoms['symptom_b'] = const SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }
    if (normalizedText.contains('appetite') ||
        normalizedText.contains('eating') ||
        normalizedText.contains('food')) {
      symptoms['symptom_c'] = const SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }

    final missingCriticalFields = _collectMissingFields(symptoms);
    final clarifyingQuestions =
        hasAnySymptom && missingCriticalFields.isNotEmpty
        ? [
            'Please say whether the symptom is present, and mention if it is worsening or lasting.',
          ]
        : const <String>[];
    final needsClarification =
        !hasAnySymptom || missingCriticalFields.isNotEmpty;

    return SymptomIntakeResult(
      redFlag: false,
      confidence: hasAnySymptom ? 0.7 : 0.0,
      extractedSymptoms: symptoms,
      missingCriticalFields: missingCriticalFields,
      clarifyingQuestions: needsClarification && turnCount < maxFollowUpTurns
          ? clarifyingQuestions
          : const [],
      readyForExpertSystem:
          !needsClarification || turnCount >= maxFollowUpTurns,
      partialData:
          turnCount >= maxFollowUpTurns && missingCriticalFields.isNotEmpty,
      inferenceMode: 'rule_based',
    );
  }

  static SymptomIntakeResult _buildFallbackResult(
    String userText,
    Set<String> selectedSymptoms,
    int turnCount,
    String inferenceMode,
  ) {
    final fallback = _buildConservativeChecklist(
      userText,
      selectedSymptoms,
      turnCount,
    );
    return fallback.copyWith(inferenceMode: inferenceMode);
  }

  static String normalizeModelOutput(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return '{"red_flag": false, "confidence": 0.0, "extracted_symptoms": {"symptom_a": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_b": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_c": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_d": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_e": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_f": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}}, "missing_critical_fields": [], "clarifying_questions": [], "ready_for_expert_system": false, "partial_data": false}';
    }

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final candidate = cleaned.substring(start, end + 1);
      try {
        jsonDecode(candidate);
        return candidate;
      } catch (_) {}
    }

    return '{"red_flag": false, "confidence": 0.0, "extracted_symptoms": {"symptom_a": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_b": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_c": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_d": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_e": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_f": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}}, "missing_critical_fields": [], "clarifying_questions": [], "ready_for_expert_system": false, "partial_data": false}';
  }
}

class SymptomIntakeResult {
  final bool redFlag;
  final double confidence;
  final Map<String, SymptomField> extractedSymptoms;
  final List<String> missingCriticalFields;
  final List<String> clarifyingQuestions;
  final bool readyForExpertSystem;
  final bool partialData;
  final String inferenceMode;

  const SymptomIntakeResult({
    required this.redFlag,
    required this.confidence,
    required this.extractedSymptoms,
    required this.missingCriticalFields,
    required this.clarifyingQuestions,
    required this.readyForExpertSystem,
    required this.partialData,
    this.inferenceMode = 'rule_based',
  });

  SymptomIntakeResult copyWith({
    bool? redFlag,
    double? confidence,
    Map<String, SymptomField>? extractedSymptoms,
    List<String>? missingCriticalFields,
    List<String>? clarifyingQuestions,
    bool? readyForExpertSystem,
    bool? partialData,
    String? inferenceMode,
  }) {
    return SymptomIntakeResult(
      redFlag: redFlag ?? this.redFlag,
      confidence: confidence ?? this.confidence,
      extractedSymptoms: extractedSymptoms ?? this.extractedSymptoms,
      missingCriticalFields:
          missingCriticalFields ?? this.missingCriticalFields,
      clarifyingQuestions: clarifyingQuestions ?? this.clarifyingQuestions,
      readyForExpertSystem: readyForExpertSystem ?? this.readyForExpertSystem,
      partialData: partialData ?? this.partialData,
      inferenceMode: inferenceMode ?? this.inferenceMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'red_flag': redFlag,
    'confidence': confidence,
    'extracted_symptoms': {
      for (final entry in extractedSymptoms.entries)
        entry.key: entry.value.toJson(),
    },
    'missing_critical_fields': missingCriticalFields,
    'clarifying_questions': clarifyingQuestions,
    'ready_for_expert_system': readyForExpertSystem,
    'partial_data': partialData,
    'inference_mode': inferenceMode,
  };
}

class SymptomField {
  final String present;
  final String severity;
  final String durationDays;

  const SymptomField({
    required this.present,
    required this.severity,
    required this.durationDays,
  });

  factory SymptomField.presentUnknown() => const SymptomField(
    present: 'unknown',
    severity: 'unknown',
    durationDays: 'unknown',
  );

  Map<String, dynamic> toJson() => {
    'present': present,
    'severity': severity,
    'duration_days': durationDays,
  };
}
