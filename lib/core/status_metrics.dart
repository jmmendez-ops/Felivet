import '../models/triage_models.dart';

class StatusMetrics {
  final List<TriageResult> scans;

  StatusMetrics(Iterable<TriageResult> history)
    : scans = (history.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));

  TriageResult? get latest => scans.isEmpty ? null : scans.first;

  TriageResult? get previous => scans.length < 2 ? null : scans[1];

  List<TriageResult> get trendScans => scans.length <= 10
      ? scans.reversed.toList()
      : scans.take(10).toList().reversed.toList();

  int? get daysSinceLatest {
    final scan = latest;
    if (scan == null) return null;
    return DateTime.now().difference(scan.timestamp).inDays;
  }

  ScanComparisonTrend? get comparison {
    final current = latest;
    final prior = previous;
    if (current == null || prior == null) return null;
    return current.compareToPrevious(prior);
  }

  List<SymptomSummary> get recurringSymptoms {
    final summaries = <String, SymptomSummary>{};
    for (final scan in scans) {
      for (final symptom in scan.selectedSymptoms) {
        final existing = summaries[symptom];
        if (existing == null) {
          summaries[symptom] = SymptomSummary(
            name: symptomDisplayName(symptom),
            count: 1,
            lastReported: scan.timestamp,
          );
        } else {
          summaries[symptom] = existing.copyWith(count: existing.count + 1);
        }
      }
    }
    final result = summaries.values.toList()
      ..sort((a, b) {
        final countOrder = b.count.compareTo(a.count);
        return countOrder == 0
            ? b.lastReported.compareTo(a.lastReported)
            : countOrder;
      });
    return result.take(3).toList();
  }
}

class SymptomSummary {
  final String name;
  final int count;
  final DateTime lastReported;

  const SymptomSummary({
    required this.name,
    required this.count,
    required this.lastReported,
  });

  SymptomSummary copyWith({int? count}) => SymptomSummary(
    name: name,
    count: count ?? this.count,
    lastReported: lastReported,
  );
}

String symptomDisplayName(String value) => switch (value) {
  'loss_of_appetite' => 'Loss of appetite',
  'lethargy' => 'Lethargy',
  'vomiting' => 'Vomiting',
  _ => value.replaceAll('_', ' '),
};

String formatStatusDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}';

String formatStatusDateTime(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year} - ${_formatHour(date)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

String relativeStatusDate(DateTime date) {
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '$days days ago';
}

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

int _formatHour(DateTime date) {
  final hour = date.hour % 12;
  return hour == 0 ? 12 : hour;
}
