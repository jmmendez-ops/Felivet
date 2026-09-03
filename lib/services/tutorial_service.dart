import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage onboarding tutorial state.
///
/// Tracks whether the user has seen the tutorial and provides methods to
/// show/reset the tutorial on demand via settings.
class TutorialService {
  static const String _tutorialShownKey = 'tutorial_onboarding_shown';

  /// Check if the user has already seen the onboarding tutorial.
  static Future<bool> hasShownTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialShownKey) ?? false;
  }

  /// Mark the tutorial as shown (called when user completes or skips tour).
  static Future<void> markTutorialAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialShownKey, true);
  }

  /// Reset the tutorial flag so it will show again on next app launch.
  /// Called when user taps "Replay Tutorial" in settings.
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialShownKey, false);
  }

  /// Check if tutorial should auto-show on app startup.
  /// Returns true only if tutorial has never been shown.
  static Future<bool> shouldAutoShowTutorial() async {
    return !(await hasShownTutorial());
  }
}
