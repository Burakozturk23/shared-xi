import 'package:flutter/services.dart';

import 'app_preferences.dart';
import 'game_audio.dart';

/// Preference-aware feedback. Unsupported hardware never blocks gameplay.
class AppFeedback {
  static AppPreferences? preferences;
  static Future<void> selection() {
    GameAudio.instance?.play(Sfx.uiTap);
    return _vibrate(preferences, selection: true);
  }

  /// Pack effects for verified events. Callers invoke these only after the
  /// server/controller confirmed the result (coin and XP after the ledger).
  static void sfx(Sfx sound, {String? eventId}) => GameAudio.instance?.play(sound, eventId: eventId);
  static void hint() => sfx(Sfx.hintReveal);

  /// Server-granted reward: same haptic as a correct answer with its own cue.
  static Future<void> reward(Sfx sound) async {
    await _vibrate(preferences);
    final audio = GameAudio.instance;
    if (audio != null) {
      audio.play(sound);
    } else {
      await _sound(preferences);
    }
  }

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
    final audio = GameAudio.instance;
    if (audio != null) {
      audio.play(correct ? Sfx.answerCorrect : Sfx.answerWrong);
    } else if (correct) {
      await _sound(preferences);
    }
  }

  static Future<void> _sound(AppPreferences? settings) async {
    final audio = GameAudio.instance;
    if (audio != null) {
      if (settings?.sound == true) audio.play(Sfx.answerCorrect, force: true);
      return;
    }
    // Without the audio engine (tests, unsupported hosts) keep the system click.
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
