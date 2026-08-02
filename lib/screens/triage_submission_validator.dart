class TriageSubmissionValidationResult {
  const TriageSubmissionValidationResult({required this.allowed, this.message});

  final bool allowed;
  final String? message;
}

TriageSubmissionValidationResult validateTriageSubmission({
  required bool hasImage,
  required bool hasSymptoms,
}) {
  if (hasImage) {
    return const TriageSubmissionValidationResult(allowed: true);
  }

  if (hasSymptoms) {
    return const TriageSubmissionValidationResult(
      allowed: false,
      message: 'Please upload a photo before submitting symptoms.',
    );
  }

  return const TriageSubmissionValidationResult(
    allowed: false,
    message: 'Please upload a photo before submitting.',
  );
}
