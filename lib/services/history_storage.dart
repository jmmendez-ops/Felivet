import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/triage_models.dart';

class HistoryStorage {
  static const String _key = 'felivet_triage_history';

  static Future<List<TriageResult>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TriageResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TriageResult> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
