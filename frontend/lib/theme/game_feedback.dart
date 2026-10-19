import 'package:flutter/services.dart';

class GameFeedback {
  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  static void tap() {
    if (hapticsEnabled) HapticFeedback.lightImpact();
    if (soundEnabled) SystemSound.play(SystemSoundType.click);
  }
}
