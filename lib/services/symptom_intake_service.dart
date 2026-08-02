import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef DownloadProgressCallback = void Function(int received, int total);

class SymptomIntakeService {
  static const _storage = FlutterSecureStorage();
  static const int maxFollowUpTurns = 4;
  static const String defaultLocalModelId = 'gemma-3-1b-instruct';
  static const List<LocalModelOption> localModelOptions = [
    LocalModelOption(
      id: 'gemma-3-1b-instruct',
      label: 'Gemma 3 1B Instruct',
      description: 'Best for most phones. Fast, helpful, and easy to use.',
      version: 'Good choice for symptom notes and simple follow-up questions.',
      downloadUrl:
          'https://huggingface.co/ggml-org/gemma-3-1b-it-Q4_K_M/resolve/main/gemma-3-1b-it-q4_k_m.gguf',
      fileName: 'gemma-3-1b-instruct.gguf',
    ),
    LocalModelOption(
      id: 'qwen-2.5-1.5b-instruct',
      label: 'Qwen 2.5 1.5B Instruct',
      description:
          'Good for older or slower phones. Still helpful without taking much space.',
      version:
          'A solid choice if you want a smaller download and faster responses.',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      fileName: 'qwen-2.5-1.5b-instruct.gguf',
    ),
    LocalModelOption(
      id: 'smollm2-360m',
      label: 'SmolLM2 360M',
      description:
          'Fastest option for simple tasks. Good if you want the smallest download.',
      version: 'Best for quick yes/no questions and simple symptom lists.',
      downloadUrl:
          'https://huggingface.co/ggml-org/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q4_k_m.gguf',
      fileName: 'smollm2-360m.gguf',
    ),
  ];

  static SymptomIntakeResult analyze({
    required String userText,
    required Set<String> selectedSymptoms,
    required int turnCount,
  }) {
    final normalizedText = userText.trim().toLowerCase();

    final redFlag = _containsRedFlag(normalizedText, selectedSymptoms);
    if (redFlag) {
      return SymptomIntakeResult(
        redFlag: true,
        confidence: 0.0,
        extractedSymptoms: _emptySymptoms(),
        missingCriticalFields: const [],
        clarifyingQuestions: const [],
        readyForExpertSystem: false,
        partialData: false,
        inferenceMode: 'rule_based',
      );
    }

    final hasExplicitDetails = _hasMeaningfulDetails(normalizedText);
    final confidence = hasExplicitDetails ? 0.72 : 0.45;

    final extractedSymptoms = _buildExtractedSymptoms(
      normalizedText,
      selectedSymptoms,
    );
    final missingCriticalFields = _collectMissingFields(extractedSymptoms);

    final needsClarification =
        confidence < 0.6 || missingCriticalFields.isNotEmpty;
    final reachedTurnLimit = turnCount >= maxFollowUpTurns;

    final readyForExpertSystem = !needsClarification || reachedTurnLimit;

    return SymptomIntakeResult(
      redFlag: false,
      confidence: confidence,
      extractedSymptoms: extractedSymptoms,
      missingCriticalFields: missingCriticalFields,
      clarifyingQuestions: needsClarification && !reachedTurnLimit
          ? [
              'Please describe the symptoms you are noticing, including how long they have lasted.',
            ]
          : const [],
      readyForExpertSystem: readyForExpertSystem,
      partialData: reachedTurnLimit && missingCriticalFields.isNotEmpty,
      inferenceMode: 'rule_based',
    );
  }

  static bool _containsRedFlag(String text, Set<String> selectedSymptoms) {
    final emergencyMarkers = [
      'blood',
      'difficulty breathing',
      'trouble breathing',
      'collapse',
      'severe',
      'sudden',
      "won't stop",
      "won't stop",
    ];

    final hasEmergencyMarker = emergencyMarkers.any(text.contains);
    final hasEmergencySymptomCombination =
        selectedSymptoms.contains('vomiting') &&
        selectedSymptoms.contains('lethargy') &&
        selectedSymptoms.contains('loss_of_appetite');

    return hasEmergencyMarker || hasEmergencySymptomCombination;
  }

  static bool _hasMeaningfulDetails(String text) {
    return text.isNotEmpty &&
        text.split(RegExp(r'\s+')).length >= 3 &&
        !text.contains('seems off') &&
        !text.contains('something is wrong');
  }

  static Map<String, SymptomField> _emptySymptoms() {
    return {
      'symptom_a': SymptomField.presentUnknown(),
      'symptom_b': SymptomField.presentUnknown(),
      'symptom_c': SymptomField.presentUnknown(),
      'symptom_d': SymptomField.presentUnknown(),
      'symptom_e': SymptomField.presentUnknown(),
      'symptom_f': SymptomField.presentUnknown(),
    };
  }

  static Map<String, SymptomField> _buildExtractedSymptoms(
    String text,
    Set<String> selectedSymptoms,
  ) {
    final symptoms = _emptySymptoms();

    if (text.contains('vomiting')) {
      symptoms['symptom_a'] = SymptomField(
        present: 'yes',
        severity: selectedSymptoms.contains('vomiting')
            ? 'moderate'
            : 'unknown',
        durationDays: 'unknown',
      );
    }
    if (text.contains('lethargy') || selectedSymptoms.contains('lethargy')) {
      symptoms['symptom_b'] = SymptomField(
        present: 'yes',
        severity: selectedSymptoms.contains('lethargy')
            ? 'moderate'
            : 'unknown',
        durationDays: 'unknown',
      );
    }
    if (text.contains('appetite') ||
        selectedSymptoms.contains('loss_of_appetite')) {
      symptoms['symptom_c'] = SymptomField(
        present: 'yes',
        severity: selectedSymptoms.contains('loss_of_appetite')
            ? 'moderate'
            : 'unknown',
        durationDays: 'unknown',
      );
    }
    if (text.contains('rash')) {
      symptoms['symptom_d'] = SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }

    return symptoms;
  }

  static List<String> _collectMissingFields(
    Map<String, SymptomField> symptoms,
  ) {
    final missing = <String>[];
    for (final entry in symptoms.entries) {
      if (entry.value.present == 'unknown') {
        missing.add('${entry.key}.present');
      }
      if (entry.value.severity == 'unknown') {
        missing.add('${entry.key}.severity');
      }
      if (entry.value.durationDays == 'unknown') {
        missing.add('${entry.key}.duration_days');
      }
    }
    return missing;
  }

  static Future<void> saveProviderSetting({
    required String provider,
    required bool useLocalModel,
    String? selectedLocalModel,
    String? apiKey,
  }) async {
    await _storage.write(key: 'provider', value: provider);
    await _storage.write(key: 'useLocalModel', value: useLocalModel.toString());
    if (selectedLocalModel != null && selectedLocalModel.isNotEmpty) {
      await _storage.write(
        key: 'selectedLocalModel',
        value: selectedLocalModel,
      );
    }
    if (apiKey != null && apiKey.isNotEmpty) {
      await _storage.write(key: 'apiKey', value: apiKey);
    }
  }

  static Future<Map<String, dynamic>> loadProviderSetting() async {
    final provider = await _storage.read(key: 'provider') ?? 'local';
    final useLocalModel = (await _storage.read(key: 'useLocalModel')) == 'true';
    final selectedLocalModel =
        await _storage.read(key: 'selectedLocalModel') ?? defaultLocalModelId;
    final apiKey = await _storage.read(key: 'apiKey');
    final downloadedModelPath = await _storage.read(key: 'downloadedModelPath');
    final resolvedModelPath = _resolveDownloadedModelPath(
      downloadedModelPath,
      selectedLocalModel,
    );
    final modelDownloaded =
        resolvedModelPath != null && File(resolvedModelPath).existsSync();
    return {
      'provider': provider,
      'useLocalModel': useLocalModel,
      'selectedLocalModel': selectedLocalModel,
      'apiKey': apiKey,
      'downloadedModelPath': resolvedModelPath,
      'modelDownloaded': modelDownloaded,
    };
  }

  static String? _resolveDownloadedModelPath(
    String? downloadedModelPath,
    String? selectedLocalModel,
  ) {
    if (downloadedModelPath != null && downloadedModelPath.isNotEmpty) {
      return downloadedModelPath;
    }

    if (selectedLocalModel == null || selectedLocalModel.isEmpty) {
      return null;
    }

    final option = localModelOptions.firstWhere(
      (model) => model.id == selectedLocalModel,
      orElse: () => localModelOptions.first,
    );

    final appDir = Directory('${Directory.current.path}/models');
    final candidate = '${appDir.path}/${option.fileName}';
    return File(candidate).existsSync() ? candidate : null;
  }

  static Future<String> downloadLocalModel({
    required String modelId,
    DownloadProgressCallback? onProgress,
  }) async {
    final option = localModelOptions.firstWhere(
      (model) => model.id == modelId,
      orElse: () => localModelOptions.first,
    );

    final addresses = await InternetAddress.lookup('huggingface.co');
    if (addresses.isEmpty) {
      throw Exception('No internet connection available.');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');
    await modelDir.create(recursive: true);

    final targetPath = '${modelDir.path}/${option.fileName}';
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(option.downloadUrl));
      final streamedResponse = await client.send(request);
      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
          'Failed to download model (${streamedResponse.statusCode}).',
        );
      }

      final total = streamedResponse.contentLength ?? -1;
      final file = File(targetPath);
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received, total);
        }
      }
      await sink.close();
      await _storage.write(key: 'selectedLocalModel', value: option.id);
      await _storage.write(key: 'downloadedModelPath', value: file.path);
      return 'Downloaded ${option.label} to ${file.path}';
    } finally {
      client.close();
    }
  }

  static Future<String> generateChatReply({
    required String userMessage,
    required List<String> history,
  }) async {
    final settings = await loadProviderSetting();
    final provider = (settings['provider'] as String?) ?? 'local';
    final useLocalModel = settings['useLocalModel'] as bool? ?? true;
    final modelDownloaded = settings['modelDownloaded'] as bool? ?? false;
    final apiKey = (settings['apiKey'] as String?) ?? '';

    try {
      if (provider == 'openai' && apiKey.isNotEmpty) {
        final response = await runRemoteChat(
          prompt: userMessage,
          history: history,
          apiKey: apiKey,
        );
        if (response.trim().isNotEmpty) {
          return response;
        }
      }

      if (useLocalModel && modelDownloaded) {
        final response = await runLocalChat(
          prompt: userMessage,
          history: history,
        );
        if (response.trim().isNotEmpty) {
          return response;
        }
      }
    } catch (_) {}

    final message = userMessage.trim().toLowerCase();
    final hasVomiting =
        message.contains('vomit') || message.contains('throwing up');
    final hasSleepy = message.contains('sleep') || message.contains('letharg');
    final hasAppetite =
        message.contains('appetite') || message.contains('eating');

    if (hasVomiting && hasSleepy) {
      return 'That combination can be concerning. Please monitor your cat closely and contact a veterinarian soon, especially if the vomiting continues or your cat becomes worse.';
    }

    if (hasVomiting) {
      return 'Vomiting can have many causes. If it continues for more than a day, or your cat seems weak, please contact a vet.';
    }

    if (hasSleepy) {
      return 'Lethargy can be a sign that your cat needs veterinary attention, especially if it is new or severe.';
    }

    if (hasAppetite) {
      return 'Loss of appetite can be a clue that something is wrong. If your cat is refusing food for more than a day, it is wise to contact a vet.';
    }

    if (history.isNotEmpty) {
      return 'I can help you track symptoms and decide whether veterinary advice is appropriate. Tell me more about what your cat is doing.';
    }

    return 'I can help you describe your cat\'s symptoms and suggest when veterinary care may be needed. What is happening today?';
  }

  static Future<SymptomIntakeResult> extractChecklistFromText({
    required String userText,
    required Set<String> selectedSymptoms,
    required int turnCount,
  }) async {
    final normalizedText = userText.trim();
    if (normalizedText.isEmpty) {
      return _buildConservativeChecklist('', selectedSymptoms, turnCount);
    }

    final settings = await loadProviderSetting();
    final provider = (settings['provider'] as String?) ?? 'local';
    final useLocalModel = settings['useLocalModel'] as bool? ?? true;
    final modelDownloaded = settings['modelDownloaded'] as bool? ?? false;
    final apiKey = (settings['apiKey'] as String?) ?? '';

    try {
      if (provider == 'openai' && apiKey.isNotEmpty) {
        final content = await runRemoteInference(
          prompt: normalizedText,
          apiKey: apiKey,
        );
        final parsed = parseStructuredIntakeResult(content);
        if (parsed != null) {
          return parsed;
        }
      } else if (useLocalModel && modelDownloaded) {
        final content = await runLocalInference(prompt: normalizedText);
        final parsed = parseStructuredIntakeResult(content);
        if (parsed != null) {
          return parsed;
        }
      }
    } catch (_) {}

    return _buildFallbackResult(
      normalizedText,
      selectedSymptoms,
      turnCount,
      useLocalModel && modelDownloaded ? 'local_fallback' : 'rule_based',
    );
  }

  static Future<String> runLocalInference({required String prompt}) async {
    final runtimeAvailable = await _isLocalRuntimeAvailable();
    if (!runtimeAvailable) {
      throw Exception('No compatible local runtime was found.');
    }

    final modelPath = await _storage.read(key: 'downloadedModelPath');
    final safePrompt = _buildSafePrompt(prompt);
    final args = <String>['--prompt', safePrompt];
    if (modelPath != null && modelPath.isNotEmpty) {
      args.addAll(['--model', modelPath]);
    }
    final response = await Process.run('llama-cli', args);
    if (response.exitCode != 0) {
      throw Exception(response.stderr.toString().trim());
    }
    return normalizeModelOutput(response.stdout.toString().trim());
  }

  static Future<bool> _isLocalRuntimeAvailable() async {
    try {
      final candidates = <String>['llama-cli', 'ollama'];
      for (final candidate in candidates) {
        final executable = Platform.isWindows ? 'where.exe' : 'which';
        final response = await Process.run(executable, [candidate]);
        if (response.exitCode == 0) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> runLocalChat({
    required String prompt,
    required List<String> history,
  }) async {
    final runtimeAvailable = await _isLocalRuntimeAvailable();
    if (!runtimeAvailable) {
      throw Exception('No compatible local runtime was found.');
    }

    final settings = await loadProviderSetting();
    final selectedModelPath =
        (settings['downloadedModelPath'] as String?) ?? '';
    final safePrompt = _buildChatPrompt(prompt, history);
    final args = <String>['--prompt', safePrompt];
    if (selectedModelPath.isNotEmpty) {
      args.addAll(['--model', selectedModelPath]);
    }

    final runtimeCommand = await _detectLocalRuntimeCommand();
    final response = await Process.run(runtimeCommand, args);
    if (response.exitCode != 0) {
      throw Exception(response.stderr.toString().trim());
    }
    return _cleanChatOutput(response.stdout.toString().trim());
  }

  static Future<String> _detectLocalRuntimeCommand() async {
    final candidates = <String>['llama-cli', 'ollama'];
    for (final candidate in candidates) {
      final executable = Platform.isWindows ? 'where.exe' : 'which';
      final response = await Process.run(executable, [candidate]);
      if (response.exitCode == 0) {
        return candidate;
      }
    }
    throw Exception('No compatible local runtime was found.');
  }

  static Future<String> runRemoteChat({
    required String prompt,
    required List<String> history,
    required String apiKey,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a caring cat health assistant. Respond helpfully, briefly, and clearly. Do not diagnose. Encourage veterinary care for urgent or worsening symptoms.',
          },
          ...history.length > 6
              ? history.sublist(history.length - 6).map((entry) {
                  final isUser = history.indexOf(entry) % 2 == 0;
                  return {
                    'role': isUser ? 'user' : 'assistant',
                    'content': entry,
                  };
                })
              : history.map((entry) {
                  final isUser = history.indexOf(entry) % 2 == 0;
                  return {
                    'role': isUser ? 'user' : 'assistant',
                    'content': entry,
                  };
                }),
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Remote inference failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Remote inference returned no choices');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = (message?['content'] as String?) ?? '';
    return _cleanChatOutput(content.trim());
  }

  static Future<String> runRemoteInference({
    required String prompt,
    required String apiKey,
  }) async {
    final safePrompt = _buildSafePrompt(prompt);
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a symptom intake assistant. Do not guess. Return a valid JSON object only. If the user did not clearly mention a symptom, set the value to "unknown" or false. Never invent symptoms or diseases.',
          },
          {'role': 'user', 'content': safePrompt},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Remote inference failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Remote inference returned no choices');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = (message?['content'] as String?) ?? '';
    return normalizeModelOutput(content);
  }

  static String _buildSafePrompt(String prompt) {
    return '''You are a symptom intake assistant.
IMPORTANT: Do not guess. Only use details explicitly present in the user message.
If a symptom is missing, use "unknown" or false.
Return a valid JSON object with these fields only:
{
  "red_flag": false,
  "confidence": 0.0,
  "extracted_symptoms": {
    "symptom_a": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"},
    "symptom_b": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"},
    "symptom_c": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"},
    "symptom_d": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"},
    "symptom_e": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"},
    "symptom_f": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}
  },
  "missing_critical_fields": [],
  "clarifying_questions": [],
  "ready_for_expert_system": false,
  "partial_data": false
}
User message: $prompt''';
  }

  static String _buildChatPrompt(String prompt, List<String> history) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are a caring cat health assistant. Reply briefly, helpfully, and clearly. Do not diagnose. Suggest veterinary care for urgent or worsening symptoms.',
    );
    final recentHistory = history.length > 6
        ? history.sublist(history.length - 6)
        : history;
    for (final entry in recentHistory) {
      buffer.writeln(entry);
    }
    buffer.writeln('User: $prompt');
    buffer.writeln('Assistant:');
    return buffer.toString();
  }

  static String _cleanChatOutput(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return '';
    final start = cleaned.indexOf('Assistant:');
    if (start >= 0) {
      return cleaned.substring(start + 'Assistant:'.length).trim();
    }
    return cleaned;
  }

  static SymptomIntakeResult? parseStructuredIntakeResult(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final extracted = <String, SymptomField>{};
      final symptoms = decoded['extracted_symptoms'] as Map<String, dynamic>?;
      if (symptoms == null) {
        return null;
      }

      for (final entry in symptoms.entries) {
        final value = entry.value as Map<String, dynamic>?;
        if (value == null) continue;
        extracted[entry.key] = SymptomField(
          present: (value['present'] ?? 'unknown').toString(),
          severity: (value['severity'] ?? 'unknown').toString(),
          durationDays: (value['duration_days'] ?? 'unknown').toString(),
        );
      }

      return SymptomIntakeResult(
        redFlag: (decoded['red_flag'] as bool?) ?? false,
        confidence: (decoded['confidence'] as num?)?.toDouble() ?? 0.0,
        extractedSymptoms: extracted,
        missingCriticalFields: List<String>.from(
          decoded['missing_critical_fields'] ?? const [],
        ),
        clarifyingQuestions: List<String>.from(
          decoded['clarifying_questions'] ?? const [],
        ),
        readyForExpertSystem:
            (decoded['ready_for_expert_system'] as bool?) ?? false,
        partialData: (decoded['partial_data'] as bool?) ?? false,
        inferenceMode: (decoded['inference_mode'] as String?) ?? 'local_model',
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, bool> checklistFlagsFromResult(
    SymptomIntakeResult result,
  ) {
    return {
      'vomiting': result.extractedSymptoms['symptom_a']?.present == 'yes',
      'lethargy': result.extractedSymptoms['symptom_b']?.present == 'yes',
      'loss_of_appetite':
          result.extractedSymptoms['symptom_c']?.present == 'yes',
    };
  }

  static SymptomIntakeResult _buildConservativeChecklist(
    String userText,
    Set<String> selectedSymptoms,
    int turnCount,
  ) {
    final normalizedText = userText.trim().toLowerCase();
    final hasAnySymptom =
        normalizedText.contains('vomit') ||
        normalizedText.contains('throwing up') ||
        normalizedText.contains('heaving') ||
        normalizedText.contains('letharg') ||
        normalizedText.contains('sleepy') ||
        normalizedText.contains('appetite') ||
        normalizedText.contains('eating') ||
        selectedSymptoms.isNotEmpty;

    final symptoms = _emptySymptoms();
    if (normalizedText.contains('vomit') ||
        normalizedText.contains('throwing up') ||
        normalizedText.contains('heaving')) {
      symptoms['symptom_a'] = const SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }
    if (normalizedText.contains('letharg') ||
        normalizedText.contains('sleepy') ||
        normalizedText.contains('lazy')) {
      symptoms['symptom_b'] = const SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }
    if (normalizedText.contains('appetite') ||
        normalizedText.contains('eating') ||
        normalizedText.contains('food')) {
      symptoms['symptom_c'] = const SymptomField(
        present: 'yes',
        severity: 'unknown',
        durationDays: 'unknown',
      );
    }

    final missingCriticalFields = _collectMissingFields(symptoms);
    final clarifyingQuestions =
        hasAnySymptom && missingCriticalFields.isNotEmpty
        ? [
            'Please say whether the symptom is present, and mention if it is worsening or lasting.',
          ]
        : const <String>[];
    final needsClarification =
        !hasAnySymptom || missingCriticalFields.isNotEmpty;

    return SymptomIntakeResult(
      redFlag: false,
      confidence: hasAnySymptom ? 0.7 : 0.0,
      extractedSymptoms: symptoms,
      missingCriticalFields: missingCriticalFields,
      clarifyingQuestions: needsClarification && turnCount < maxFollowUpTurns
          ? clarifyingQuestions
          : const [],
      readyForExpertSystem:
          !needsClarification || turnCount >= maxFollowUpTurns,
      partialData:
          turnCount >= maxFollowUpTurns && missingCriticalFields.isNotEmpty,
      inferenceMode: 'rule_based',
    );
  }

  static SymptomIntakeResult _buildFallbackResult(
    String userText,
    Set<String> selectedSymptoms,
    int turnCount,
    String inferenceMode,
  ) {
    final fallback = _buildConservativeChecklist(
      userText,
      selectedSymptoms,
      turnCount,
    );
    return fallback.copyWith(inferenceMode: inferenceMode);
  }

  static String normalizeModelOutput(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return '{"red_flag": false, "confidence": 0.0, "extracted_symptoms": {"symptom_a": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_b": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_c": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_d": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_e": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_f": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}}, "missing_critical_fields": [], "clarifying_questions": [], "ready_for_expert_system": false, "partial_data": false}';
    }

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final candidate = cleaned.substring(start, end + 1);
      try {
        jsonDecode(candidate);
        return candidate;
      } catch (_) {}
    }

    return '{"red_flag": false, "confidence": 0.0, "extracted_symptoms": {"symptom_a": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_b": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_c": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_d": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_e": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}, "symptom_f": {"present": "unknown", "severity": "unknown", "duration_days": "unknown"}}, "missing_critical_fields": [], "clarifying_questions": [], "ready_for_expert_system": false, "partial_data": false}';
  }
}

class SymptomIntakeResult {
  final bool redFlag;
  final double confidence;
  final Map<String, SymptomField> extractedSymptoms;
  final List<String> missingCriticalFields;
  final List<String> clarifyingQuestions;
  final bool readyForExpertSystem;
  final bool partialData;
  final String inferenceMode;

  const SymptomIntakeResult({
    required this.redFlag,
    required this.confidence,
    required this.extractedSymptoms,
    required this.missingCriticalFields,
    required this.clarifyingQuestions,
    required this.readyForExpertSystem,
    required this.partialData,
    this.inferenceMode = 'rule_based',
  });

  SymptomIntakeResult copyWith({
    bool? redFlag,
    double? confidence,
    Map<String, SymptomField>? extractedSymptoms,
    List<String>? missingCriticalFields,
    List<String>? clarifyingQuestions,
    bool? readyForExpertSystem,
    bool? partialData,
    String? inferenceMode,
  }) {
    return SymptomIntakeResult(
      redFlag: redFlag ?? this.redFlag,
      confidence: confidence ?? this.confidence,
      extractedSymptoms: extractedSymptoms ?? this.extractedSymptoms,
      missingCriticalFields:
          missingCriticalFields ?? this.missingCriticalFields,
      clarifyingQuestions: clarifyingQuestions ?? this.clarifyingQuestions,
      readyForExpertSystem: readyForExpertSystem ?? this.readyForExpertSystem,
      partialData: partialData ?? this.partialData,
      inferenceMode: inferenceMode ?? this.inferenceMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'red_flag': redFlag,
    'confidence': confidence,
    'extracted_symptoms': {
      for (final entry in extractedSymptoms.entries)
        entry.key: entry.value.toJson(),
    },
    'missing_critical_fields': missingCriticalFields,
    'clarifying_questions': clarifyingQuestions,
    'ready_for_expert_system': readyForExpertSystem,
    'partial_data': partialData,
    'inference_mode': inferenceMode,
  };
}

class SymptomField {
  final String present;
  final String severity;
  final String durationDays;

  const SymptomField({
    required this.present,
    required this.severity,
    required this.durationDays,
  });

  factory SymptomField.presentUnknown() => const SymptomField(
    present: 'unknown',
    severity: 'unknown',
    durationDays: 'unknown',
  );

  Map<String, dynamic> toJson() => {
    'present': present,
    'severity': severity,
    'duration_days': durationDays,
  };
}

class LocalModelOption {
  final String id;
  final String label;
  final String description;
  final String version;
  final String downloadUrl;
  final String fileName;

  const LocalModelOption({
    required this.id,
    required this.label,
    required this.description,
    required this.version,
    required this.downloadUrl,
    required this.fileName,
  });
}
