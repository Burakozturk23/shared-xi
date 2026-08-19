import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/popular_clubs_pool.dart';
import '../data/popular_matchups.dart';
import '../models/football_calendar_theme.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'game_service.dart';

class DailyChallengeService {
  DailyChallengeService._();

  static const _lastPlayedDateKey = 'daily_last_played_date';
  static const _lastScoreKey = 'daily_last_score';
  static const _streakKey = 'daily_streak';
  static const _hintsKey = 'daily_hints';
  static const _badgesKey = 'daily_badges';
  static const _lastSuccessRateKey = 'daily_last_success_rate';
  static const _pointsKey = 'daily_points';
  static const _completedDatesKey = 'daily_completed_dates';
  static const _unlockedDatesKey = 'daily_unlocked_dates';

  static const int unlockCost = 100;
  static const int basePointsReward = 25;

  /// Ortak oyuncu kalite eşiği.
  static const int minQualityCommons = 5;

  static String dateKeyFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays;
  }

  static Random _rngFor(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return Random(seed);
  }

  static FootballCalendarTheme themeFor([DateTime? date]) =>
      FootballCalendarTheme.forDate(date ?? DateTime.now());

  static ({MatchEntity entity1, MatchEntity entity2, String label})
      getMatchupForDate(DateTime date) {
    final theme = themeFor(date);
    final need = max(minQualityCommons, theme.targetFinds);
    final rng = _rngFor(date);

    final themed = _poolForTheme(theme.kind);
    final themedPick = _bestFromCandidates(themed, need, rng);
    if (themedPick != null) return themedPick;

    final allPopular = <({MatchEntity entity1, MatchEntity entity2, String label})>[];
    for (final m in popularClubClubMatchups) {
      final a = Repository.instance.clubById(m.clubId1);
      final b = Repository.instance.clubById(m.clubId2);
      if (a != null && b != null) {
        allPopular.add((
          entity1: MatchEntity.club(a),
          entity2: MatchEntity.club(b),
          label: m.label,
        ));
      }
    }
    final popularPick = _bestFromCandidates(allPopular, need, rng);
    if (popularPick != null) return popularPick;

    final dynamicPick = _pickDynamicPair(need, rng);
    if (dynamicPick != null) return dynamicPick;

    return _fromGlobalPool(date);
  }

  static ({MatchEntity entity1, MatchEntity entity2, String label})?
      _bestFromCandidates(
    List<({MatchEntity entity1, MatchEntity entity2, String label})> pool,
    int need,
    Random rng,
  ) {
    if (pool.isEmpty) return null;

    final scored = <({
      MatchEntity entity1,
      MatchEntity entity2,
      String label,
      int quality,
    })>[];

    for (final m in pool) {
      final q = _qualityCount(m.entity1, m.entity2);
      if (q >= need) {
        scored.add((
          entity1: m.entity1,
          entity2: m.entity2,
          label: m.label,
          quality: q,
        ));
      }
    }

    if (scored.isEmpty) {
      final relaxed = (need * 0.6).ceil().clamp(3, need);
      for (final m in pool) {
        final q = _qualityCount(m.entity1, m.entity2);
        if (q >= relaxed) {
          scored.add((
            entity1: m.entity1,
            entity2: m.entity2,
            label: m.label,
            quality: q,
          ));
        }
      }
    }

    if (scored.isEmpty) return null;

    scored.sort((a, b) => b.quality.compareTo(a.quality));
    final top = scored.take(min(12, scored.length)).toList();
    final pick = top[rng.nextInt(top.length)];
    return (entity1: pick.entity1, entity2: pick.entity2, label: pick.label);
  }

  static int _qualityCount(MatchEntity a, MatchEntity b) {
    var n = 0;
    for (final p in Repository.instance.players) {
      if (!_isQualityPlayer(p)) continue;
      if (!_belongs(p, a) || !_belongs(p, b)) continue;
      n++;
    }
    return n;
  }

  static bool _belongs(Player p, MatchEntity e) {
    switch (e.type) {
      case MatchEntityType.club:
        return p.clubs.contains(e.clubId);
      case MatchEntityType.country:
        return p.countries.contains(e.countryName);
    }
  }

  static bool _isQualityPlayer(Player p) {
    if (p.name.trim().isEmpty) return false;
    if (p.careerGoals >= 10) return true;
    if (p.peakMarketValue >= 2000000) return true;
    if (p.marketValue >= 1000000) return true;
    return p.name.trim().split(RegExp(r'\s+')).length >= 2;
  }

  static ({MatchEntity entity1, MatchEntity entity2, String label})?
      _pickDynamicPair(int need, Random rng) {
    final clubs = PopularClubs.resolveAll();
    if (clubs.length < 2) return null;

    final shuffled = List.of(clubs)..shuffle(rng);
    final limit = min(40, shuffled.length);

    ({MatchEntity entity1, MatchEntity entity2, String label, int q})? best;

    for (var i = 0; i < limit; i++) {
      for (var j = i + 1; j < limit; j++) {
        final a = shuffled[i];
        final b = shuffled[j];
        if (a.id == b.id) continue;
        final e1 = MatchEntity.club(a);
        final e2 = MatchEntity.club(b);
        final q = _qualityCount(e1, e2);
        if (q < need) continue;
        if (best == null || q > best.q) {
          best = (
            entity1: e1,
            entity2: e2,
            label: '${a.name} × ${b.name}',
            q: q,
          );
        }
      }
    }

    if (best == null) return null;
    return (entity1: best.entity1, entity2: best.entity2, label: best.label);
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
              l.contains('juventus') ||
              l.contains('milan') ||
              l.contains('inter') ||
              l.contains('liverpool') ||
              l.contains('chelsea') ||
              l.contains('arsenal') ||
              l.contains('manchester') ||
              l.contains('psg') ||
              l.contains('paris') ||
              l.contains('dortmund') ||
              l.contains('ajax') ||
              l.contains('porto') ||
              l.contains('benfica') ||
              l.contains('atletico') ||
              l.contains('napoli') ||
              l.contains('roma');
        });
      case CalendarThemeKind.derbyCountdown:
      case CalendarThemeKind.derbyDay:
        source = popularClubClubMatchups.where((m) {
          final l = m.label.toLowerCase();
          return l.contains('galatasaray') ||
              l.contains('fenerbahçe') ||
              l.contains('fenerbahce') ||
              l.contains('beşiktaş') ||
              l.contains('besiktas') ||
              l.contains('trabzon') ||
              l.contains('madrid') ||
              l.contains('barcelona') ||
              l.contains('milan') ||
              l.contains('inter') ||
              l.contains('liverpool') ||
              l.contains('everton') ||
              l.contains('arsenal') ||
              l.contains('tottenham') ||
              l.contains('manchester') ||
              l.contains('roma') ||
              l.contains('lazio') ||
              l.contains('dortmund') ||
              l.contains('schalke') ||
              l.contains('celtic') ||
              l.contains('rangers');
        });
      case CalendarThemeKind.weekSummary:
        source = popularClubClubMatchups;
    }

    for (final m in source) {
      final a = Repository.instance.clubById(m.clubId1 as int);
      final b = Repository.instance.clubById(m.clubId2 as int);
      if (a != null && b != null) {
        out.add((
          entity1: MatchEntity.club(a),
          entity2: MatchEntity.club(b),
          label: m.label as String,
        ));
      }
    }
    return out;
  }

  static ({MatchEntity entity1, MatchEntity entity2, String label})
      _fromGlobalPool(DateTime date) {
    final clubs = PopularClubs.resolveAll();
    if (clubs.length >= 2) {
      final rng = _rngFor(date);
      final a = clubs[rng.nextInt(clubs.length)];
      var b = clubs[rng.nextInt(clubs.length)];
      var guard = 0;
      while (b.id == a.id && guard < 20) {
        b = clubs[rng.nextInt(clubs.length)];
        guard++;
      }
      return (
        entity1: MatchEntity.club(a),
        entity2: MatchEntity.club(b),
        label: '${a.name} × ${b.name}',
      );
    }

    final all = Repository.instance.clubs;
    if (all.isEmpty) {
      throw StateError('No clubs in repository');
    }
    if (all.length < 2) {
      return (
        entity1: MatchEntity.club(all.first),
        entity2: MatchEntity.club(all.first),
        label: all.first.name,
      );
    }
    final i = (date.year * 1000 + _dayOfYear(date)) % all.length;
    final j = (i + 7 + _dayOfYear(date)) % all.length;
    final jj = j == i ? (j + 1) % all.length : j;
    return (
      entity1: MatchEntity.club(all[i]),
      entity2: MatchEntity.club(all[jj]),
      label: '${all[i].name} × ${all[jj].name}',
    );
  }

  /// Ortak oyuncular — kaliteli isimler önde.
  static List<Player> qualityMatchingPlayers({
    required MatchEntity entity1,
    required MatchEntity entity2,
  }) {
    final raw = GameService.matchingPlayers(
      players: Repository.instance.players,
      entity1: entity1,
      entity2: entity2,
    );
    final quality = raw.where(_isQualityPlayer).toList();
    quality.sort((a, b) {
      final ga = a.careerGoals;
      final gb = b.careerGoals;
      if (gb != ga) return gb.compareTo(ga);
      return b.peakMarketValue.compareTo(a.peakMarketValue);
    });
    return quality.isNotEmpty ? quality : raw;
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