import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local practice records only. Previous star saves stay intact as history;
/// they never become client-authorized money or entitlements.
class SquadChallengeProgressService {
  SquadChallengeProgressService();
  static final instance = SquadChallengeProgressService();
  static const _key = 'sc_practice_records_v2';
  Future<void> _tail = Future.value();

  Future<Map<String, int>> records() async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
  }

  Future<int> legacyCompletedThemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith('sc_stars_') && (prefs.getInt(k) ?? 0) > 0)
        .length;
  }

  Future<void> saveScore(String themeId, int score) {
    final next = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final rows = raw == null
          ? <String, int>{}
          : (jsonDecode(raw) as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            );
      if (score > (rows[themeId] ?? -1)) {
        rows[themeId] = score;
        if (!await prefs.setString(_key, jsonEncode(rows)))
          throw StateError('Rekor kaydedilemedi.');
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}
