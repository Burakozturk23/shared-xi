import 'dart:math';

import '../data/manager_league_clubs.dart';
import '../models/manager_league_club.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import '../models/manager_tactics.dart';

class ManagerSeasonService {
  ManagerSeasonService({Random? random}) : _rng = random ?? Random();
  static final instance = ManagerSeasonService();
  final Random _rng;

  /// The league's opponents are real popular clubs, rated by their best known XI of
  /// every era (as the player's own squad is drafted). Most ratings bunch between 84
  /// and 89, so a club's strength is its rank spread evenly over the band the
  /// made-up clubs used (55-85, average 70): the balance stays and the order is
  /// real, Barcelona 85 and Rangers near 55. Equal ratings share a strength.
  static double strengthOf(ManagerLeagueClub club) {
    final rank = managerLeagueClubs.indexWhere((c) => c.rating == club.rating);
    return 85 - rank * 30 / (managerLeagueClubs.length - 1);
  }

  static final Map<int, ManagerLeagueClub> _clubs = {
    for (final c in managerLeagueClubs) c.id: c,
  };
  static ManagerLeagueClub? clubOf(SeasonClub c) => leagueClub(c.clubId);
  static ManagerLeagueClub? leagueClub(int? id) =>
      id == null ? null : _clubs[id];

  ManagerSeason createSeason({
    String userName = 'Senin XI',
    ManagerDifficulty difficulty = ManagerDifficulty.medium,
  }) {
    final picks = List<ManagerLeagueClub>.from(managerLeagueClubs)
      ..shuffle(_rng);
    final offset = switch (difficulty) {
      ManagerDifficulty.easy => -5.0,
      ManagerDifficulty.medium => 0.0,
      ManagerDifficulty.hard => 5.0,
    };
    final clubs = [
      SeasonClub(
        id: 'user',
        name: userName,
        leagueHint: 'Ortak Saha Ligi',
        style: OpponentStyle.balanced,
        strength: 70,
        isUser: true,
      ),
      for (var i = 0; i < ManagerSeason.opponentCount; i++)
        SeasonClub(
          id: 'opp_$i',
          name: picks[i].name,
          leagueHint: picks[i].league,
          clubId: picks[i].id,
          style:
              OpponentStyle.values[_rng.nextInt(OpponentStyle.values.length)],
          strength: (strengthOf(picks[i]) + offset).roundToDouble(),
        ),
    ];
    // Circle method: 19 rounds, each unordered pair exactly once.
    final rotation = clubs.map((c) => c.id).toList()..shuffle(_rng);
    final firstLeg = <LeagueFixture>[];
    for (var round = 0; round < ManagerSeason.opponentCount; round++) {
      for (var pair = 0; pair < ManagerSeason.teamCount ~/ 2; pair++) {
        final a = rotation[pair];
        final b = rotation[rotation.length - 1 - pair];
        final flip = pair == 0 ? round.isOdd : pair.isOdd;
        firstLeg.add(
          LeagueFixture(
            week: round + 1,
            homeId: flip ? b : a,
            awayId: flip ? a : b,
          ),
        );
      }
      rotation.insert(1, rotation.removeLast());
    }
    final matches = [
      ...firstLeg,
      for (final f in firstLeg)
        LeagueFixture(
          week: f.week + ManagerSeason.opponentCount,
          homeId: f.awayId,
          awayId: f.homeId,
        ),
    ];
    final fixtures = [
      for (final f in matches)
        if (f.homeId == 'user' || f.awayId == 'user')
          SeasonFixture(
            week: f.week,
            opponentId: f.homeId == 'user' ? f.awayId : f.homeId,
            isHome: f.homeId == 'user',
          ),
    ];
    return ManagerSeason(
      id: 'cm-${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 30)}',
      clubs: clubs,
      fixtures: fixtures,
      leagueFixtures: matches,
    );
  }

  ManagerSeason applyUserResult(
    ManagerSeason season, {
    required String opponentId,
    required int userGoals,
    required int oppGoals,
    int? expectedWeek,
  }) {
    final next = season.nextFixture;
    if (!season.isCurrentFormat ||
        next == null ||
        next.opponentId != opponentId ||
        (expectedWeek != null && next.week != expectedWeek)) {
      throw StateError('Bu maç artık sıradaki maç değil.');
    }
    if (userGoals < 0 || oppGoals < 0) {
      throw ArgumentError('Gol sayısı negatif olamaz.');
    }
    final clubs = season.clubs
        .map((c) => SeasonClub.fromJson(c.toJson()))
        .toList();
    final byId = {for (final c in clubs) c.id: c};
    final matches = <LeagueFixture>[];
    for (final f in season.leagueFixtures) {
      if (f.week != next.week) {
        matches.add(f);
        continue;
      }
      if (f.played) throw StateError('Bu haftanın sonucu zaten kaydedildi.');
      final home = byId[f.homeId]!;
      final away = byId[f.awayId]!;
      final int h, a;
      if (home.isUser) {
        h = userGoals;
        a = oppGoals;
      } else if (away.isUser) {
        h = oppGoals;
        a = userGoals;
      } else {
        final diff = home.strength + 3 - away.strength;
        h = _goals((1.35 + diff * .035).clamp(.25, 3.5));
        a = _goals((1.15 - diff * .035).clamp(.25, 3.5));
      }
      _applyResult(home, away, h, a);
      matches.add(f.withResult(h, a));
    }
    return ManagerSeason(
      id: season.id,
      clubs: clubs,
      leagueFixtures: matches,
      currentWeek: next.week + 1,
      fixtures: [
        for (final f in season.fixtures)
          f.week == next.week
              ? f.copyWith(
                  played: true,
                  userGoals: userGoals,
                  oppGoals: oppGoals,
                )
              : f,
      ],
    );
  }

  int _goals(double xg) {
    var goals = 0;
    for (var i = 0; i < 8; i++) {
      if (_rng.nextDouble() < xg / 8) goals++;
    }
    return goals;
  }

  void _applyResult(SeasonClub a, SeasonClub b, int ga, int gb) {
    a.played++;
    b.played++;
    a.gf += ga;
    a.ga += gb;
    b.gf += gb;
    b.ga += ga;
    if (ga > gb) {
      a.won++;
      a.points += 3;
      b.lost++;
    } else if (ga < gb) {
      b.won++;
      b.points += 3;
      a.lost++;
    } else {
      a.drawn++;
      b.drawn++;
      a.points++;
      b.points++;
    }
  }

  ManagerOpponent toOpponent(SeasonClub c) => ManagerOpponent(
    name: c.name,
    leagueHint: c.leagueHint,
    style: c.style,
    basePower: c.strength,
    forwards: clubOf(c)?.forwards ?? const [],
    midfielders: clubOf(c)?.midfielders ?? const [],
    clubId: clubOf(c)?.id,
  );
}
