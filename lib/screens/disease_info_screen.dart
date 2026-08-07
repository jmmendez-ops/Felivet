import 'package:flutter/material.dart';

import '../core/app_state.dart';

class DiseaseInfoScreen extends StatelessWidget {
  final String diseaseName;

  const DiseaseInfoScreen({super.key, required this.diseaseName});

  static const Map<String, _DiseaseInfo> _infoByDisease = {
    'Scabies': _DiseaseInfo(
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
    'ringworms': _DiseaseInfo(
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
    'Flee Allergy': _DiseaseInfo(
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
        final info = _infoByDisease[diseaseName] ?? _infoByDisease['Scabies']!;
        final color = Colors.deepPurple;

        return Scaffold(
          appBar: AppBar(
            title: Text(diseaseName),
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [Colors.black12, const Color(0xFF121212)]
                    : [color.withValues(alpha: 0.16), Colors.white],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.medical_information_outlined,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  diseaseName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            info.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    _buildSection(
                      'Common symptoms',
                      Icons.healing_outlined,
                      info.symptoms,
                      color,
                      isDark,
                    ),
                    _buildSection(
                      'Likely causes',
                      Icons.psychology_outlined,
                      info.causes,
                      color,
                      isDark,
                    ),
                    _buildSection(
                      'Contagious status',
                      Icons.warning_amber_rounded,
                      [info.contagiousStatus],
                      color,
                      isDark,
                    ),
                    _buildSection(
                      'Home care',
                      Icons.home_repair_service_outlined,
                      info.homeCare,
                      color,
                      isDark,
                    ),
                    _buildSection(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    String title,
    IconData icon,
    List<String> items,
    Color color,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fiber_manual_record, size: 9, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: isDark ? Colors.grey.shade200 : Colors.black87,
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
