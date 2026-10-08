import 'package:flutter/material.dart';

import '../core/status_metrics.dart';
import '../core/ui_tokens.dart';
import '../models/triage_models.dart';

class StatusScreen extends StatefulWidget {
  final List<TriageResult> history;

  const StatusScreen({super.key, required this.history});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = StatusMetrics(widget.history);
    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FeliVetUi.spaceLg,
              FeliVetUi.spaceMd,
              FeliVetUi.spaceLg,
              FeliVetUi.spaceXl + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metrics.latest == null)
                  _buildEmptyState(context)
                else ...[
                  _buildLastScanCard(context, metrics),
                  const SizedBox(height: FeliVetUi.spaceMd),
                  _buildChangeCard(context, metrics),
                  const SizedBox(height: FeliVetUi.spaceMd),
                  _buildTrendCard(context, metrics),
                  if (metrics.recurringSymptoms.isNotEmpty) ...[
                    const SizedBox(height: FeliVetUi.spaceMd),
                    _buildSymptomsCard(context, metrics.recurringSymptoms),
                  ],
                  if ((metrics.daysSinceLatest ?? 0) >= 5) ...[
                    const SizedBox(height: FeliVetUi.spaceMd),
                    _buildReminder(context, metrics.daysSinceLatest!),
                  ],
                  const SizedBox(height: FeliVetUi.spaceMd),
                  _buildDisclaimer(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FeliVetUi.spaceXl),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 42, color: scheme.primary),
          const SizedBox(height: FeliVetUi.spaceMd),
          Text(
            'No scan progress yet',
            style: FeliVetUi.heading(context, size: 18),
          ),
          const SizedBox(height: FeliVetUi.spaceSm),
          Text(
            'Run your first scan to start tracking changes over time.',
            textAlign: TextAlign.center,
            style: FeliVetUi.muted(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLastScanCard(BuildContext context, StatusMetrics metrics) {
    final scan = metrics.latest!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: FeliVetUi.cardPadding,
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last scan', style: FeliVetUi.muted(context, size: 12)),
          const SizedBox(height: FeliVetUi.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  formatStatusDateTime(scan.timestamp),
                  style: FeliVetUi.heading(context, size: 17),
                ),
              ),
              _urgencyChip(context, scan.urgency),
            ],
          ),
          const SizedBox(height: FeliVetUi.spaceXs),
          Text(
            relativeStatusDate(scan.timestamp),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeCard(BuildContext context, StatusMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final prior = metrics.previous;
    final comparison = metrics.comparison;
    return Container(
      width: double.infinity,
      padding: FeliVetUi.cardPadding,
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Icon(
            comparison == null
                ? Icons.timeline_outlined
                : _comparisonIcon(comparison),
            color: comparison == null
                ? scheme.primary
                : _comparisonColor(comparison),
            size: 24,
          ),
          const SizedBox(width: FeliVetUi.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change since previous scan',
                  style: FeliVetUi.muted(context, size: 12),
                ),
                const SizedBox(height: FeliVetUi.spaceXs),
                Text(
                  comparison == null
                      ? 'Scan again to see changes'
                      : _comparisonLabel(comparison),
                  style: FeliVetUi.heading(context, size: 16),
                ),
                if (prior != null)
                  Text(
                    'vs ${formatStatusDate(prior.timestamp)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(BuildContext context, StatusMetrics metrics) {
    final scans = metrics.trendScans;
    return Container(
      width: double.infinity,
      padding: FeliVetUi.cardPadding,
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health progress', style: FeliVetUi.heading(context, size: 17)),
          const SizedBox(height: FeliVetUi.spaceXs),
          Text(
            'Urgency across your most recent scans.',
            style: FeliVetUi.muted(context, size: 12),
          ),
          const SizedBox(height: FeliVetUi.spaceMd),
          if (scans.length < 2)
            Text(
              'Complete another scan to see your progress trend.',
              style: FeliVetUi.muted(context),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final scheme = Theme.of(context).colorScheme;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: 190,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      scans: scans,
                      textColor: scheme.onSurfaceVariant,
                      lineColor: scheme.primary,
                      borderColor: scheme.outlineVariant,
                      surfaceColor: scheme.surface,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSymptomsCard(
    BuildContext context,
    List<SymptomSummary> symptoms,
  ) {
    return Container(
      width: double.infinity,
      padding: FeliVetUi.cardPadding,
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recurring symptoms',
            style: FeliVetUi.heading(context, size: 17),
          ),
          const SizedBox(height: FeliVetUi.spaceMd),
          ...symptoms.map(
            (symptom) => Padding(
              padding: const EdgeInsets.only(bottom: FeliVetUi.spaceSm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      symptom.name,
                      style: FeliVetUi.heading(context, size: 14),
                    ),
                  ),
                  Text(
                    '${symptom.count} ${symptom.count == 1 ? 'scan' : 'scans'} · last ${formatStatusDate(symptom.lastReported)}',
                    style: FeliVetUi.muted(context, size: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminder(BuildContext context, int days) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: FeliVetUi.spaceMd,
        vertical: FeliVetUi.spaceSm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(FeliVetUi.compactRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        'Last scanned $days days ago. Consider rescanning.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) => Text(
    'Based on app scan results, not a veterinary diagnosis.',
    style: FeliVetUi.muted(context, size: 11),
  );

  Widget _urgencyChip(BuildContext context, UrgencyLevel urgency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: urgency.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        urgency.label,
        style: TextStyle(
          color: urgency.color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: scheme.outlineVariant),
    );
  }

  String _comparisonLabel(ScanComparisonTrend trend) => switch (trend) {
    ScanComparisonTrend.improved => 'Improving',
    ScanComparisonTrend.worsened => 'Worsening',
    ScanComparisonTrend.noChange => 'Stable',
  };

  IconData _comparisonIcon(ScanComparisonTrend trend) => switch (trend) {
    ScanComparisonTrend.improved => Icons.trending_down_rounded,
    ScanComparisonTrend.worsened => Icons.trending_up_rounded,
    ScanComparisonTrend.noChange => Icons.trending_flat_rounded,
  };

  Color _comparisonColor(ScanComparisonTrend trend) => switch (trend) {
    ScanComparisonTrend.improved => const Color(0xFF6FCF97),
    ScanComparisonTrend.worsened => const Color(0xFFF07A7A),
    ScanComparisonTrend.noChange => Theme.of(context).colorScheme.primary,
  };
}

class _TrendPainter extends CustomPainter {
  final List<TriageResult> scans;
  final Color textColor;
  final Color lineColor;
  final Color borderColor;
  final Color surfaceColor;

  const _TrendPainter({
    required this.scans,
    required this.textColor,
    required this.lineColor,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 56.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (chart.width <= 0 || chart.height <= 0 || scans.length < 2) return;

    final points = List<Offset>.generate(scans.length, (index) {
      final x = chart.left + index * (chart.width / (scans.length - 1));
      final y = chart.bottom - (scans[index].urgency.index / 2) * chart.height;
      return Offset(x, y);
    });

    final gridPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const labels = ['Stable', 'Moderate', 'High'];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < labels.length; i++) {
      final y = chart.bottom - chart.height * i / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: textColor, fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chart.left - textPainter.width - 10, y - textPainter.height / 2),
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = lineColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, linePaint);

    final dateCounts = <String, int>{};
    for (final scan in scans) {
      final date = _dateKey(scan.timestamp);
      dateCounts[date] = (dateCounts[date] ?? 0) + 1;
    }
    final labelIndices = <int>[];
    for (var i = 0; i < points.length; i++) {
      final dateKey = _dateKey(scans[i].timestamp);
      final sameDateIndices = [
        for (var index = 0; index < scans.length; index++)
          if (_dateKey(scans[index].timestamp) == dateKey) index,
      ];
      final isDateBoundary =
          sameDateIndices.first == i || sameDateIndices.last == i;
      if (isDateBoundary &&
          (points.length <= 6 || i.isEven || i == points.length - 1)) {
        labelIndices.add(i);
      }
    }

    final occupiedLabelRightEdges = <double>[];
    for (final i in labelIndices) {
      final point = points[i];
      final urgencyPaint = Paint()..color = scans[i].urgency.color;
      canvas.drawCircle(point, i == points.length - 1 ? 7 : 5, urgencyPaint);
      canvas.drawCircle(
        point,
        i == points.length - 1 ? 7 : 5,
        Paint()
          ..color = surfaceColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final dateKey = _dateKey(scans[i].timestamp);
      final label = dateCounts[dateKey] == 1
          ? formatStatusDate(scans[i].timestamp)
          : formatStatusDateTime(
              scans[i].timestamp,
            ).replaceFirst(RegExp(r' - '), ', ');
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      final leftEdge = point.dx - textPainter.width / 2;
      final rightEdge = point.dx + textPainter.width / 2;
      if (occupiedLabelRightEdges.any(
        (previousRight) => leftEdge < previousRight + 4,
      )) {
        continue;
      }
      occupiedLabelRightEdges.add(rightEdge);
      textPainter.paint(canvas, Offset(leftEdge, chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    if (oldDelegate.textColor != textColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.scans.length != scans.length) {
      return true;
    }
    for (var i = 0; i < scans.length; i++) {
      if (oldDelegate.scans[i].timestamp != scans[i].timestamp ||
          oldDelegate.scans[i].urgency != scans[i].urgency) {
        return true;
      }
    }
    return false;
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
