import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_state.dart';
import '../core/sound_utils.dart';
import '../core/ui_tokens.dart';
import '../models/triage_models.dart';
import '../services/pdf_report_service.dart';
import 'disease_info_screen.dart';

class ResultScreen extends StatelessWidget {
  final TriageResult result;
  final List<TriageResult> history;
  final Future<void> Function(TriageResult entry)? onDeleteHistoryEntry;
  final Future<void> Function()? onClearHistory;

  const ResultScreen({
    super.key,
    required this.result,
    required this.history,
    this.onDeleteHistoryEntry,
    this.onClearHistory,
  });

  void _showPhotoPopup(BuildContext context, File image) {
    AppSounds.playTap();
    showDialog(
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

  Color _urgencyColor(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.high:
        return const Color(0xFFE0402C);
      case UrgencyLevel.moderate:
        return const Color(0xFFF2A93B);
      case UrgencyLevel.stable:
        return const Color(0xFF3FA85C);
    }
  }

  IconData _urgencyIcon(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.high:
        return Icons.warning_rounded;
      case UrgencyLevel.moderate:
        return Icons.assignment_late_rounded;
      case UrgencyLevel.stable:
        return Icons.verified_rounded;
    }
  }

  String _headerLabel() => result.detectedDisease != null
      ? result.detectedDisease!.toUpperCase()
      : 'No detected disease';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final color = _urgencyColor(result.urgency);
        final icon = _urgencyIcon(result.urgency);

        return Scaffold(
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            backgroundColor: color,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Detection',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: 'Analyze again',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).scaffoldBackgroundColor,
                      ]
                    : [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceXl,
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.isLowQuality)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          bottom: FeliVetUi.spaceMd,
                        ),
                        padding: const EdgeInsets.all(FeliVetUi.spaceMd),
                        decoration: FeliVetUi.cardDecoration(context),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: FeliVetUi.spaceSm),
                            Expanded(
                              child: Text(
                                'This scan used a lower-quality photo. Results may be less reliable — consider retaking the image for a clearer analysis.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                          width: double.infinity,
                          padding: FeliVetUi.cardPadding,
                          decoration: FeliVetUi.cardDecoration(
                            context,
                            elevated: true,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  FeliVetUi.spaceSm,
                                ),
                                decoration: FeliVetUi.iconBadge(
                                  context,
                                  color: color,
                                ),
                                child: Icon(icon, color: color, size: 26),
                              ),
                              const SizedBox(width: FeliVetUi.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Skin Disease Detected:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: FeliVetUi.spaceSm),
                                    Text(
                                      _headerLabel(),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    if (result.detectedDisease != null &&
                                        result.detectedDisease!.toLowerCase() ==
                                            'ringworm') ...[
                                      const SizedBox(height: FeliVetUi.spaceSm),
                                      Text(
                                        'Ringworm is a contagious fungal infection. Keep your cat isolated and consult your veterinarian for treatment.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .slideY(
                          begin: 0.3,
                          end: 0.0,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(duration: const Duration(milliseconds: 400)),
                    const SizedBox(height: FeliVetUi.spaceMd),
                    if (result.image != null)
                      GestureDetector(
                        onTap: () => _showPhotoPopup(context, result.image!),
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          margin: const EdgeInsets.only(
                            bottom: FeliVetUi.spaceMd,
                          ),
                          decoration: FeliVetUi.cardDecoration(
                            context,
                            elevated: true,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  FeliVetUi.cardRadius,
                                ),
                                child: Image.file(
                                  result.image!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 900,
                                  filterQuality: FilterQuality.low,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Theme.of(context).cardColor,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: FeliVetUi.spaceMd,
                                    vertical: FeliVetUi.spaceSm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to enlarge',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: FeliVetUi.cardPadding,
                      decoration: FeliVetUi.cardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Detection Result',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: FeliVetUi.spaceSm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: FeliVetUi.spaceMd,
                                  vertical: FeliVetUi.spaceXs,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'RESULT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: FeliVetUi.spaceSm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  FeliVetUi.spaceSm,
                                ),
                                decoration: FeliVetUi.iconBadge(
                                  context,
                                  color: color,
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: FeliVetUi.spaceMd),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Triage Analyzation:',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' ${result.urgency.label}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: FeliVetUi.spaceLg),
                          if (result.comparisonTrend != null &&
                              result.comparisonSummary != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(FeliVetUi.spaceMd),
                              margin: const EdgeInsets.only(
                                bottom: FeliVetUi.spaceMd,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: isDark ? 0.16 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.compare_arrows_rounded,
                                    color: color,
                                    size: 18,
                                  ),
                                  const SizedBox(width: FeliVetUi.spaceSm),
                                  Expanded(
                                    child: Text(
                                      '${result.comparisonTrend!.label} · ${result.comparisonSummary}',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: FeliVetUi.spaceLg),
                          if (result.urgency == UrgencyLevel.high) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(FeliVetUi.spaceMd),
                              margin: const EdgeInsets.only(
                                bottom: FeliVetUi.spaceMd,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2B1112)
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFFB23A3A)
                                      : Colors.red.shade300,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.emergency_outlined,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                  const SizedBox(width: FeliVetUi.spaceSm),
                                  Expanded(
                                    child: Text(
                                      'Emergency advice: If your cat is struggling to breathe, collapsing, refusing water, or appears much worse than usual, seek urgent veterinary help now.',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFFFE5E5)
                                            : Colors.red.shade900,
                                        fontSize: 12.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (result.detectedDisease != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: FeliVetUi.spaceMd,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DiseaseInfoScreen(
                                      diseaseName: result.detectedDisease!,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.info_outline),
                                label: const Text('View disease information'),
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            padding: FeliVetUi.cardPadding,
                            decoration: FeliVetUi.cardDecoration(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.analytics_outlined,
                                      size: 15,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: FeliVetUi.spaceSm),
                                    Expanded(
                                      child: Text(
                                        'Evidence Analysis',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: FeliVetUi.spaceSm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: FeliVetUi.spaceSm,
                                        vertical: FeliVetUi.spaceXs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        result.evidenceStrength.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FeliVetUi.spaceMd),
                                Wrap(
                                  spacing: FeliVetUi.spaceSm,
                                  runSpacing: FeliVetUi.spaceSm,
                                  children: [
                                    _buildInfoPill(
                                      icon: Icons.insights_rounded,
                                      label: result.confidence != null
                                          ? '${(result.confidence! * 100).toStringAsFixed(0)}% confidence'
                                          : 'Confidence pending',
                                      color: color,
                                      isDark: isDark,
                                    ),
                                    _buildInfoPill(
                                      icon: Icons.checklist_rtl_rounded,
                                      label:
                                          '${result.symptomCount} symptom${result.symptomCount == 1 ? '' : 's'} selected',
                                      color: color,
                                      isDark: isDark,
                                    ),
                                    _buildInfoPill(
                                      icon: Icons.health_and_safety_outlined,
                                      label:
                                          result.diseaseRisk?.label ??
                                          'Clinical risk pending',
                                      color: color,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FeliVetUi.spaceMd),
                                if (result.confidence != null) ...[
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: FeliVetUi.spaceSm,
                                    runSpacing: FeliVetUi.spaceXs / 2,
                                    children: [
                                      Text(
                                        'Model Confidence',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        "${(result.confidence! * 100).toStringAsFixed(0)}%"
                                        "${result.confidenceLevel != null ? ' · ${result.confidenceLevel!.label}' : ''}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: FeliVetUi.spaceSm),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: result.confidence,
                                      minHeight: 8,
                                      backgroundColor: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: FeliVetUi.spaceXs),
                                  Text(
                                    'Confidence reflects how sure the AI is about this prediction — not how severe the condition is.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: FeliVetUi.spaceMd),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: 'Detected Areas',
                                        value: '${result.detectionCount}',
                                        icon: Icons.grain_rounded,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: FeliVetUi.spaceMd),
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: 'Symptoms',
                                        value: '${result.symptomCount}',
                                        icon: Icons.checklist_rtl_rounded,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FeliVetUi.spaceSm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: 'Presence',
                                        value: result.presenceStatus.label,
                                        icon: Icons.fact_check_outlined,
                                        color: color,
                                        small: true,
                                      ),
                                    ),
                                    const SizedBox(width: FeliVetUi.spaceMd),
                                    Expanded(
                                      child: _statTile(
                                        context: context,
                                        isDark: isDark,
                                        label: 'Clinical Risk',
                                        value:
                                            result.diseaseRisk?.label ?? 'N/A',
                                        icon: Icons.health_and_safety_outlined,
                                        color: color,
                                        small: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (result.isAmbiguous) ...[
                                  const SizedBox(height: FeliVetUi.spaceMd),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.help_outline_rounded,
                                        size: 14,
                                        color: color,
                                      ),
                                      const SizedBox(width: FeliVetUi.spaceSm),
                                      Expanded(
                                        child: Text(
                                          'Classification is ambiguous between candidate conditions.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: FeliVetUi.spaceMd),
                          Container(
                            width: double.infinity,
                            padding: FeliVetUi.cardPadding,
                            decoration: FeliVetUi.cardDecoration(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.psychology_outlined,
                                      size: 15,
                                      color: color,
                                    ),
                                    const SizedBox(width: FeliVetUi.spaceSm),
                                    Text(
                                      'Expert System Reasoning',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FeliVetUi.spaceSm),
                                Text(
                                  result.reasoning,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: isDark
                                        ? Colors.grey.shade100
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: FeliVetUi.spaceMd),
                                Container(
                                  padding: const EdgeInsets.all(
                                    FeliVetUi.spaceMd,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: isDark ? 0.15 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    result.recommendation,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: FeliVetUi.spaceMd),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 13,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: FeliVetUi.spaceSm),
                              Expanded(
                                child: Text(
                                  'This is an AI-assisted triage tool. Always consult a licensed veterinarian for diagnosis.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: FeliVetUi.spaceXl),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: FeliVetUi.spaceMd,
                              ),
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back, size: 18),
                            label: Text(
                              'Back',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: FeliVetUi.spaceMd),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              try {
                                final file =
                                    await PdfReportService.generateScanReport(
                                      result,
                                    );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Report saved to ${file.path}',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to create PDF report: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text(
                              'Export PDF',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FeliVetUi.spaceMd,
        vertical: FeliVetUi.spaceSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: FeliVetUi.spaceSm),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: FeliVetUi.spaceSm,
        horizontal: FeliVetUi.spaceSm,
      ),
      decoration: FeliVetUi.cardDecoration(context),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: FeliVetUi.spaceSm),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: small ? 11.5 : 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: FeliVetUi.spaceXs / 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
