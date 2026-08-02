import 'package:flutter_test/flutter_test.dart';
import 'package:feline_detector/screens/triage_submission_validator.dart';

void main() {
  group('triage submission validation', () {
    test('allows photo without symptoms', () {
      final result = validateTriageSubmission(
        hasImage: true,
        hasSymptoms: false,
      );

      expect(result.allowed, isTrue);
      expect(result.message, isNull);
    });

    test('blocks symptoms without a photo', () {
      final result = validateTriageSubmission(
        hasImage: false,
        hasSymptoms: true,
      );

      expect(result.allowed, isFalse);
      expect(result.message, contains('photo'));
    });

    test('blocks empty submission without a photo', () {
      final result = validateTriageSubmission(
        hasImage: false,
        hasSymptoms: false,
      );

      expect(result.allowed, isFalse);
      expect(result.message, contains('photo'));
    });
  });
}
