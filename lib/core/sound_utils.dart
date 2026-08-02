import 'package:flutter/services.dart';

class AppSounds {
  static void playTap() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
