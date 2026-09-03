import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/triage_models.dart';

class HistoryStorage {
  static const String _key = 'felivet_triage_history';

  static Future<List<TriageResult>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        if (kDebugMode) {
          print('HistoryStorage.load: no saved history found for key $_key');
        }
        return [];
      }
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      if (kDebugMode) {
        print('HistoryStorage.load: decoded ${decoded.length} entries');
      }
      final results = <TriageResult>[];
      for (final entry in decoded) {
        final result = TriageResult.fromJson(entry as Map<String, dynamic>);
        results.add(result);
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  static Future<List<TriageResult>> save(List<TriageResult> history) async {
    final prefs = await SharedPreferences.getInstance();
    final persistedResults = <TriageResult>[];
    final imageDir = await _historyImageDirectory();

    for (final result in history) {
      final image = await _copyImageToStorage(result.image, imageDir);
      persistedResults.add(result.copyWith(image: image));
    }

    final encoded = jsonEncode(
      persistedResults.map((result) => result.toJson()).toList(),
    );
    await prefs.setString(_key, encoded);
    return persistedResults;
  }

  static Future<void> deleteEntry(TriageResult entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final remaining = current
        .where((item) => item.timestamp != entry.timestamp)
        .toList();
    await save(remaining);
    await _deleteImageFile(entry.image);
    await prefs.setString(
      _key,
      jsonEncode(remaining.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    final imageDir = await _historyImageDirectory();
    if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
    }
  }

  static Future<Directory> _historyImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/history_images');
    await imageDir.create(recursive: true);
    return imageDir;
  }

  static Future<File?> _copyImageToStorage(
    File? image,
    Directory imageDir,
  ) async {
    if (image == null || !image.existsSync()) {
      return null;
    }

    if (image.path.startsWith(imageDir.path)) {
      return image;
    }

    final extension = image.path.split('.').lastOrNull ?? 'png';
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final destination = File('${imageDir.path}/$fileName');
    await image.copy(destination.path);
    return destination;
  }

  static Future<void> _deleteImageFile(File? image) async {
    if (image == null) {
      return;
    }
    if (await image.exists()) {
      await image.delete();
    }
  }
}

extension _StringListExtension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
