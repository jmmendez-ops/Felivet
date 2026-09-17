import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/ui_tokens.dart';

class DiseaseInfoScreen extends StatelessWidget {
  final String diseaseName;

  const DiseaseInfoScreen({super.key, required this.diseaseName});

  static const Map<String, _DiseaseInfo> _infoByDisease = {
    'scabies': _DiseaseInfo(
      description:
          'Scabies is a highly contagious skin infestation caused by mites. It often leads to intense itching, crusting, and hair loss.',
      symptoms: [
        'Intense itching, especially at night',
        'Red, irritated skin',
        'Small crusts or scabs',
        'Hair loss around the affected area',
      ],
      causes: [
        'Sarcoptic mites burrowing into the skin',
        'Close contact with an infested animal or contaminated bedding',
      ],
      contagiousStatus: 'Highly contagious to other cats and animals.',
      homeCare: [
        'Isolate the affected cat from other pets until a vet checks it.',
        'Wash bedding and grooming tools thoroughly.',
        'Keep the skin clean and avoid scratching the area.',
      ],
      veterinaryAdvice: [
        'A veterinarian can confirm scabies and prescribe treatment.',
        'Other pets in the household should also be checked.',
      ],
    ),
    'ringworm': _DiseaseInfo(
      description:
          'Ringworm is a fungal infection that can affect the skin, hair, and nails. It often appears as circular patches with hair loss.',
      symptoms: [
        'Circular bald patches',
        'Red, flaky, or crusted skin',
        'Broken hairs around the lesion',
      ],
      causes: [
        'Fungal spores spread by direct contact or contaminated surfaces',
        'Stress, overcrowding, or poor immune function can increase risk',
      ],
      contagiousStatus: 'Contagious to other animals and sometimes to people.',
      homeCare: [
        'Clean shared surfaces and bedding regularly.',
        'Prevent scratching and biting the area.',
        'Keep the cat comfortable while awaiting veterinary care.',
      ],
      veterinaryAdvice: [
        'Treatment usually requires veterinary-prescribed antifungal medication.',
        'Follow-up checks help ensure the infection clears fully.',
      ],
    ),
    'flea allergy': _DiseaseInfo(
      description:
          'Flea allergy is an overreaction to flea saliva. Even a few fleas can trigger severe itching and skin irritation.',
      symptoms: [
        'Severe scratching or chewing',
        'Red, inflamed skin',
        'Small scabs or sores',
        'Hair loss from over-grooming',
      ],
      causes: [
        'Allergic reaction to flea bites',
        'Fleas living in the coat or environment',
      ],
      contagiousStatus:
          'Not contagious between pets, but fleas spread easily in the environment.',
      homeCare: [
        'Treat the environment and bedding for fleas.',
        'Use gentle grooming and keep the coat clean.',
        'Prevent further scratching to avoid skin damage.',
      ],
      veterinaryAdvice: [
        'A vet can recommend flea control and anti-itch treatment.',
        'A full household flea plan is often needed.',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final normalizedDisease = diseaseName.toLowerCase();
        final info =
            _infoByDisease[normalizedDisease] ?? _infoByDisease['scabies']!;
        final color = Theme.of(context).colorScheme.primary;

        return Scaffold(
          appBar: AppBar(title: Text(diseaseName)),
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
                        color.withValues(alpha: 0.08),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: FeliVetUi.cardPadding,
                      decoration: FeliVetUi.cardDecoration(
                        context,
                        elevated: true,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  FeliVetUi.spaceSm,
                                ),
                                decoration: FeliVetUi.iconBadge(
                                  context,
                                  color: color,
                                ),
                                child: Icon(
                                  Icons.medical_information_outlined,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: FeliVetUi.spaceMd),
                              Expanded(
                                child: Text(
                                  diseaseName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: FeliVetUi.spaceMd),
                          Text(
                            info.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: FeliVetUi.spaceMd),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildBadge('Veterinary care', color, isDark),
                              _buildBadge('Contagion info', color, isDark),
                              _buildBadge('Home care', color, isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: FeliVetUi.spaceMd),
                    _buildSection(
                      context,
                      'Common symptoms',
                      Icons.healing_outlined,
                      info.symptoms,
                      color,
                      isDark,
                    ),
                    _buildSection(
                      context,
                      'Likely causes',
                      Icons.psychology_outlined,
                      info.causes,
                      color,
                      isDark,
                    ),
                    _buildSection(
                      context,
                      'Contagious status',
                      Icons.warning_amber_rounded,
                      [info.contagiousStatus],
                      color,
                      isDark,
                    ),
                    _buildSection(
                      context,
                      'Home care',
                      Icons.home_repair_service_outlined,
                      info.homeCare,
                      color,
                      isDark,
                    ),
                    _buildSection(
                      context,
                      'Veterinary advice',
                      Icons.local_hospital_outlined,
                      info.veterinaryAdvice,
                      color,
                      isDark,
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

  Widget _buildBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FeliVetUi.spaceMd,
        vertical: FeliVetUi.spaceSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
    Color color,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: FeliVetUi.spaceMd),
      padding: FeliVetUi.cardPadding,
      decoration: FeliVetUi.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(FeliVetUi.spaceXs),
                decoration: FeliVetUi.iconBadge(context, color: color),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: FeliVetUi.spaceSm),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: FeliVetUi.spaceSm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: FeliVetUi.spaceSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fiber_manual_record, size: 9, color: color),
                  const SizedBox(width: FeliVetUi.spaceSm),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseInfo {
  final String description;
  final List<String> symptoms;
  final List<String> causes;
  final String contagiousStatus;
  final List<String> homeCare;
  final List<String> veterinaryAdvice;

  const _DiseaseInfo({
    required this.description,
    required this.symptoms,
    required this.causes,
    required this.contagiousStatus,
    required this.homeCare,
    required this.veterinaryAdvice,
  });
}
