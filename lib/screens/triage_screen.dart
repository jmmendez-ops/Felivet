import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/detection_config.dart';
import '../core/app_state.dart';
import '../core/sound_utils.dart';
import '../core/ui_tokens.dart';
import '../models/cat_profile.dart';
import '../models/triage_models.dart';
import '../services/cat_profile_storage.dart';
import '../services/history_storage.dart';
import '../services/symptom_intake_service.dart';
import '../services/triage_engine.dart';
import '../services/pdf_report_service.dart';
import 'history_screen.dart';
import 'result_screen.dart';
import 'triage_submission_validator.dart';

class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

List<FlSpot> buildTrendSpots(List<TriageResult> history) {
  if (history.length < 2) return [];

  final ordered = history.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final normalized = ordered.map((entry) {
    final value = switch (entry.urgency) {
      UrgencyLevel.high => 3.0,
      UrgencyLevel.moderate => 2.0,
      UrgencyLevel.stable => 1.0,
    };
    return value;
  }).toList();

  final maxValue = normalized.reduce((a, b) => a > b ? a : b);
  final minValue = normalized.reduce((a, b) => a < b ? a : b);
  final range = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;

  return List.generate(ordered.length, (index) {
    final value = normalized[index];
    final adjusted = 1.0 + ((value - minValue) / range) * 2.0;
    return FlSpot(index.toDouble(), adjusted);
  });
}

class _TriageScreenState extends State<TriageScreen> {
  File? _image;
  bool _hideLatestImage = false;
  final ImagePicker _picker = ImagePicker();

  FlutterVision? _vision;
  bool _isModelLoaded = false;
  bool _isScanning = false;
  String? _loadError;

  bool _isVomiting = false;
  bool _isLethargic = false;
  bool _lostAppetite = false;

  List<TriageResult> _history = [];
  final Map<String, bool> _pdfAvailability = {};
  List<CatProfile> _profiles = [];
  CatProfile? _activeProfile;
  int _selectedIndex = 0;
  String? _imageQualityMessage;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadProfiles();
    _loadHistory();
  }

  Future<void> _loadProfiles() async {
    final profiles = await CatProfileStorage.ensureDefaultProfile();
    final activeId = await CatProfileStorage.loadActiveCatId();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfile = profiles.cast<CatProfile?>().firstWhere(
        (profile) => profile?.id == activeId,
        orElse: () => profiles.first,
      );
      _hideLatestImage = false;
      _image = _latestActiveImage;
    });
  }

  Future<void> _loadHistory() async {
    final saved = await HistoryStorage.load();
    if (!mounted) return;
    if (mounted) {
      setState(() {
        _history = saved;
      });
      _refreshPdfAvailability(saved);
    }
    // Debug: log loaded history count so devs can verify persistence
    // This will appear in device logs when running in debug mode.
    // Keep as a plain print to avoid introducing UI side-effects.
    print('TriageScreen: loaded history with ${saved.length} entries');
  }

  Future<List<TriageResult>> _persistHistory() async {
    return HistoryStorage.save(_history);
  }

  List<TriageResult> get _activeCatHistory {
    if (_activeProfile == null) return _history;
    return _history
        .where(
          (entry) => entry.catId == null || entry.catId == _activeProfile!.id,
        )
        .toList();
  }

  File? get _latestActiveImage {
    final activeHistory = _activeCatHistory;
    return activeHistory.isEmpty ? null : activeHistory.first.image;
  }

  File? get _previewImage =>
      _hideLatestImage ? null : (_image ?? _latestActiveImage);

  String _pdfKey(TriageResult result) => result.timestamp.toIso8601String();

  Future<void> _refreshPdfAvailability(List<TriageResult> results) async {
    final availability = <String, bool>{};
    for (final result in results) {
      final file = await PdfReportService.reportFileFor(result);
      availability[_pdfKey(result)] = await file.exists();
    }
    if (mounted) setState(() => _pdfAvailability.addAll(availability));
  }

  Future<void> _changeActiveProfile(CatProfile profile) async {
    await CatProfileStorage.saveActiveCatId(profile.id);
    if (!mounted) return;
    setState(() {
      _activeProfile = profile;
      _hideLatestImage = false;
      _image = _latestActiveImage;
    });
  }

  Future<void> _showAddCatDialog({bool fromSettings = false}) async {
    final nameController = TextEditingController();
    final breedController = TextEditingController();
    File? selectedPhoto;
    final picker = ImagePicker();

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add cat profile'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedPhoto != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            selectedPhoto!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (pickedFile != null) {
                                  final adjustedPhoto =
                                      await _adjustProfilePhoto(
                                        File(pickedFile.path),
                                      );
                                  if (adjustedPhoto == null) return;
                                  setDialogState(() {
                                    selectedPhoto = adjustedPhoto;
                                  });
                                }
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Add photo'),
                            ),
                          ),
                          if (selectedPhoto != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() => selectedPhoto = null);
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Cat name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: breedController,
                        decoration: const InputDecoration(
                          labelText: 'Breed (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      Navigator.pop(dialogContext);
                      return;
                    }
                    Navigator.pop(dialogContext, {
                      'name': name,
                      'breed': breedController.text.trim().isEmpty
                          ? null
                          : breedController.text.trim(),
                      'photoPath': selectedPhoto?.path,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final profile = CatProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: result['name'] ?? 'My Cat',
      breed: result['breed'],
      photoPath: result['photoPath'],
    );
    final updatedProfiles = [..._profiles, profile];
    await CatProfileStorage.saveProfiles(updatedProfiles);
    await _changeActiveProfile(profile);
    if (!mounted) return;
    setState(() => _profiles = updatedProfiles);
    if (fromSettings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.name} added to your profiles.')),
      );
    }
  }

  Future<void> _removeProfile(
    CatProfile profile, {
    bool fromSettings = false,
  }) async {
    if (_profiles.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one cat profile.')),
      );
      return;
    }

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove cat profile?'),
        content: Text('Remove ${profile.name} from your profiles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;

    final updatedProfiles = _profiles
        .where((item) => item.id != profile.id)
        .toList();
    CatProfile? nextActiveProfile;
    if (_activeProfile?.id == profile.id) {
      nextActiveProfile = updatedProfiles.isEmpty
          ? null
          : updatedProfiles.first;
    } else {
      nextActiveProfile = _activeProfile;
    }

    await CatProfileStorage.saveProfiles(updatedProfiles);
    await CatProfileStorage.saveActiveCatId(nextActiveProfile?.id);

    if (!mounted) return;
    setState(() {
      _profiles = updatedProfiles;
      _activeProfile = nextActiveProfile;
    });

    if (fromSettings) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${profile.name} removed.')));
    }
  }

  Future<File?> _adjustProfilePhoto(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null || !mounted) return source;
    var zoom = 1.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust profile photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: ColoredBox(
                    color: Colors.black12,
                    child: Transform.scale(
                      scale: zoom,
                      child: Image.file(
                        source,
                        fit: BoxFit.cover,
                        width: 190,
                        height: 190,
                        cacheWidth: 380,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.zoom_out, size: 18),
                  Expanded(
                    child: Slider(
                      value: zoom,
                      min: 1,
                      max: 3,
                      divisions: 20,
                      label: '${zoom.toStringAsFixed(1)}x',
                      onChanged: (value) => setDialogState(() => zoom = value),
                    ),
                  ),
                  const Icon(Icons.zoom_in, size: 18),
                ],
              ),
              Text(
                'Use the slider to fit the cat inside the circle.',
                style: FeliVetUi.muted(context, size: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use photo'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return null;

    final cropSize =
        (decoded.width < decoded.height ? decoded.width : decoded.height) /
        zoom;
    final cropped = img.copyCrop(
      decoded,
      x: ((decoded.width - cropSize) / 2).round(),
      y: ((decoded.height - cropSize) / 2).round(),
      width: cropSize.round(),
      height: cropSize.round(),
    );
    final directory = await getApplicationDocumentsDirectory();
    final output = File(
      '${directory.path}/cat_profile_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await output.writeAsBytes(img.encodeJpg(cropped, quality: 88));
    return output;
  }

  Widget _buildCatAvatar(CatProfile profile, {double radius = 10}) {
    final photoPath = profile.photoPath;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.deepPurple.shade100,
      child: photoPath == null
          ? Text(
              profile.name.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: radius, color: Colors.deepPurple),
            )
          : ClipOval(
              child: Image.file(
                File(photoPath),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                cacheWidth: (radius * 4).round(),
                errorBuilder: (_, _, _) => Text(
                  profile.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: radius, color: Colors.deepPurple),
                ),
              ),
            ),
    );
  }

  Future<void> _deleteHistoryEntry(TriageResult entry) async {
    setState(() => _history.remove(entry));
    await HistoryStorage.deleteEntry(entry);
    await _persistHistory();
  }

  Future<void> _clearHistory() async {
    setState(() {
      _history = [];
      _image = null;
    });
    await HistoryStorage.clear();
  }

  Future<void> _loadModel() async {
    try {
      _vision ??= FlutterVision();
      await _vision!.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/best.tflite',
        modelVersion: 'yolov11',
        coordinateFormat: 'normalized',
        numThreads: 2,
        useGpu: false,
      );
      if (mounted) setState(() => _isModelLoaded = true);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load model: $e');
    }
  }

  @override
  void dispose() {
    _vision?.closeYoloModel();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final shouldContinue = await _showCameraTips();
      if (!shouldContinue) return;
    }

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final newImage = File(pickedFile.path);
      setState(() {
        _image = newImage;
        _hideLatestImage = false;
        _imageQualityMessage = null;
      });
      await _assessImageQuality(newImage);
    }
  }

  Future<bool> _showCameraTips() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Camera tips'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For the best scan result, try to:'),
            SizedBox(height: 8),
            Text('• Keep the affected area in focus and close to the camera.'),
            Text('• Use bright, even lighting and avoid strong shadows.'),
            Text('• Capture the area clearly without motion blur.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return shouldContinue ?? false;
  }

  Future<({String? message, bool isLowQuality})> _assessImageQuality(
    File imageFile,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (mounted) setState(() => _imageQualityMessage = null);
        return (message: null, isLowQuality: false);
      }

      final gray = img.grayscale(decoded);
      final sharpnessScore = _estimateBlur(gray);
      final brightness = _estimateBrightness(gray);
      final issues = <String>[];
      if (sharpnessScore < 0.08) issues.add('blurry');
      if (brightness < 0.22) issues.add('too dark');

      final bool isLowQuality = issues.isNotEmpty;
      final message = !isLowQuality
          ? null
          : issues.length == 2
          ? 'The photo looks blurry and too dark. Try a brighter, steadier shot for better results.'
          : issues.first == 'blurry'
          ? 'The photo looks blurry. A clearer image may improve the analysis.'
          : 'The photo looks too dark. Brighter lighting may improve the analysis.';

      if (mounted) setState(() => _imageQualityMessage = message);
      return (message: message, isLowQuality: isLowQuality);
    } catch (_) {
      if (mounted) setState(() => _imageQualityMessage = null);
      return (message: null, isLowQuality: false);
    }
  }

  Future<bool> _confirmImageQualityBeforeAnalysis() async {
    if (_image == null) return true;

    final quality = await _assessImageQuality(_image!);
    if (!quality.isLowQuality) return true;

    final shouldUseAnyway = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Image quality check'),
        content: Text(
          quality.message ??
              'The selected photo may be too blurry or too dark for a reliable result.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Retake'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Use anyway'),
          ),
        ],
      ),
    );

    return shouldUseAnyway ?? false;
  }

  double _estimateBlur(img.Image image) {
    final width = image.width;
    final height = image.height;
    if (width < 3 || height < 3) return 0.0;

    final sample = img.copyResize(
      image,
      width: width ~/ 2,
      height: height ~/ 2,
    );
    double total = 0.0;
    for (int y = 0; y < sample.height - 1; y++) {
      for (int x = 0; x < sample.width - 1; x++) {
        final current = sample.getPixel(x, y);
        final next = sample.getPixel(x + 1, y + 1);
        total += (current.r.toDouble() - next.r.toDouble()).abs();
      }
    }
    return (total / ((sample.width * sample.height) + 1)).clamp(0.0, 1.0);
  }

  double _estimateBrightness(img.Image image) {
    double total = 0.0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        total += pixel.r.toDouble() / 255.0;
      }
    }
    return total / (image.width * image.height);
  }

  int get _symptomCount =>
      [_isVomiting, _isLethargic, _lostAppetite].where((s) => s).length;

  Future<void> _runInference() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a photo before analyzing your cat.'),
        ),
      );
      return;
    }

    final validation = validateTriageSubmission(
      hasImage: _image != null,
      hasSymptoms: _symptomCount > 0,
    );

    if (!validation.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.message ?? 'Please upload a photo first.'),
        ),
      );
      return;
    }

    final qualityCheck = await _assessImageQuality(_image!);
    final shouldProceed =
        !qualityCheck.isLowQuality ||
        await _confirmImageQualityBeforeAnalysis();
    if (!shouldProceed || !mounted) return;

    setState(() => _isScanning = true);

    try {
      final intake = await SymptomIntakeService.extractChecklistFromText(
        userText: _buildIntakePrompt(),
        selectedSymptoms: _selectedSymptoms,
        turnCount: 1,
      );

      if (intake.redFlag) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Urgent vet care is recommended for this situation.'),
          ),
        );
        setState(() => _isScanning = false);
        return;
      }

      final List<DiseaseEvidence> evidenceList = [];
      if (_image != null && _isModelLoaded) {
        final Uint8List bytes = await _image!.readAsBytes();
        final imageInfo = await decodeImageFromList(bytes);

        final List<dynamic> rawResults = await _vision!.yoloOnImage(
          bytesList: bytes,
          imageHeight: imageInfo.height,
          imageWidth: imageInfo.width,
          iouThreshold: DetectionConfig.iouThreshold,
          confThreshold: DetectionConfig.minDetectionConfidence,
          classThreshold: DetectionConfig.minDetectionConfidence,
        );

        final Map<String, List<double>> confidencesPerDisease = {
          for (final disease in DetectionConfig.knownDiseases) disease: [],
        };

        for (final res in rawResults) {
          if (res is! Map) continue;
          final String tag = (res['tag'] ?? '').toString();
          if (!DetectionConfig.knownDiseases.contains(tag)) continue;

          final conf = extractConfidence(res);
          if (conf == null || conf < DetectionConfig.minDetectionConfidence) {
            continue;
          }
          confidencesPerDisease[tag]!.add(conf);
        }

        confidencesPerDisease.forEach((disease, confs) {
          if (confs.isEmpty) return;
          final best = confs.reduce((a, b) => a > b ? a : b);
          final avg = confs.reduce((a, b) => a + b) / confs.length;
          evidenceList.add(
            DiseaseEvidence(
              disease: disease,
              bestConfidence: best,
              avgConfidence: avg,
              detectionCount: confs.length,
            ),
          );
        });
      }

      final checklistFlags = SymptomIntakeService.checklistFlagsFromResult(
        intake,
      );
      final symptomCount = [
        checklistFlags['vomiting'] == true,
        checklistFlags['lethargy'] == true,
        checklistFlags['loss_of_appetite'] == true,
      ].where((value) => value).length;

      final result = runExpertSystem(
        evidenceList: evidenceList,
        symptomCount: symptomCount,
        image: _image,
        selectedSymptoms: _selectedSymptoms.toList()..sort(),
      );

      final activeHistoryForComparison = _activeCatHistory;
      final previous = activeHistoryForComparison.isNotEmpty
          ? activeHistoryForComparison.first
          : null;
      final comparisonTrend = previous != null
          ? result.compareToPrevious(previous)
          : ScanComparisonTrend.noChange;
      final comparisonSummary = previous == null
          ? 'This is your first scan. Keep monitoring for changes over time.'
          : switch (comparisonTrend) {
              ScanComparisonTrend.improved =>
                'Compared with your previous scan, this result looks improved.',
              ScanComparisonTrend.worsened =>
                'Compared with your previous scan, this result looks worse.',
              ScanComparisonTrend.noChange =>
                'Compared with your previous scan, there is no clear change.',
            };

      final resultWithIntake = result.copyWith(
        reasoning:
            result.reasoning +
            (intake.partialData
                ? '\n\nBased on limited information — consult a vet if symptoms persist or worsen.'
                : ''),
        catId: _activeProfile?.id,
        selectedSymptoms: _selectedSymptoms.toList()..sort(),
        comparisonTrend: comparisonTrend,
        comparisonSummary: comparisonSummary,
        isLowQuality: qualityCheck.isLowQuality && shouldProceed,
      );

      setState(() {
        _isScanning = false;
        _history.insert(0, resultWithIntake);
      });
      final persistedHistory = await _persistHistory();
      if (mounted) {
        setState(() {
          _history = persistedHistory;
          _image = persistedHistory.first.image;
        });
      }
      final persistedResult = persistedHistory.first;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: persistedResult,
            history: _history,
            onDeleteHistoryEntry: _deleteHistoryEntry,
            onClearHistory: _clearHistory,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isScanning = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error during scan: $e')));
    }
  }

  Set<String> get _selectedSymptoms {
    final selected = <String>{};
    if (_isVomiting) selected.add('vomiting');
    if (_isLethargic) selected.add('lethargy');
    if (_lostAppetite) selected.add('loss_of_appetite');
    return selected;
  }

  String _buildSymptomSummary() {
    final parts = <String>[];
    if (_isVomiting) parts.add('vomiting');
    if (_isLethargic) parts.add('lethargy');
    if (_lostAppetite) parts.add('loss_of_appetite');
    return parts.isEmpty ? 'No symptoms reported.' : parts.join(', ');
  }

  String _buildIntakePrompt() {
    final selectedSummary = _buildSymptomSummary();
    return selectedSummary == 'No symptoms reported.'
        ? ''
        : 'Selected symptom checklist: $selectedSummary';
  }

  String _getSymptomInsight() {
    if (_symptomCount == 0) return '';
    if (_symptomCount >= 2) {
      return 'Multiple symptoms suggest your cat is under stress. This could be related to a skin condition or to an unrelated internal issue — both should be evaluated by a vet.';
    } else if (_isVomiting) {
      return 'Vomiting can have many causes, including but not limited to skin-condition-related over-grooming. It should be evaluated on its own merits rather than assumed to be caused by a skin issue.';
    } else if (_isLethargic) {
      return 'Lethargy can stem from many causes. It should be evaluated independently rather than automatically attributed to a skin condition.';
    } else {
      return 'Loss of appetite can have many causes. It should be evaluated independently rather than automatically attributed to a skin condition.';
    }
  }

  Widget _buildSymptomOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool isDark,
  }) {
    final info = _symptomInfo[title.toLowerCase()] ?? _symptomInfo['default']!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: value
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF5F5F7))
            : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.shade300)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade200),
          width: value ? 2.0 : 1.0,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: value ? FontWeight.w700 : FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Why this matters',
                onPressed: () {
                  AppSounds.playTap();
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close insight',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      content: Text(
                        info,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          value: value,
          onChanged: onChanged,
          dense: true,
          horizontalTitleGap: 8,
          minLeadingWidth: 24,
          activeColor: isDark ? Colors.white70 : Colors.black87,
          checkColor: isDark ? Colors.black87 : Colors.white,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Map<String, String> get _symptomInfo => {
    'vomiting':
        'Vomiting can be linked to many causes, including digestive upset, infections, or stress. It should be evaluated carefully when paired with other symptoms.',
    'lethargy':
        'Lethargy means your cat seems unusually tired or weak. It can signal pain, illness, or an emergency if it is sudden or severe.',
    'loss_of_appetite':
        'Loss of appetite can be a sign of discomfort or illness. It matters more when your cat refuses food for a day or more.',
    'default':
        'This symptom can be important for overall health and may help the triage system assess urgency.',
  };

  Widget _buildQuickStats(bool isDark) {
    final activeHistory = _activeCatHistory;
    final latest = activeHistory.isNotEmpty ? activeHistory.first : null;
    final latestLabel = latest == null ? 'No scan yet' : latest.urgency.label;
    final urgencyColor = latest?.urgency.color ?? Colors.deepPurple;
    final tip = buildDailyCareTip(
      scanCount: activeHistory.length,
      latestUrgency: latest?.urgency,
    );
    final historyForTrend = activeHistory.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final trendSpots = buildTrendSpots(historyForTrend);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: FeliVetUi.cardDecoration(context, elevated: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latest Scan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      latestLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (latest != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        latest.urgency.label,
                        style: TextStyle(
                          color: urgencyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Scanned: ${latest.timestamp.day}/${latest.timestamp.month}/${latest.timestamp.year} ${latest.timestamp.hour.toString().padLeft(2, '0')}:${latest.timestamp.minute.toString().padLeft(2, '0')}',
                  style: FeliVetUi.muted(context, size: 12),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _statChip(
                    Icons.history_rounded,
                    '${activeHistory.length}',
                    'Total scans',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  if (latest != null)
                    _statChip(
                      Icons.verified_rounded,
                      latest.confidence != null
                          ? '${(latest.confidence! * 100).toStringAsFixed(0)}%'
                          : '—',
                      'Confidence',
                      isDark,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: FeliVetUi.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Trend',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tracks your cat\'s health score over time based on scan results. Higher scores indicate more urgency.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              if (trendSpots.length < 2)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    foregroundPainter: DashedBorderPainter(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 30,
                          color: FeliVetUi.mutedLight,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your scan trend will appear here after your first analysis',
                          textAlign: TextAlign.center,
                          style: FeliVetUi.muted(context),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 108,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawHorizontalLine: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.grey.shade300,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.round();
                                    if (index < 0 ||
                                        index >= historyForTrend.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final date =
                                        historyForTrend[index].timestamp;
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        '${date.month}/${date.day}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: trendSpots,
                                isCurved: true,
                                color: isDark
                                    ? Colors.deepPurple.shade300
                                    : Colors.deepPurple,
                                barWidth: 3,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                        final urgencyColor =
                                            historyForTrend[index]
                                                .urgency
                                                .color;
                                        return FlDotCirclePainter(
                                          radius: 4,
                                          color: urgencyColor,
                                          strokeWidth: 1.5,
                                          strokeColor: isDark
                                              ? Colors.white
                                              : Colors.black26,
                                        );
                                      },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color:
                                      (isDark
                                              ? Colors.deepPurple.shade300
                                              : Colors.deepPurple)
                                          .withValues(alpha: 0.16),
                                ),
                              ),
                            ],
                            minY: 0.8,
                            maxY: 3.2,
                            lineTouchData: LineTouchData(enabled: false),
                          ),
                        ),
                        ...List.generate(trendSpots.length, (index) {
                          final spot = trendSpots[index];
                          final horizontalRatio =
                              index / (trendSpots.length - 1);
                          final verticalRatio = 1 - ((spot.y - 0.8) / 2.4);
                          final score =
                              switch (historyForTrend[index].urgency) {
                                UrgencyLevel.high => 3,
                                UrgencyLevel.moderate => 2,
                                UrgencyLevel.stable => 1,
                              };
                          return Positioned(
                            left: (constraints.maxWidth - 18) * horizontalRatio,
                            top: (120 * verticalRatio).clamp(0.0, 100.0),
                            child: Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : Colors.deepPurple,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _trendLegendItem(
                    score: '1',
                    label: 'Stable',
                    color: UrgencyLevel.stable.color,
                    isDark: isDark,
                  ),
                  _trendLegendItem(
                    score: '2',
                    label: 'Moderate',
                    color: UrgencyLevel.moderate.color,
                    isDark: isDark,
                  ),
                  _trendLegendItem(
                    score: '3',
                    label: 'High',
                    color: UrgencyLevel.high.color,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade200 : Colors.black87,
                    height: 1.5,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendLegendItem({
    required String score,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$score $label',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    final bool hasSymptoms = _symptomCount > 0;
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_imageQualityMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_circle,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _imageQualityMessage!,
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_loadError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    '⚠️ $_loadError',
                    style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                  ),
                )
              else if (!_isModelLoaded)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading detection model…',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.05,
                      ),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _previewImage == null
                            ? SizedBox.expand(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pets,
                                      size: 60,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Upload a photo to begin',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(
                                _previewImage!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                cacheWidth: 900,
                                filterQuality: FilterQuality.low,
                              ),
                      ),
                    ),
                    if (_image != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.58),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Remove selected photo',
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              AppSounds.playTap();
                              setState(() {
                                _image = null;
                                _hideLatestImage = true;
                                _imageQualityMessage = null;
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildQuickStats(isDark),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.deepPurple,
                      ),
                      onPressed: () {
                        AppSounds.playTap();
                        _getImage(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(
                        'Camera',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.deepPurple,
                      ),
                      onPressed: () {
                        AppSounds.playTap();
                        _getImage(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text(
                        'Gallery',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Systemic Symptoms',
                style: FeliVetUi.heading(context, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                'Check any symptoms your cat is currently showing.',
                style: FeliVetUi.muted(context, size: 14).copyWith(height: 1.4),
              ),
              const SizedBox(height: 15),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    _symptomCount == 0
                        ? 'Select symptoms'
                        : '$_symptomCount symptom${_symptomCount == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Tap to choose from the symptom checklist',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  children: [
                    _buildSymptomOption(
                      title: 'Vomiting',
                      subtitle: 'Frequent throwing up or dry heaving',
                      value: _isVomiting,
                      onChanged: (v) => setState(() => _isVomiting = v!),
                      isDark: isDark,
                    ),
                    _buildSymptomOption(
                      title: 'Lethargy',
                      subtitle: 'Unusually tired, sleepy, or unresponsive',
                      value: _isLethargic,
                      onChanged: (v) => setState(() => _isLethargic = v!),
                      isDark: isDark,
                    ),
                    _buildSymptomOption(
                      title: 'Loss of Appetite',
                      subtitle: 'Ignoring food or eating very little',
                      value: _lostAppetite,
                      onChanged: (v) => setState(() => _lostAppetite = v!),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              if (hasSymptoms) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getSymptomInsight(),
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade200
                                : Colors.black87,
                            height: 1.5,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isScanning
                      ? null
                      : () {
                          AppSounds.playTap();
                          _runInference();
                        },
                  child: _isScanning
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'ANALYZE HEALTH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final screens = <Widget>[
          _buildDashboard(),
          HistoryScreen(
            history: _activeCatHistory,
            onDelete: _deleteHistoryEntry,
            onClearAll: _clearHistory,
            onRefresh: _loadHistory,
          ),
          _buildPersonalization(),
        ];

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 52,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 23),
                const SizedBox(width: 7),
                const Text(
                  'FeliVet Insight',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 7),
                InkWell(
                  onTap: () async {
                    final profiles = [..._profiles];
                    if (profiles.isEmpty) {
                      await _showAddCatDialog();
                      return;
                    }
                    await showModalBottomSheet<void>(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (sheetContext) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Select cat',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(sheetContext);
                                        await _showAddCatDialog();
                                      },
                                      child: const Text('Add cat'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: profiles.length,
                                    itemBuilder: (context, index) {
                                      final profile = profiles[index];
                                      final isActive =
                                          profile.id ==
                                          (_activeProfile?.id ?? '');
                                      return ListTile(
                                        leading: _buildCatAvatar(
                                          profile,
                                          radius: 20,
                                        ),
                                        title: Text(profile.name),
                                        subtitle: profile.breed != null
                                            ? Text(profile.breed!)
                                            : null,
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isActive)
                                              const Icon(Icons.check)
                                            else
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () async {
                                                  Navigator.pop(sheetContext);
                                                  await _removeProfile(profile);
                                                },
                                              ),
                                          ],
                                        ),
                                        onTap: () async {
                                          Navigator.pop(sheetContext);
                                          await _changeActiveProfile(profile);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _activeProfile == null
                            ? const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: Text(
                                  'M',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              )
                            : _buildCatAvatar(_activeProfile!, radius: 10),
                        const SizedBox(width: 6),
                        Text(
                          _activeProfile?.name ?? 'My Cat',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          body: IndexedStack(index: _selectedIndex, children: screens),
          bottomNavigationBar: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.deepPurple.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.65),
                  border: Border.all(
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  indicatorColor: Colors.deepPurple.shade100,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: 'Settings',
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

  Widget _buildPersonalization() {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final reportHistory = _activeCatHistory;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _showAddCatDialog(fromSettings: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.deepPurple.withValues(
                        alpha: isDark ? 0.25 : 0.16,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.05,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pets_outlined,
                        color: Colors.deepPurple,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add cat profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_profiles.isNotEmpty) ...[
                Text(
                  'Your cats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ..._profiles.map((profile) {
                  final isActive = profile.id == (_activeProfile?.id ?? '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF232323) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(
                            alpha: isDark ? 0.2 : 0.14,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: _buildCatAvatar(profile, radius: 20),
                        title: Text(profile.name),
                        subtitle: profile.breed != null
                            ? Text(profile.breed!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              Icon(Icons.check_circle, color: Colors.deepPurple)
                            else
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _removeProfile(profile, fromSettings: true),
                              ),
                          ],
                        ),
                        onTap: isActive
                            ? null
                            : () async {
                                await _changeActiveProfile(profile);
                              },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(
                      alpha: isDark ? 0.25 : 0.16,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.brightness_7_outlined,
                          color: Colors.deepPurple,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Display Theme',
                                style: FeliVetUi.heading(context, size: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isDark
                                    ? 'Dark mode enabled'
                                    : 'Light mode enabled',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? FeliVetUi.mutedDark
                                      : FeliVetUi.mutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            AppSounds.playTap();
                            isDarkModeNotifier.value =
                                !isDarkModeNotifier.value;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: isDark
                                  ? Colors.amber.shade300
                                  : Colors.deepPurple,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(
                      alpha: isDark ? 0.25 : 0.16,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          color: Colors.deepPurple,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Report History',
                          style: FeliVetUi.heading(context, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (reportHistory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No reports available',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: reportHistory.map((result) {
                          final fileName =
                              '${result.detectedDisease ?? "Analysis"}_${result.timestamp.day}-${result.timestamp.month}-${result.timestamp.year}.pdf';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: const Color(0xFFE0402C),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${result.timestamp.day}/${result.timestamp.month}/${result.timestamp.year} ${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        _pdfAvailability[_pdfKey(result)] ==
                                            true
                                        ? 'Open PDF'
                                        : 'Download PDF',
                                    icon: Icon(
                                      _pdfAvailability[_pdfKey(result)] == true
                                          ? Icons.open_in_new_outlined
                                          : Icons.download_outlined,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    onPressed: () async {
                                      AppSounds.playTap();
                                      try {
                                        final file =
                                            await PdfReportService.reportFileFor(
                                              result,
                                            );
                                        if (!await file.exists()) {
                                          await PdfReportService.generateScanReport(
                                            result,
                                          );
                                        }
                                        if (!mounted) return;
                                        setState(
                                          () =>
                                              _pdfAvailability[_pdfKey(
                                                    result,
                                                  )] =
                                                  true,
                                        );
                                        await OpenFilex.open(file.path);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('PDF ready to open'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Unable to create PDF: ${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(
                      alpha: isDark ? 0.25 : 0.16,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.deepPurple,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'About FeliVet Insight',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'v1.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'An intelligent AI-powered feline health triage system designed to help identify potential skin conditions and assess urgency through computer vision analysis.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
