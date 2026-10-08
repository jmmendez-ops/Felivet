import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/detection_config.dart';
import '../core/sound_utils.dart';
import '../core/ui_tokens.dart';
import '../models/cat_profile.dart';
import '../models/triage_models.dart';
import '../services/cat_profile_storage.dart';
import '../services/cat_gatekeeper.dart';
import '../services/history_storage.dart';
import '../services/symptom_intake_service.dart';
import '../services/triage_engine.dart';
import '../services/pdf_report_service.dart';
import '../widgets/follow_up_reminder_panel.dart';
import 'history_screen.dart';
import 'result_screen.dart';
import 'status_screen.dart';
import 'triage_submission_validator.dart';

class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

abstract final class TriageTabs {
  static const dashboardTab = 0;
  static const statusTab = 1;
  static const historyTab = 2;
  static const settingsTab = 3;
}

enum _NoCatAction { retry, cancel }

class _NoCatDetectedDialog extends StatelessWidget {
  final File? rejectedImage;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _NoCatDetectedDialog({
    required this.rejectedImage,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasThumbnail = rejectedImage != null && rejectedImage!.existsSync();

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Icon(
                            Icons.pets_outlined,
                            color: scheme.tertiary,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'No cat detected',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "We couldn't find a cat in this photo. Try again with a clearer shot.",
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (hasThumbnail) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 118,
                          child: Image.file(
                            rejectedImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Try these tips',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _tip(
                      context,
                      Icons.crop_free_rounded,
                      'Make sure your cat is fully in frame',
                    ),
                    _tip(
                      context,
                      Icons.wb_sunny_outlined,
                      'Use good lighting and avoid blur',
                    ),
                    _tip(
                      context,
                      Icons.center_focus_strong_rounded,
                      'Get close to the affected area, but include some of the cat',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Semantics(
                        button: true,
                        label: 'Retry with the same photo source',
                        child: FilledButton(
                          onPressed: onRetry,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Semantics(
                        button: true,
                        label: 'Cancel and return to the empty dashboard',
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: scheme.surfaceContainerHighest,
                            foregroundColor: scheme.onSurface,
                            side: BorderSide(color: scheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tip(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PressScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final BoxDecoration decoration;
  final Color foregroundColor;
  final Color? iconColor;
  final IconData icon;
  final String label;

  const _PressScaleButton({
    required this.onPressed,
    required this.decoration,
    required this.foregroundColor,
    this.iconColor,
    required this.icon,
    required this.label,
  });

  @override
  State<_PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<_PressScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 100),
      child: DecoratedBox(
        decoration: widget.decoration,
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.iconColor ?? widget.foregroundColor,
                    size: 20,
                  ),
                  const SizedBox(width: FeliVetUi.spaceSm),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.foregroundColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<FlSpot> buildTrendSpots(List<TriageResult> history) {
  if (history.length < 2) return [];

  final ordered = history.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final scores = ordered.map((entry) {
    return switch (entry.urgency) {
      UrgencyLevel.high => 3.0,
      UrgencyLevel.moderate => 2.0,
      UrgencyLevel.stable => 1.0,
    };
  }).toList();

  return List.generate(ordered.length, (index) {
    return FlSpot(index.toDouble(), scores[index]);
  });
}

bool shouldShowTrendDateLabel(int index, int pointCount) {
  if (index < 0 || index >= pointCount) return false;
  if (pointCount <= 4) return true;

  final interval = (pointCount + 1) ~/ 3;
  return index == 0 || index == pointCount - 1 || index % interval == 0;
}

class _TriageScreenState extends State<TriageScreen> {
  File? _image;
  bool _hideLatestImage = false;
  final ImagePicker _picker = ImagePicker();
  ImageSource? _lastImageSource;

  FlutterVision? _vision;
  final CatGatekeeper _catGatekeeper = CatGatekeeper();
  bool _isModelLoaded = false;
  bool _isScanning = false;
  // ignore: unused_field
  String? _loadError;

  bool _isVomiting = false;
  bool _isLethargic = false;
  bool _lostAppetite = false;

  List<TriageResult> _history = [];
  final Map<String, bool> _pdfAvailability = {};
  List<CatProfile> _profiles = [];
  CatProfile? _activeProfile;
  int _selectedIndex = TriageTabs.dashboardTab;
  // ignore: unused_field
  String? _imageQualityMessage;
  int? _selectedTrendIndex;

  @override
  void initState() {
    super.initState();
    _loadCatGatekeeper();
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

  Future<void> _loadCatGatekeeper() async {
    try {
      await _catGatekeeper.load();
    } catch (error, stackTrace) {
      debugPrint('Cat gatekeeper failed to load: $error\n$stackTrace');
    }
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

  Widget _buildCatAvatar(
    BuildContext context,
    CatProfile profile, {
    double radius = 10,
  }) {
    final photoPath = profile.photoPath;
    final primary = Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: primary.withValues(alpha: 0.14),
      child: photoPath == null
          ? Text(
              profile.name.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: radius, color: primary),
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
                  style: TextStyle(fontSize: radius, color: primary),
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
    _catGatekeeper.close();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final shouldContinue = await _showCameraTips();
        if (!shouldContinue) return;
      }

      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final newImage = File(pickedFile.path);
      if (!await newImage.exists() || await newImage.length() == 0) {
        throw StateError('The selected image was not written completely.');
      }

      if (!mounted) return;
      setState(() {
        _image = newImage;
        _lastImageSource = source;
        _hideLatestImage = false;
        _imageQualityMessage = null;
      });
      await _assessImageQuality(newImage);
    } catch (error, stackTrace) {
      debugPrint('Image capture failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load that image. Please try again.'),
        ),
      );
    }
  }

  Future<void> _showNoCatDetectedDialog() async {
    final rejectedImage = _image;
    final source = _lastImageSource ?? ImageSource.gallery;
    var actionHandled = false;
    final action = await showGeneralDialog<_NoCatAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'No cat detected',
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 230),
      pageBuilder: (dialogContext, _, _) {
        return _NoCatDetectedDialog(
          rejectedImage: rejectedImage,
          onRetry: () {
            if (actionHandled) return;
            actionHandled = true;
            Navigator.of(dialogContext).pop(_NoCatAction.retry);
          },
          onCancel: () {
            if (actionHandled) return;
            actionHandled = true;
            Navigator.of(dialogContext).pop(_NoCatAction.cancel);
          },
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _image = null;
      _hideLatestImage = true;
      _imageQualityMessage = null;
    });

    if (action == _NoCatAction.retry) {
      await _getImage(source);
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

  Future<({Uint8List bytes, int width, int height})> _prepareImageForInference(
    File imageFile,
  ) async {
    final sourceBytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('The image format could not be decoded.');
    }

    final oriented = img.bakeOrientation(decoded);
    final longestSide = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final prepared = longestSide > 1600
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height
                ? 1600
                : (oriented.width * 1600 / oriented.height).round(),
            height: oriented.height >= oriented.width
                ? 1600
                : (oriented.height * 1600 / oriented.width).round(),
          )
        : oriented;
    final bytes = Uint8List.fromList(img.encodeJpg(prepared, quality: 85));
    debugPrint(
      'Prepared image for inference: ${prepared.width}x${prepared.height}, '
      '${bytes.length} bytes',
    );
    return (bytes: bytes, width: prepared.width, height: prepared.height);
  }

  Future<void> _runInference() async {
    if (_isScanning) return;
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

    setState(() => _isScanning = true);
    final qualityCheck = await _assessImageQuality(_image!);
    final shouldProceed =
        !qualityCheck.isLowQuality ||
        await _confirmImageQualityBeforeAnalysis();
    if (!shouldProceed || !mounted) {
      if (mounted) setState(() => _isScanning = false);
      return;
    }

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
        final prepared = await _prepareImageForInference(_image!);

        try {
          final score = await _catGatekeeper.catScore(prepared.bytes);
          debugPrint('Cat gatekeeper score: $score');
          if (score < CatGatekeeper.catThreshold) {
            if (!mounted) return;
            setState(() => _isScanning = false);
            await _showNoCatDetectedDialog();
            return;
          }
        } catch (error, stackTrace) {
          debugPrint('Cat gatekeeper failed: $error\n$stackTrace');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not check the image. Please try another photo.',
              ),
            ),
          );
          setState(() => _isScanning = false);
          return;
        }

        final List<dynamic> rawResults = await _vision!.yoloOnImage(
          bytesList: prepared.bytes,
          imageHeight: prepared.height,
          imageWidth: prepared.width,
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

  Widget _buildSymptomChip({
    required String title,
    required bool value,
    required ValueChanged<bool> onSelected,
  }) {
    final info = _symptomInfo[title.toLowerCase()] ?? _symptomInfo['default']!;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: value ? 1 : 0.98,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: FilterChip(
        selected: value,
        onSelected: onSelected,
        showCheckmark: true,
        checkmarkColor: scheme.onPrimaryContainer,
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(
          color: value
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.outline.withValues(alpha: 0.45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        labelStyle: TextStyle(
          color: value ? scheme.onPrimaryContainer : scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            const SizedBox(width: FeliVetUi.spaceXs),
            GestureDetector(
              onTap: () {
                AppSounds.playTap();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(title),
                    content: Text(info),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(
                Icons.info_outline,
                size: 15,
                color: value
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
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

  // ignore: unused_element
  Widget _buildQuickStats(bool isDark) {
    final activeHistory = _activeCatHistory;
    final latest = activeHistory.isNotEmpty ? activeHistory.first : null;
    final latestLabel = latest == null
        ? 'No scan yet'
        : latest.detectedDisease ?? 'No detected condition';
    final urgencyColor =
        latest?.urgency.color ?? Theme.of(context).colorScheme.primary;
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
          padding: FeliVetUi.cardPadding,
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
              const SizedBox(height: FeliVetUi.spaceSm),
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
                const SizedBox(height: FeliVetUi.spaceSm),
                Text(
                  'Scanned: ${latest.timestamp.day}/${latest.timestamp.month}/${latest.timestamp.year} ${latest.timestamp.hour.toString().padLeft(2, '0')}:${latest.timestamp.minute.toString().padLeft(2, '0')}',
                  style: FeliVetUi.muted(context, size: 12),
                ),
              ],
              const SizedBox(height: FeliVetUi.spaceSm),
              Row(
                children: [
                  _statChip(
                    Icons.history_rounded,
                    '${activeHistory.length}',
                    'Total scans',
                    isDark,
                  ),
                  const SizedBox(width: FeliVetUi.spaceSm),
                  if (latest?.confidence != null) ...[
                    const SizedBox(width: FeliVetUi.spaceSm),
                    _statChip(
                      Icons.verified_rounded,
                      '${(latest!.confidence! * 100).toStringAsFixed(0)}%',
                      'Confidence',
                      isDark,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FeliVetUi.spaceMd),
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
              const SizedBox(height: FeliVetUi.spaceXs),
              Text(
                'Tracks your cat\'s health score over time based on scan results. Higher scores indicate more urgency.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: FeliVetUi.spaceSm),
              if (trendSpots.length < 2)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: FeliVetUi.emptyState(context),
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
                        const SizedBox(height: FeliVetUi.spaceSm),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: math.max(280.0, trendSpots.length * 72.0),
                    height: 132,
                    child: LineChart(
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
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: trendSpots,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                final urgencyColor =
                                    historyForTrend[index].urgency.color;
                                return FlDotCirclePainter(
                                  radius: _selectedTrendIndex == index ? 6 : 5,
                                  color: urgencyColor,
                                  strokeWidth: _selectedTrendIndex == index
                                      ? 3
                                      : 1.5,
                                  strokeColor: _selectedTrendIndex == index
                                      ? Theme.of(context).colorScheme.primary
                                      : isDark
                                      ? Colors.white
                                      : Colors.black26,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.16),
                            ),
                          ),
                        ],
                        minY: 0.8,
                        maxY: 3.2,
                        lineTouchData: LineTouchData(
                          enabled: true,
                          handleBuiltInTouches: false,
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response?.lineBarSpots == null ||
                                response!.lineBarSpots!.isEmpty) {
                              return;
                            }
                            final index =
                                response.lineBarSpots!.first.spotIndex;
                            if (index < 0 || index >= historyForTrend.length) {
                              return;
                            }
                            setState(() => _selectedTrendIndex = index);
                            final scan = historyForTrend[index];
                            showModalBottomSheet<void>(
                              context: context,
                              builder: (sheetContext) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    FeliVetUi.spaceLg,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.event_outlined,
                                      color: scan.urgency.color,
                                    ),
                                    title: Text(
                                      '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}',
                                    ),
                                    subtitle: Text(
                                      '${scan.urgency.label} · ${scan.detectedDisease ?? 'No condition detected'}',
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: FeliVetUi.spaceXs),
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
        const SizedBox(height: FeliVetUi.spaceMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FeliVetUi.spaceMd),
          decoration: FeliVetUi.cardDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                decoration: FeliVetUi.iconBadge(context),
                child: Icon(
                  Icons.tips_and_updates_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: FeliVetUi.spaceSm),
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
        decoration: FeliVetUi.cardDecoration(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(FeliVetUi.spaceSm),
              decoration: FeliVetUi.iconBadge(context),
              child: Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: FeliVetUi.spaceXs),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        const SizedBox(width: FeliVetUi.spaceXs),
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

  Widget _buildSystemicSymptomsCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FeliVetUi.spaceLg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const []
            : [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.04),
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                decoration: FeliVetUi.iconBadge(context),
                child: Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: FeliVetUi.spaceSm),
              Text(
                'Systemic Symptoms',
                style: FeliVetUi.heading(context, size: 18),
              ),
            ],
          ),
          const SizedBox(height: FeliVetUi.spaceXs),
          Text(
            'Optional: select anything you have noticed',
            style: FeliVetUi.muted(context, size: 12),
          ),
          const SizedBox(height: FeliVetUi.spaceMd),
          Wrap(
            spacing: FeliVetUi.spaceSm,
            runSpacing: FeliVetUi.spaceSm,
            children: [
              _buildSymptomChip(
                title: 'Vomiting',
                value: _isVomiting,
                onSelected: (value) => setState(() => _isVomiting = value),
              ),
              _buildSymptomChip(
                title: 'Lethargy',
                value: _isLethargic,
                onSelected: (value) => setState(() => _isLethargic = value),
              ),
              _buildSymptomChip(
                title: 'Loss of Appetite',
                value: _lostAppetite,
                onSelected: (value) => setState(() => _lostAppetite = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _dashboardCardDecoration(
    BuildContext context, {
    double radius = 24,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      boxShadow: Theme.of(context).brightness == Brightness.dark
          ? const []
          : [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.13),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.05),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
    );
  }

  Widget _buildDashboardStatusMessage() {
    final scheme = Theme.of(context).colorScheme;
    final String? message =
        _imageQualityMessage ??
        _loadError ??
        (!_isModelLoaded ? 'Loading detection model…' : null);
    if (message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: FeliVetUi.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: FeliVetUi.spaceMd,
        vertical: FeliVetUi.spaceSm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          if (_imageQualityMessage == null && _loadError == null)
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else
            Icon(
              _loadError == null
                  ? Icons.lightbulb_circle_outlined
                  : Icons.warning_amber_rounded,
              color: scheme.primary,
              size: 19,
            ),
          const SizedBox(width: FeliVetUi.spaceSm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoHero() {
    final scheme = Theme.of(context).colorScheme;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.4).clamp(
      200.0,
      300.0,
    );
    final preview = _previewImage;

    return Container(
      width: double.infinity,
      height: heroHeight,
      decoration: _dashboardCardDecoration(context, radius: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          child: preview == null
              ? CustomPaint(
                  key: const ValueKey('empty-photo'),
                  foregroundPainter: DashedBorderPainter(
                    color: scheme.primary.withValues(alpha: 0.34),
                    radius: 28,
                  ),
                  child: _buildEmptyPhotoState(),
                )
              : _buildPhotoPreview(preview),
        ),
      ),
    );
  }

  Widget _buildEmptyPhotoState() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.pets_rounded,
              size: 42,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: FeliVetUi.spaceMd),
          Text(
            'Upload a photo to begin',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: FeliVetUi.spaceXs),
          Text(
            'Use good lighting and keep the skin area in focus',
            textAlign: TextAlign.center,
            style: FeliVetUi.muted(context, size: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(File preview) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      key: const ValueKey('photo-preview'),
      fit: StackFit.expand,
      children: [
        Image.file(
          preview,
          fit: BoxFit.cover,
          cacheWidth: 900,
          filterQuality: FilterQuality.low,
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0),
                  scheme.scrim.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
        ),
        if (_image != null)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: scheme.surface.withValues(alpha: 0.72),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Remove selected photo',
                icon: Icon(Icons.close_rounded, color: scheme.onSurface),
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
    );
  }

  Widget _buildCaptureButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildCaptureButton(
            source: ImageSource.camera,
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
          ),
        ),
        const SizedBox(width: FeliVetUi.spaceMd),
        Expanded(
          child: _buildCaptureButton(
            source: ImageSource.gallery,
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton({
    required ImageSource source,
    required IconData icon,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return _PressScaleButton(
      onPressed: () {
        AppSounds.playTap();
        _getImage(source);
      },
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      foregroundColor: scheme.onSurface,
      iconColor: scheme.primary,
      icon: icon,
      label: label,
    );
  }

  Widget _buildAnalyzeButton() {
    final scheme = Theme.of(context).colorScheme;
    final enabled = _image != null && !_isScanning;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: enabled
              ? scheme.primary
              : scheme.primary.withValues(alpha: 0.35),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary.withValues(alpha: 0),
              shadowColor: scheme.primary.withValues(alpha: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: enabled
                ? () {
                    AppSounds.playTap();
                    _runInference();
                  }
                : null,
            child: _isScanning
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    'ANALYZE HEALTH',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardEntrance(Widget child, int delayMs) {
    return child
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 250),
          delay: Duration(milliseconds: delayMs),
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: const Duration(milliseconds: 250),
          delay: Duration(milliseconds: delayMs),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildDashboard() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, scheme.surfaceContainer],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceMd,
                  FeliVetUi.spaceLg,
                  FeliVetUi.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dashboardEntrance(_buildDashboardStatusMessage(), 0),
                    _dashboardEntrance(_buildPhotoHero(), 60),
                    const SizedBox(height: FeliVetUi.spaceMd),
                    _dashboardEntrance(_buildCaptureButtons(), 120),
                    const SizedBox(height: FeliVetUi.spaceLg),
                    _dashboardEntrance(_buildSystemicSymptomsCard(), 180),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FeliVetUi.spaceLg,
                FeliVetUi.spaceSm,
                FeliVetUi.spaceLg,
                FeliVetUi.spaceMd,
              ),
              child: _dashboardEntrance(_buildAnalyzeButton(), 240),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _buildDashboard(),
      StatusScreen(history: _activeCatHistory),
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
                                      profile.id == (_activeProfile?.id ?? '');
                                  return ListTile(
                                    leading: _buildCatAvatar(
                                      context,
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
                  horizontal: FeliVetUi.spaceMd,
                  vertical: FeliVetUi.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.22),
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
                                color: FeliVetUi.accent,
                              ),
                            ),
                          )
                        : _buildCatAvatar(context, _activeProfile!, radius: 10),
                    const SizedBox(width: FeliVetUi.spaceSm),
                    Text(
                      _activeProfile?.name ?? 'My Cat',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: FeliVetUi.spaceXs / 2),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
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
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart_rounded),
            label: 'Status',
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
    );
  }

  Widget _buildPersonalization() {
    final reportHistory = _activeCatHistory;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FeliVetUi.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: FeliVetUi.spaceLg),
          GestureDetector(
            onTap: () => _showAddCatDialog(fromSettings: true),
            child: Container(
              width: double.infinity,
              padding: FeliVetUi.cardPadding,
              decoration: FeliVetUi.cardDecoration(context),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                    decoration: FeliVetUi.iconBadge(context),
                    child: Icon(
                      Icons.pets_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: FeliVetUi.spaceMd),
                  Expanded(
                    child: Text(
                      'Add cat profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FeliVetUi.spaceMd),
          if (_profiles.isNotEmpty) ...[
            Text(
              'Your cats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: FeliVetUi.spaceMd),
            ..._profiles.map((profile) {
              final isActive = profile.id == (_activeProfile?.id ?? '');
              return Padding(
                padding: const EdgeInsets.only(bottom: FeliVetUi.spaceSm),
                child: Container(
                  decoration: FeliVetUi.cardDecoration(context),
                  child: ListTile(
                    leading: _buildCatAvatar(context, profile, radius: 20),
                    title: Text(profile.name),
                    subtitle: profile.breed != null
                        ? Text(profile.breed!)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
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
            const SizedBox(height: FeliVetUi.spaceMd),
          ],
          const SizedBox(height: FeliVetUi.spaceMd),
          FollowUpReminderPanel(catName: _activeProfile?.name),
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
                    Container(
                      padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                      decoration: FeliVetUi.iconBadge(
                        context,
                        color: Colors.blueGrey,
                      ),
                      child: Icon(
                        Icons.file_download_outlined,
                        color: Colors.blueGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: FeliVetUi.spaceMd),
                    Text(
                      'Report History',
                      style: FeliVetUi.heading(context, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: FeliVetUi.spaceMd),
                if (reportHistory.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FeliVetUi.spaceXl,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                            decoration: FeliVetUi.iconBadge(context),
                            child: Icon(
                              Icons.inbox_outlined,
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: FeliVetUi.spaceMd),
                          Text(
                            'No reports available',
                            style: FeliVetUi.muted(context, size: 14),
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
                        padding: const EdgeInsets.only(
                          bottom: FeliVetUi.spaceSm,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(FeliVetUi.spaceMd),
                          decoration: FeliVetUi.cardDecoration(context),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  FeliVetUi.spaceSm,
                                ),
                                decoration: FeliVetUi.iconBadge(
                                  context,
                                  color: const Color(0xFFE0402C),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  color: Color(0xFFE0402C),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: FeliVetUi.spaceSm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '${result.timestamp.day}/${result.timestamp.month}/${result.timestamp.year} ${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    _pdfAvailability[_pdfKey(result)] == true
                                    ? 'Open PDF'
                                    : 'Download PDF',
                                icon: Container(
                                  padding: const EdgeInsets.all(
                                    FeliVetUi.spaceSm,
                                  ),
                                  decoration: FeliVetUi.iconBadge(context),
                                  child: Icon(
                                    _pdfAvailability[_pdfKey(result)] == true
                                        ? Icons.open_in_new_outlined
                                        : Icons.download_outlined,
                                  ),
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
                                      () => _pdfAvailability[_pdfKey(result)] =
                                          true,
                                    );
                                    await OpenFilex.open(file.path);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('PDF ready to open'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                    Container(
                      padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                      decoration: FeliVetUi.iconBadge(context),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: FeliVetUi.spaceMd),
                    Text(
                      'About FeliVet Insight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FeliVetUi.spaceSm),
                Text(
                  'v1.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: FeliVetUi.spaceXs),
                Text(
                  'An intelligent AI-powered feline health triage system designed to help identify potential skin conditions and assess urgency through computer vision analysis.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FeliVetUi.spaceXl),
        ],
      ),
    );
  }
}
