import 'package:flutter/services.dart';

import 'app_preferences.dart';

/// One preference-aware entry point for all future mode feedback.
class AppFeedback {
  static AppPreferences? preferences;
  static Future<void> selection() async {
    if (preferences?.haptics != true) return;
    try {
      await HapticFeedback.selectionClick();
    } on PlatformException {
      /* Optional platform feedback. */
    } on MissingPluginException {
      /* Unsupported platforms remain silent. */
    }
  }

  static Future<void> answer({required bool correct}) async {
    if (preferences?.haptics == true) {
      try {
        if (correct) {
          await HapticFeedback.lightImpact();
        } else {
          await HapticFeedback.mediumImpact();
        }
      } on PlatformException {
        /* Gameplay must not depend on haptic support. */
      } on MissingPluginException {
        /* Unsupported platforms remain silent. */
      }
    }
    if (correct && preferences?.sound == true) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } on PlatformException {
        /* Optional sound. */
      } on MissingPluginException {
        /* Unsupported platforms remain silent. */
      }
    }
  }
}
