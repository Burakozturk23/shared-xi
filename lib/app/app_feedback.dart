import 'package:flutter/services.dart';

import 'app_preferences.dart';

/// Preference-aware feedback. Unsupported hardware never blocks gameplay.
class AppFeedback {
  static AppPreferences? preferences;
  static Future<void> selection() =>
      _vibrate(preferences, selection: true);

  static Future<void> previewHaptics(AppPreferences settings) =>
      _vibrate(settings);

  static Future<void> previewSound(AppPreferences settings) => _sound(settings);

  static Future<void> _vibrate(
    AppPreferences? settings, {
    bool selection = false,
    bool correct = true,
  }) async {
    if (settings?.haptics != true) return;
    try {
      switch (settings!.hapticStrength) {
        case HapticStrength.gentle:
          await HapticFeedback.selectionClick();
        case HapticStrength.standard:
          if (selection) {
            await HapticFeedback.selectionClick();
          } else if (correct) {
            await HapticFeedback.lightImpact();
          } else {
            await HapticFeedback.mediumImpact();
          }
        case HapticStrength.strong:
          await HapticFeedback.heavyImpact();
      }
    } on PlatformException {
      /* Optional platform feedback. */
    } on MissingPluginException {
      /* Unsupported platforms remain silent. */
    }
  }

  static Future<void> answer({required bool correct}) async {
    await _vibrate(preferences, correct: correct);
    if (correct) await _sound(preferences);
  }

  static Future<void> _sound(AppPreferences? settings) async {
    if (settings?.sound == true) {
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
