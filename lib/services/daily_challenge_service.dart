import 'package:shared_preferences/shared_preferences.dart';

import '../data/popular_matchups.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';

class DailyChallengeService {
  DailyChallengeService._();

  static const _lastPlayedDateKey = 'daily_last_played_date';
  static const _lastScoreKey = 'daily_last_score';
  static const _streakKey = 'daily_streak';

  static String _dateKeyFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays;
  }

  /// Bugünün eşleşmesi — tarihe göre sabit, herkes için aynı.
  static ({MatchEntity entity1, MatchEntity entity2, String label})
      getTodayMatchup() {
    final now = DateTime.now();

    final pool =
        <({String label, MatchEntity entity1, MatchEntity entity2})>[];

    for (final m in popularClubClubMatchups) {
      final a = Repository.instance.clubById(m.clubId1);
      final b = Repository.instance.clubById(m.clubId2);
      if (a != null && b != null) {
        pool.add((
          label: m.label,
          entity1: MatchEntity.club(a),
          entity2: MatchEntity.club(b),
        ));
      }
    }

    for (final m in popularClubCountryMatchups) {
      final club = Repository.instance.clubById(m.clubId);
      if (club != null) {
        pool.add((
          label: m.label,
          entity1: MatchEntity.club(club),
          entity2: MatchEntity.country(m.country),
        ));
      }
    }

    final index = (now.year * 1000 + _dayOfYear(now)) % pool.length;
    final chosen = pool[index];

    return (
      entity1: chosen.entity1,
      entity2: chosen.entity2,
      label: chosen.label,
    );
  }

  static Future<bool> isCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPlayed = prefs.getString(_lastPlayedDateKey);
    return lastPlayed == _dateKeyFor(DateTime.now());
  }

  static Future<int> getLastScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastScoreKey) ?? 0;
  }

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  static Future<int> recordCompletion(int score) async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now();
    final todayStr = _dateKeyFor(today);
    final yesterdayStr = _dateKeyFor(today.subtract(const Duration(days: 1)));

    final lastPlayed = prefs.getString(_lastPlayedDateKey);
    final currentStreak = prefs.getInt(_streakKey) ?? 0;

    int newStreak;
    if (lastPlayed == yesterdayStr) {
      newStreak = currentStreak + 1;
    } else if (lastPlayed == todayStr) {
      newStreak = currentStreak;
    } else {
      newStreak = 1;
    }

    await prefs.setString(_lastPlayedDateKey, todayStr);
    await prefs.setInt(_lastScoreKey, score);
    await prefs.setInt(_streakKey, newStreak);

    return newStreak;
  }
}