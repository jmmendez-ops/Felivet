import 'package:flutter_test/flutter_test.dart';
import 'package:feline_detector/services/symptom_intake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SymptomIntakeService', () {
    test('flags red-flag combinations and skips the expert system', () {
      final result = SymptomIntakeService.analyze(
        userText:
            'My cat has been vomiting, seems lethargic, and is not eating.',
        selectedSymptoms: const {'vomiting', 'lethargy', 'loss_of_appetite'},
        turnCount: 1,
      );

      expect(result.redFlag, isTrue);
      expect(result.readyForExpertSystem, isFalse);
      expect(result.partialData, isFalse);
    });

    test(
      'requests clarification when confidence is low and details are missing',
      () {
        final result = SymptomIntakeService.analyze(
          userText: 'My cat seems off.',
          selectedSymptoms: const {},
          turnCount: 1,
        );

        expect(result.confidence, lessThan(0.6));
        expect(result.readyForExpertSystem, isFalse);
        expect(result.clarifyingQuestions, isNotEmpty);
      },
    );

    test('marks partial data after the follow-up limit', () {
      final result = SymptomIntakeService.analyze(
        userText: 'My cat has a rash.',
        selectedSymptoms: const {},
        turnCount: 5,
      );

      expect(result.partialData, isTrue);
      expect(result.readyForExpertSystem, isTrue);
    });

    test('produces a conservative fallback for empty model output', () {
      final normalized = SymptomIntakeService.normalizeModelOutput('');

      expect(normalized, contains('"red_flag": false'));
      expect(normalized, contains('"confidence": 0.0'));
      expect(normalized, contains('"partial_data": false'));
    });

    test('parses a structured checklist response without inventing symptoms', () {
      final parsed = SymptomIntakeService.parseStructuredIntakeResult(
        '{"red_flag":false,"confidence":0.8,"extracted_symptoms":{"symptom_a":{"present":"yes","severity":"moderate","duration_days":"unknown"},"symptom_b":{"present":"unknown","severity":"unknown","duration_days":"unknown"},"symptom_c":{"present":"yes","severity":"mild","duration_days":"2"},"symptom_d":{"present":"unknown","severity":"unknown","duration_days":"unknown"}},"missing_critical_fields":[],"clarifying_questions":[],"ready_for_expert_system":true,"partial_data":false,"inference_mode":"local_model"}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.extractedSymptoms['symptom_a']!.present, 'yes');
      expect(parsed.extractedSymptoms['symptom_c']!.present, 'yes');
      expect(parsed.clarifyingQuestions, isEmpty);
      expect(parsed.inferenceMode, 'local_model');
    });

    test('generates a helpful reply for symptom-related questions', () async {
      final reply = await SymptomIntakeService.generateChatReply(
        userMessage: 'My cat is vomiting and seems sleepy.',
        history: const [],
      );

      expect(reply.toLowerCase(), contains('vomiting'));
      expect(reply.toLowerCase(), contains('vet'));
    });
  });
}
