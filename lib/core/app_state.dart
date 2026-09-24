import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

const _darkModeKey = 'felivet_dark_mode';

Future<void> loadDarkMode() async {
  final prefs = await SharedPreferences.getInstance();
  isDarkModeNotifier.value = prefs.getBool(_darkModeKey) ?? false;
}

Future<void> saveDarkMode(bool isDark) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_darkModeKey, isDark);
}
