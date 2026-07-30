import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image_picker/image_picker.dart';

import '../config/detection_config.dart';
import '../core/app_state.dart';
import '../models/triage_models.dart';
import '../services/history_storage.dart';
import '../services/triage_engine.dart';
import 'history_screen.dart';
import 'result_screen.dart';

class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  FlutterVision? _vision;
  bool _isModelLoaded = false;
  bool _isScanning = false;
  String? _loadError;

  bool _isVomiting = false;
  bool _isLethargic = false;
  bool _lostAppetite = false;

  List<TriageResult> _history = [];
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final saved = await HistoryStorage.load();
    if (!mounted) return;
    setState(() {
      _history = saved;
      _isHistoryLoaded = true;
    });
  }

  Future<void> _persistHistory() async {
    await HistoryStorage.save(_history);
  }

  Future<void> _deleteHistoryEntry(TriageResult entry) async {
    setState(() => _history.remove(entry));
    await _persistHistory();
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    await HistoryStorage.clear();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          history: _history,
          onDelete: _deleteHistoryEntry,
          onClearAll: _clearHistory,
        ),
      ),
    );
  }

  Future<void> _loadModel() async {
    try {
      _vision ??= FlutterVision();
      await _vision!.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/CatDisease.tflite',
        modelVersion: 'yolov8',
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
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  int get _symptomCount =>
      [_isVomiting, _isLethargic, _lostAppetite].where((s) => s).length;

  Future<void> _runInference() async {
    if (_image == null || !_isModelLoaded) return;
    setState(() => _isScanning = true);

    try {
      final Uint8List bytes = await _image!.readAsBytes();
      final imageInfo = await decodeImageFromList(bytes);

      final List<dynamic> rawResults = await _vision!.yoloOnImage(
        bytesList: bytes,
        imageHeight: imageInfo.height,
        imageWidth: imageInfo.width,
        iouThreshold: DetectionConfig.iouThreshold,
        confThreshold: DetectionConfig.minDetectionConfidence,
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

      final evidenceList = <DiseaseEvidence>[];
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

      final result = runExpertSystem(
        evidenceList: evidenceList,
        symptomCount: _symptomCount,
        image: _image,
      );

      setState(() {
        _isScanning = false;
        _history.insert(0, result);
      });
      await _persistHistory();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value
            ? (isDark
                  ? Colors.teal.shade900.withValues(alpha: 0.5)
                  : Colors.teal.shade50)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value
              ? Colors.teal
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: value ? 2.5 : 1.0,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: value ? FontWeight.bold : FontWeight.w500,
              color: value
                  ? (isDark ? Colors.tealAccent : Colors.teal.shade900)
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.teal,
          checkColor: Colors.white,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSymptoms = _symptomCount > 0;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets, size: 26),
                SizedBox(width: 10),
                Text(
                  'FeliVet Insight',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          drawer: SizedBox(
            width: MediaQuery.of(context).size.width * 0.20,
            child: Drawer(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () =>
                          isDarkModeNotifier.value = !isDarkModeNotifier.value,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.teal.shade700
                              : Colors.teal.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.teal.shade800,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDark ? 'Dark' : 'Light',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: !_isHistoryLoaded
                          ? null
                          : () {
                              Navigator.pop(context);
                              _openHistory();
                            },
                      child: Opacity(
                        opacity: _history.isEmpty ? 0.4 : 1.0,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.teal.shade900
                                    : Colors.teal.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.history_rounded,
                                color: isDark
                                    ? Colors.tealAccent
                                    : Colors.teal.shade800,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'History',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadError != null)
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
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _image == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pets,
                                size: 60,
                                color: Colors.teal[200],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Upload a photo to begin',
                                style: TextStyle(
                                  color: Colors.teal[300],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.teal.shade400,
                            width: 2.5,
                          ),
                        ),
                        onPressed: () => _getImage(ImageSource.camera),
                        icon: Icon(
                          Icons.camera_alt,
                          color: Colors.teal.shade700,
                        ),
                        label: Text(
                          'Camera',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.teal.shade400,
                            width: 2.5,
                          ),
                        ),
                        onPressed: () => _getImage(ImageSource.gallery),
                        icon: Icon(
                          Icons.photo_library,
                          color: Colors.teal.shade700,
                        ),
                        label: Text(
                          'Gallery',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  'Systemic Symptoms',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check any symptoms your cat is currently showing.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 15),
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
                if (hasSymptoms) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F2D40)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark
                            ? Colors.blue.shade800
                            : Colors.blue.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getSymptomInsight(),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.blue.shade100
                                  : Colors.blue.shade900,
                              height: 1.4,
                              fontSize: 14,
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
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed:
                        (_image == null || !_isModelLoaded || _isScanning)
                        ? null
                        : _runInference,
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
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}
