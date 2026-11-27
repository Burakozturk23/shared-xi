import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'energy_service.dart';

/// Wakes cold server functions ahead of play (Isınma). With few players each game
/// function sleeps after a quiet spell and its next call waits for a fresh start;
/// a `{warm: true}` call opens the function and its catalog without touching
/// account data, while the player is still choosing. Fire-and-forget: failures
/// are ignored, and each function is woken at most once per [window].
class WarmUp {
  WarmUp._();

  static const window = Duration(minutes: 10);
  static final Map<String, DateTime> _last = {};

  /// Test hook; the default calls the real callable.
  static Future<void> Function(String name)? caller;
  static DateTime Function() now = DateTime.now;

  /// Every solo mode's first call (status), woken when the games catalog opens.
  static const menu = [
    'getBotSupport', 'getGridSupport', 'getArcade', 'getChoice', 'getCareerTransfer', 'getMysteryChain',
    'getThreeMode', 'getFakeClub', 'getDailyWords', 'getMySquadChallenge',
  ];

  static void functions(Iterable<String> names) {
    final time = now();
    for (final name in names) {
      final last = _last[name];
      if (last != null && time.difference(last) < window) continue;
      _last[name] = time;
      unawaited(_call(name));
    }
  }

  static Future<void> _call(String name) async {
    try {
      final hook = caller;
      if (hook != null) return await hook(name);
      // Widget tests run without Firebase: nothing to wake.
      if (Firebase.apps.isEmpty) return;
      await EnergyService().call(name, {'warm': true});
    } catch (_) {
      // A missed warm-up only means the first move starts cold, as before.
    }
  }

  static void reset() => _last.clear();
}
