import 'dart:async';

import 'package:flutter/services.dart';

import 'app_preferences.dart';
import 'game_audio.dart';

/// Preference-aware feedback. Unsupported hardware never blocks gameplay.
class AppFeedback {
  static AppPreferences? preferences;

  /// Clock for the one-pulse-per-event rule (tests replace it).
  static DateTime Function() clock = DateTime.now;

  /// A reward right after an answer belongs to the same event: one haptic.
  static const sameEvent = Duration(milliseconds: 300);

  /// Gap between the two short pulses of a wrong answer.
  static const wrongGap = Duration(milliseconds: 90);
  static DateTime? _lastPulse;
  static Future<void> selection() {
    GameAudio.instance?.play(Sfx.uiTap);
    return _vibrate(preferences, selection: true);
  }

  /// Pack effects for verified events. Callers invoke these only after the
  /// server/controller confirmed the result (coin and XP after the ledger).
  static void sfx(Sfx sound, {String? eventId}) =>
      GameAudio.instance?.play(sound, eventId: eventId);
  static void hint() => sfx(Sfx.hintReveal);

  /// Server-granted reward: same haptic as a correct answer with its own cue.
  /// Right after an answer (same event) the haptic is skipped; the cue still plays.
  static Future<void> reward(Sfx sound) async {
    await _vibrate(preferences, skipIfRecent: true);
    final audio = GameAudio.instance;
    if (audio != null) {
      audio.play(sound);
    } else {
      await _sound(preferences);
    }
  }

  /// Gap between the coin (or streak) cue and the XP cue that follows it.
  static const xpDelay = Duration(milliseconds: 450);

  /// A confirmed grant: level-up, a continuing streak or coins play first;
  /// earned XP follows with its own cue (skipped on level-up, which covers it).
  static Future<void> earned({
    int coins = 0,
    int xp = 0,
    bool streak = false,
    bool levelUp = false,
  }) async {
    if (coins <= 0 && xp <= 0 && !levelUp) return;
    final first = levelUp
        ? Sfx.levelUp
        : streak
        ? Sfx.streak
        : coins > 0
        ? Sfx.coinReward
        : Sfx.xpReward;
    await reward(first);
    if (xp > 0 &&
        first != Sfx.xpReward &&
        !levelUp &&
        GameAudio.instance != null) {
      Timer(xpDelay, () => GameAudio.instance?.play(Sfx.xpReward));
    }
  }

  /// Gap between the right and the wrong pattern in the settings preview.
  static const previewGap = Duration(milliseconds: 450);

  /// "Titreşimi dene": the right-answer pulse, then the wrong-answer double.
  static Future<void> previewHaptics(AppPreferences settings) async {
    if (settings.haptics != true) return;
    await _vibrate(settings);
    await Future<void>.delayed(previewGap);
    await _vibrate(settings, correct: false);
  }

  static Future<void> previewSound(AppPreferences settings) => _sound(settings);

  /// One pulse of the chosen strength (taps stay a selection click).
  static Future<void> _pulse(
    HapticStrength strength, {
    bool selection = false,
  }) => selection
      ? HapticFeedback.selectionClick()
      : switch (strength) {
          HapticStrength.gentle => HapticFeedback.selectionClick(),
          HapticStrength.standard => HapticFeedback.lightImpact(),
          HapticStrength.strong => HapticFeedback.heavyImpact(),
        };

  /// Correct: one pulse. Wrong: two short pulses at every strength, so the
  /// result is felt without looking (Hafif, Standart and Güçlü alike).
  static Future<void> _vibrate(
    AppPreferences? settings, {
    bool selection = false,
    bool correct = true,
    bool skipIfRecent = false,
  }) async {
    if (settings?.haptics != true) return;
    final now = clock();
    if (skipIfRecent &&
        _lastPulse != null &&
        now.difference(_lastPulse!) < sameEvent) {
      return;
    }
    if (!selection) _lastPulse = now;
    try {
      final strength = settings!.hapticStrength;
      await _pulse(strength, selection: selection);
      if (!selection && !correct) {
        await Future<void>.delayed(wrongGap);
        await _pulse(strength);
      }
    } on PlatformException {
      /* Optional platform feedback. */
    } on MissingPluginException {
      /* Unsupported platforms remain silent. */
    }
  }

  static Future<void> answer({required bool correct}) async {
    // Sound first: the second pulse of a wrong answer must not delay the cue.
    final audio = GameAudio.instance;
    if (audio != null) {
      audio.play(correct ? Sfx.answerCorrect : Sfx.answerWrong);
    } else if (correct) {
      await _sound(preferences);
    }
    await _vibrate(preferences, correct: correct);
  }

  /// Answer feedback from a server session before and after an action, for
  /// modes that only return the new session: a higher `wrong` count or fewer
  /// `lives` is a wrong answer; a higher `correct` / `score` / `streak` count or
  /// a newly `found` target is a right one. Anything else (hints, navigation)
  /// stays silent. Returns the result it played, or null.
  static bool? answerFrom(Map? before, Map? after) {
    if (before == null || after == null || after.isEmpty) return null;
    if (before['id'] != null && after['id'] != before['id']) return null;
    int n(Object? v) => v is num ? v.toInt() : 0;
    bool more(String key) => n(after[key]) > n(before[key]);
    final wrong = more('wrong') || n(after['lives']) < n(before['lives']);
    final right =
        more('correct') ||
        more('score') ||
        more('streak') ||
        (after['found'] == true && before['found'] != true);
    if (!wrong && !right) return null;
    unawaited(answer(correct: !wrong));
    return !wrong;
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
