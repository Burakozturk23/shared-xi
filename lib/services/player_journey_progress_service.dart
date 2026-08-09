import 'package:shared_preferences/shared_preferences.dart';

class PlayerJourneyProgressService {
  static const String _completedKey = 'player_journey_completed_ids';

  static Future<Set<String>> getCompletedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_completedKey) ?? const [];
    return list.toSet();
  }

  static Future<void> markCompleted(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_completedKey) ?? <String>[];
    if (current.contains(journeyId)) return;
    current.add(journeyId);
    await prefs.setStringList(_completedKey, current);
  }

  static Future<bool> isCompleted(String journeyId) async {
    final ids = await getCompletedIds();
    return ids.contains(journeyId);
  }

  static Future<bool> isUnlocked({
    required List<String> orderedJourneyIds,
    required int index,
  }) async {
    if (index <= 0) return true;
    final completed = await getCompletedIds();
    for (var i = 0; i < index; i++) {
      if (!completed.contains(orderedJourneyIds[i])) return false;
    }
    return true;
  }
}