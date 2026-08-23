import '../models/football_calendar_theme.dart';
import '../models/match_entity.dart';
import 'club_name_resolver.dart';
import 'daily_challenge_service.dart';
import 'daily_fixture_service.dart';

/// Gunun oynanabilir eslesmelerinden biri.
class PlayableDailyMatch {
  final String id; // fixtureId veya home-away key
  final MatchEntity entity1;
  final MatchEntity entity2;
  final String label;
  final FootballCalendarTheme theme;
  final bool isDerby;
  final int importance;
  final String leagueName;

  const PlayableDailyMatch({
    required this.id,
    required this.entity1,
    required this.entity2,
    required this.label,
    required this.theme,
    required this.isDerby,
    required this.importance,
    required this.leagueName,
  });
}

class DailyPlayableMatches {
  DailyPlayableMatches._();

  /// RTDB listesinden, veritabaninda eslesen ve yeterli ortak oyuncusu olan maclar.
  static Future<List<PlayableDailyMatch>> forDate(DateTime date) async {
    final day = await DailyFixtureService.fetchDay(date);
    if (day == null || day.matches.isEmpty) {
      // Fallback: tek klasik eslesme
      final fb = DailyChallengeService.getMatchupForDate(date);
      final theme = FootballCalendarTheme.forDate(date);
      return [
        PlayableDailyMatch(
          id: 'fallback-${DailyChallengeService.dateKeyFor(date)}',
          entity1: fb.entity1,
          entity2: fb.entity2,
          label: fb.label,
          theme: theme,
          isDerby: theme.kind == CalendarThemeKind.derbyDay ||
              theme.kind == CalendarThemeKind.derbyCountdown,
          importance: 0,
          leagueName: '',
        ),
      ];
    }

    final out = <PlayableDailyMatch>[];
    final seen = <String>{};

    for (final m in day.matches) {
      final h = ClubNameResolver.resolve(m.homeName);
      final a = ClubNameResolver.resolve(m.awayName);
      if (h == null || a == null || h.id == a.id) continue;

      final e1 = MatchEntity.club(h);
      final e2 = MatchEntity.club(a);
      final q = DailyChallengeService.qualityCountPublic(e1, e2);
      if (q < 3) continue;

      final id = m.fixtureId != null
          ? 'fx-${m.fixtureId}'
          : 'pair-${h.id}-${a.id}';
      if (seen.contains(id)) continue;
      seen.add(id);

      final label =
          m.isDerby ? '${h.name} 🆚 ${a.name}' : '${h.name} × ${a.name}';
      final theme = FootballCalendarTheme.fromFixture(
        isDerby: m.isDerby,
        leagueId: m.leagueId,
        label: label,
      );

      out.add(
        PlayableDailyMatch(
          id: id,
          entity1: e1,
          entity2: e2,
          label: label,
          theme: theme,
          isDerby: m.isDerby,
          importance: m.importance,
          leagueName: m.leagueName,
        ),
      );
    }

    out.sort((a, b) => b.importance.compareTo(a.importance));

    // Hicbiri eslesmezse fallback
    if (out.isEmpty) {
      final fb = DailyChallengeService.getMatchupForDate(date);
      final theme = FootballCalendarTheme.forDate(date);
      return [
        PlayableDailyMatch(
          id: 'fallback-${DailyChallengeService.dateKeyFor(date)}',
          entity1: fb.entity1,
          entity2: fb.entity2,
          label: fb.label,
          theme: theme,
          isDerby: false,
          importance: 0,
          leagueName: '',
        ),
      ];
    }

    // En fazla 8 mac goster (UI)
    if (out.length > 8) return out.sublist(0, 8);
    return out;
  }
}