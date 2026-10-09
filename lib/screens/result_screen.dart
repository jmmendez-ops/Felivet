import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../core/sound_utils.dart';
import '../models/triage_models.dart';
import '../services/report_service.dart';
import 'disease_info_screen.dart';

String reasoningSupportText(TriageResult result) {
  final confidence = result.confidence == null
      ? '(confidence unavailable)'
      : 'at ${(result.confidence! * 100).toStringAsFixed(0)}% confidence';
  final riskSentence = result.diseaseRisk == null
      ? 'Clinical risk could not be estimated'
      : 'This is rated as ${result.diseaseRisk!.label.toLowerCase()}';
  final symptoms = result.symptomCount == 0
      ? '0 symptoms were reported'
      : '${result.symptomCount} symptom${result.symptomCount == 1 ? '' : 's'} '
            '${result.symptomCount == 1 ? 'was' : 'were'} reported';

  return 'The scan found ${result.detectionCount} area${result.detectionCount == 1 ? '' : 's'} '
      'with ${result.evidenceStrength.label.toLowerCase()} $confidence. '
      '$riskSentence, and $symptoms.';
}

class ResultScreen extends StatefulWidget {
  final TriageResult result;
  final List<TriageResult> history;
  final Future<void> Function(TriageResult entry)? onDeleteHistoryEntry;
  final Future<void> Function()? onClearHistory;
  final void Function(ReportFile report)? onViewReports;

  const ResultScreen({
    super.key,
    required this.result,
    required this.history,
    this.onDeleteHistoryEntry,
    this.onClearHistory,
    this.onViewReports,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showDetails = false;
  bool _isExporting = false;

  TriageResult get result => widget.result;

  void _showPhotoPopup(BuildContext context, File image) {
    AppSounds.playTap();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(image, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection'),
        actions: [
          IconButton(
            tooltip: 'Analyze again',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroImage(
                      image: result.image,
                      urgency: result.urgency,
                      onTap: result.image == null
                          ? null
                          : () => _showPhotoPopup(context, result.image!),
                    ),
                    const SizedBox(height: 16),
                    _SummaryCard(result: result),
                    const SizedBox(height: 12),
                    _DiseaseInfoButton(
                      enabled: result.detectedDisease != null,
                      onPressed: result.detectedDisease == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DiseaseInfoScreen(
                                    diseaseName: result.detectedDisease!,
                                  ),
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 12),
                    _DetailsSection(
                      result: result,
                      expanded: _showDetails,
                      onToggle: () =>
                          setState(() => _showDetails = !_showDetails),
                    ),
                    const SizedBox(height: 16),
                    _Disclaimer(color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            _BottomActions(
              onBack: () => Navigator.pop(context),
              onExport: () => _exportPdf(context),
              exporting: _isExporting,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final report = await ReportService.exportReport(result);
      if (!context.mounted) return;
      setState(() => _isExporting = false);
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Report saved'),
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final openResult = await ReportService.openReport(report);
                    if (!context.mounted) return;
                    if (openResult.type != ResultType.done) {
                      await _shareWithFallback(context, report);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('View in Reports'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(context);
                    widget.onViewReports?.call(report);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _shareWithFallback(context, report);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _isExporting = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create PDF report: $error')),
      );
    }
  }

  Future<void> _shareWithFallback(
    BuildContext context,
    ReportFile report,
  ) async {
    try {
      await ReportService.shareReport(report);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No PDF viewer found. Share sheet opened.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open or share report: $error')));
    }
  }
}

class _HeroImage extends StatelessWidget {
  final File? image;
  final UrgencyLevel urgency;
  final VoidCallback? onTap;

  const _HeroImage({
    required this.image,
    required this.urgency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(urgency);
    final statusIcon = _statusIcon(urgency);

    return AspectRatio(
      aspectRatio: 1.65,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image.file(
                  image!,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) => _ImagePlaceholder(),
                )
              else
                const _ImagePlaceholder(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x99000000)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _StatusBadge(
                  urgency: urgency,
                  color: statusColor,
                  icon: statusIcon,
                ),
              ),
              if (onTap != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _Pill(
                    icon: Icons.zoom_in_rounded,
                    label: 'Tap to enlarge',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TriageResult result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(result.urgency);
    final title = result.detectedDisease ?? 'No detected disease';
    final trend = result.comparisonTrend;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Detection Result',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (trend != null)
                _TrendChip(trend: trend, summary: result.comparisonSummary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIcon(color: color, icon: _statusIcon(result.urgency)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.recommendation,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.grid_view_rounded,
                  value: '${result.detectionCount}',
                  label: 'Detected Areas',
                  tooltip: 'Number of visual areas identified in the scan.',
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.checklist_rounded,
                  value: '${result.symptomCount}',
                  label: 'Symptoms',
                  tooltip: 'Symptoms reported during the triage questionnaire.',
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.health_and_safety_outlined,
                  value:
                      result.diseaseRisk?.label.replaceFirst(
                        ' Clinical Risk',
                        '',
                      ) ??
                      '—',
                  label: 'Clinical Risk',
                  tooltip: 'Estimated clinical risk based on scan evidence.',
                  color: color,
                  compactValue: true,
                ),
              ),
            ],
          ),
          if (result.confidence != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Confidence',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(result.confidence! * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: result.confidence!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String tooltip;
  final Color color;
  final bool compactValue;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.tooltip,
    required this.color,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compactValue ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: tooltip,
                child: Icon(
                  Icons.info_outline,
                  size: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiseaseInfoButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enabled;

  const _DiseaseInfoButton({required this.onPressed, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.info_outline),
      label: const Align(
        alignment: Alignment.centerLeft,
        child: Text('View disease information'),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: enabled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final TriageResult result;
  final bool expanded;
  final VoidCallback onToggle;

  const _DetailsSection({
    required this.result,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(result.urgency);

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 19, color: color),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'View details',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _DetailBlock(
                          icon: Icons.psychology_outlined,
                          title: 'Reasoning',
                          child: Text(
                            result.reasoning,
                            style: TextStyle(
                              height: 1.45,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DetailBlock(
                          icon: Icons.analytics_outlined,
                          title: 'Evidence analysis',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _EvidenceChip(
                                    label: result.confidence == null
                                        ? 'Confidence —'
                                        : '${(result.confidence! * 100).toStringAsFixed(0)}% confidence',
                                    color: color,
                                  ),
                                  _EvidenceChip(
                                    label: result.evidenceStrength.label,
                                    color: color,
                                  ),
                                ],
                              ),
                              if (result.selectedSymptoms.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Selected symptoms',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: result.selectedSymptoms
                                      .map(
                                        (symptom) => Chip(
                                          label: Text(symptom),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (result.isLowQuality) ...[
                          const SizedBox(height: 16),
                          Text(
                            'The image quality was low, so this result should be interpreted cautiously.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailBlock({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: scheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final Color color;

  const _Disclaimer({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'AI-assisted triage tool. Always consult a licensed veterinarian for diagnosis.',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontStyle: FontStyle.italic,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onBack;
  final Future<void> Function() onExport;
  final bool exporting;

  const _BottomActions({
    required this.onBack,
    required this.onExport,
    required this.exporting,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: exporting ? null : onExport,
                icon: exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(exporting ? 'Saving…' : 'Export PDF'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFFB99AFB),
                  foregroundColor: const Color(0xFF24133F),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final UrgencyLevel urgency;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.urgency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Pill(icon: icon, label: urgency.label, color: color);
  }
}

class _StatusIcon extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _StatusIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color:
            color?.withValues(alpha: 0.18) ??
            Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final ScanComparisonTrend trend;
  final String? summary;

  const _TrendChip({required this.trend, required this.summary});

  @override
  Widget build(BuildContext context) {
    final color = trend == ScanComparisonTrend.worsened
        ? _statusColor(UrgencyLevel.high)
        : trend == ScanComparisonTrend.improved
        ? _statusColor(UrgencyLevel.stable)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final arrow = trend == ScanComparisonTrend.worsened ? '↓' : '↑';
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$arrow ${summary ?? trend.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  final String label;
  final Color color;

  const _EvidenceChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Color _statusColor(UrgencyLevel urgency) => switch (urgency) {
  UrgencyLevel.stable => const Color(0xFF3FA85C),
  UrgencyLevel.moderate => const Color(0xFFF2A93B),
  UrgencyLevel.high => const Color(0xFFE0402C),
};

IconData _statusIcon(UrgencyLevel urgency) => switch (urgency) {
  UrgencyLevel.stable => Icons.verified_rounded,
  UrgencyLevel.moderate => Icons.assignment_late_rounded,
  UrgencyLevel.high => Icons.warning_rounded,
};
