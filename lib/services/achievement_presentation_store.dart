import 'package:shared_preferences/shared_preferences.dart';

class AchievementPresentationStore {
  AchievementPresentationStore._();

  static const String _seenUnlocksKey = 'achievement_seen_unlocks_v1';

  static Future<Set<String>> loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_seenUnlocksKey) ?? const <String>[]).toSet();
  }

  static Future<void> markSeen(String id) async {
    final seen = await loadSeenIds();
    if (!seen.add(id)) return;

    final prefs = await SharedPreferences.getInstance();
    final rows = seen.toList()..sort();
    await prefs.setStringList(_seenUnlocksKey, rows);
  }

  static Future<void> markAllSeen(Iterable<String> ids) async {
    final seen = await loadSeenIds();
    var changed = false;

    for (final id in ids) {
      changed = seen.add(id) || changed;
    }

    if (!changed) return;

    final prefs = await SharedPreferences.getInstance();
    final rows = seen.toList()..sort();
    await prefs.setStringList(_seenUnlocksKey, rows);
  }

  static Future<int> unseenCount(Iterable<String> unlockedIds) async {
    final seen = await loadSeenIds();
    var count = 0;

    for (final id in unlockedIds) {
      if (!seen.contains(id)) count += 1;
    }

    return count;
  }
}
