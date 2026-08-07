import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cat_profile.dart';

class CatProfileStorage {
  static const String _key = 'felivet_cat_profiles';
  static const String _activeKey = 'felivet_active_cat_id';

  static Future<List<CatProfile>> loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => CatProfile.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveProfiles(List<CatProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    await prefs.setString(_key, encoded);
  }

  static Future<String?> loadActiveCatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<void> saveActiveCatId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }

  static Future<List<CatProfile>> ensureDefaultProfile() async {
    final profiles = await loadProfiles();
    if (profiles.isNotEmpty) {
      return profiles;
    }

    final defaultProfile = CatProfile(id: 'default_my_cat', name: 'My Cat');
    await saveProfiles([defaultProfile]);
    await saveActiveCatId(defaultProfile.id);
    return [defaultProfile];
  }
}
