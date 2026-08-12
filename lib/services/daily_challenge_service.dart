import 'package:shared_preferences/shared_preferences.dart';

import '../data/popular_matchups.dart';
import '../models/football_calendar_theme.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';

class DailyChallengeService {
  DailyChallengeService._();

  static const _lastPlayedDateKey = 'daily_last_played_date';
  static const _lastScoreKey = 'daily_last_score';
  static const _streakKey = 'daily_streak';
  static const _hintsKey = 'daily_hints';
  static const _badgesKey = 'daily_badges';
  static const _lastSuccessRateKey = 'daily_last_success_rate';
  static const _pointsKey = 'daily_points';
  static const _completedDatesKey = 'daily_completed_dates'; // "yyyy-MM-dd:score,..."
  static const _unlockedDatesKey = 'daily_unlocked_dates'; // "yyyy-MM-dd,..."

  /// Telafi: geçmiş günü açmak için puan maliyeti.
  static const int unlockCost = 100;

  /// Mücadele bitince verilen taban puan.
  static const int basePointsReward = 25;

  static String dateKeyFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays;
  }

  static FootballCalendarTheme themeFor([DateTime? date]) =>
      FootballCalendarTheme.forDate(date ?? DateTime.now());

  /// Belirli bir günün eşleşmesi (bugün veya geçmiş arşiv).
  static ({MatchEntity entity1, MatchEntity entity2, String label})
      getMatchupForDate(DateTime date) {
    final theme = themeFor(date);
    final pool = _poolForTheme(theme.kind);

    if (pool.isEmpty) {
      return _fromGlobalPool(date);
    }

    final index = (date.year * 1000 + _dayOfYear(date)) % pool.length;
    return pool[index];
  }

  static ({MatchEntity entity1, MatchEntity entity2, String label})
      getTodayMatchup([DateTime? date]) =>
          getMatchupForDate(date ?? DateTime.now());

  static List<({MatchEntity entity1, MatchEntity entity2, String label})>
      _poolForTheme(CalendarThemeKind kind) {
    final out =
        <({MatchEntity entity1, MatchEntity entity2, String label})>[];

    Iterable source;
    switch (kind) {
      case CalendarThemeKind.europeNight:
        source = popularClubClubMatchups.where((m) {
          final l = m.label.toLowerCase();
          return l.contains('madrid') ||
              l.contains('barcelona') ||
              l.contains('bayern') ||
              l.contains('liverpool') ||
              l.contains('milan') ||
              l.contains('juventus') ||
              l.contains('psg') ||
              l.contains('city') ||
              l.contains('chelsea') ||
              l.contains('arsenal') ||
              l.contains('inter') ||
              l.contains('dortmund');
        });
        break;
      case CalendarThemeKind.derbyCountdown:
      case CalendarThemeKind.derbyDay:
        source = popularClubClubMatchups.where((m) {
          final l = m.label.toLowerCase();
          return l.contains('derbi') ||
              l.contains('derby') ||
              l.contains('fener') ||
              l.contains('galata') ||
              l.contains('beşiktaş') ||
              l.contains('besiktas') ||
              l.contains('madrid') ||
              l.contains('milan') ||
              l.contains('manchester') ||
              l.contains('liverpool') ||
              l.contains('arsenal') ||
              l.contains('inter') ||
              l.contains('roma');
        });
        break;
      case CalendarThemeKind.weekSummary:
        for (final m in popularClubCountryMatchups) {
          final club = Repository.instance.clubById(m.clubId);
          if (club != null) {
            out.add((
              label: m.label,
              entity1: MatchEntity.club(club),
              entity2: MatchEntity.country(m.country),
            ));
          }
        }
        source = popularClubClubMatchups;
        break;
    }

    for (final m in source) {
      final a = Repository.instance.clubById(m.clubId1);
      final b = Repository.instance.clubById(m.clubId2);
      if (a != null && b != null) {
        out.add((
          label: m.label,
          entity1: MatchEntity.club(a),
          entity2: MatchEntity.club(b),
        ));
      }
    }
    return out;
  }

  static ({MatchEntity entity1, MatchEntity entity2, String label})
      _fromGlobalPool(DateTime date) {
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
    final index = (date.year * 1000 + _dayOfYear(date)) % pool.length;
    final c = pool[index];
    return (entity1: c.entity1, entity2: c.entity2, label: c.label);
  }

  // ── Persistence helpers ──────────────────────────────────────────

  static Future<bool> isCompletedOn(DateTime date) async {
    final map = await _completedMap();
    return map.containsKey(dateKeyFor(date));
  }

  static Future<bool> isCompletedToday() => isCompletedOn(DateTime.now());

  static Future<Map<String, int>> _completedMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_completedDatesKey) ?? '';
    final map = <String, int>{};
    if (raw.isEmpty) return map;
    for (final part in raw.split(',')) {
      final bits = part.split(':');
      if (bits.length == 2) {
        map[bits[0]] = int.tryParse(bits[1]) ?? 0;
      }
    }
    return map;
  }

  static Future<void> _saveCompletedMap(Map<String, int> map) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        map.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_completedDatesKey, raw);
  }

  static Future<Set<String>> _unlockedSet() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unlockedDatesKey) ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  static Future<void> _saveUnlocked(Set<String> set) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unlockedDatesKey, set.join(','));
  }

  /// Geçmiş gün oynanabilir mi?
  /// - Bugün her zaman serbest
  /// - Tamamlanmış günler sonuç için açılır
  /// - Telafi ile unlock edilmiş günler serbest
  /// - Dün streak için ücretsiz bakılabilir (oynamak için unlock gerekir)
  static Future<bool> canPlay(DateTime date) async {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    if (d.isAfter(t)) return false; // gelecek
    if (d == t) return true;
    if (await isCompletedOn(d)) return true; // sonuç gör
    final unlocked = await _unlockedSet();
    return unlocked.contains(dateKeyFor(d));
  }

  static Future<bool> isUnlocked(DateTime date) async {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    if (d == t) return true;
    if (await isCompletedOn(d)) return true;
    final unlocked = await _unlockedSet();
    return unlocked.contains(dateKeyFor(d));
  }

  /// Puanla geçmiş günü aç (telafi).
  static Future<({bool ok, String message})> unlockDate(DateTime date) async {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    if (!d.isBefore(t)) {
      return (ok: false, message: 'Sadece geçmiş günler açılabilir.');
    }
    if (await isUnlocked(d)) {
      return (ok: false, message: 'Bu gün zaten açık.');
    }

    final points = await getPoints();
    if (points < unlockCost) {
      return (
        ok: false,
        message: 'Yetersiz puan ($points / $unlockCost). Mücadele tamamlayarak puan kazan.'
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, points - unlockCost);
    final unlocked = await _unlockedSet()..add(dateKeyFor(d));
    await _saveUnlocked(unlocked);
    return (ok: true, message: 'Gün açıldı! -$unlockCost puan.');
  }

  static Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  static Future<int> getLastScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastScoreKey) ?? 0;
  }

  static Future<double> getLastSuccessRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_lastSuccessRateKey) ?? 0;
  }

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  static Future<int> getHints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hintsKey) ?? 0;
  }

  static Future<Set<String>> getBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_badgesKey) ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  /// Tamamlama kaydı. [playDate] arşiv günü için.
  static Future<({int streak, Set<String> newBadges, int hints, int points})>
      recordCompletion({
    required int score,
    required double successRate,
    required FootballCalendarTheme theme,
    DateTime? playDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final day = playDate ?? DateTime.now();
    final dayStr = dateKeyFor(day);
    final todayStr = dateKeyFor(DateTime.now());
    final isToday = dayStr == todayStr;

    // completed map
    final completed = await _completedMap();
    final alreadyDone = completed.containsKey(dayStr);
    completed[dayStr] = score;
    await _saveCompletedMap(completed);

    // streak sadece bugün ilk tamamlamada
    final lastPlayed = prefs.getString(_lastPlayedDateKey);
    final currentStreak = prefs.getInt(_streakKey) ?? 0;
    final yesterdayStr =
        dateKeyFor(DateTime.now().subtract(const Duration(days: 1)));

    int newStreak = currentStreak;
    if (isToday && !alreadyDone) {
      if (lastPlayed == yesterdayStr) {
        newStreak = currentStreak + 1;
      } else if (lastPlayed == todayStr) {
        newStreak = currentStreak;
      } else {
        newStreak = 1;
      }
      await prefs.setString(_lastPlayedDateKey, todayStr);
      await prefs.setInt(_streakKey, newStreak);
      await prefs.setInt(_lastScoreKey, score);
      await prefs.setDouble(_lastSuccessRateKey, successRate);
    }

    var hints = prefs.getInt(_hintsKey) ?? 0;
    final badges = await getBadges();
    final newBadges = <String>{};

    if (isToday && !alreadyDone && newStreak > 0 && newStreak % 7 == 0) {
      if (!badges.contains('sadik_taktisyen')) {
        newBadges.add('sadik_taktisyen');
      }
      hints += 5;
    }

    if (successRate >= 0.80 &&
        (theme.kind == CalendarThemeKind.derbyDay ||
            theme.kind == CalendarThemeKind.derbyCountdown)) {
      if (!badges.contains('derbi_uzmani')) {
        newBadges.add('derbi_uzmani');
      }
    }

    // Puan ödülü (tekrar oynamada verme)
    var points = prefs.getInt(_pointsKey) ?? 0;
    if (!alreadyDone) {
      final bonus = (successRate * 50).round(); // 0–50
      points += basePointsReward + bonus + score * 5;
      await prefs.setInt(_pointsKey, points);
    }

    final allBadges = {...badges, ...newBadges};
    await prefs.setInt(_hintsKey, hints);
    await prefs.setString(_badgesKey, allBadges.join(','));

    return (
      streak: newStreak,
      newBadges: newBadges,
      hints: hints,
      points: points,
    );
  }

  static Future<bool> consumeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hints = prefs.getInt(_hintsKey) ?? 0;
    if (hints <= 0) return false;
    await prefs.setInt(_hintsKey, hints - 1);
    return true;
  }

  /// Paylaşım metni (API / share_plus olmadan panoya kopyalanabilir).
  static String buildShareText({
    required String label,
    required int score,
    required double successRate,
    required int streak,
  }) {
    final pct = (successRate * 100).round();
    return 'Shared XI — Günün Mücadelesi\n'
        '$label\n'
        'Skor: $score doğru · %$pct başarı\n'
        'Seri: $streak gün 🔥\n'
        'Sen kaç yapabilirsin?';
  }
}