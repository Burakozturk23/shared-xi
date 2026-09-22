import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/models/manager_season.dart';
import 'package:shared_xi/services/manager_season_service.dart';

void main() {
  test('20 teams play 38 balanced weeks; every ordered pair plays once', () {
    for (var seed = 0; seed < 30; seed++) {
      final season = ManagerSeasonService(random: Random(seed)).createSeason();
      expect(season.clubs.length, 20);
      expect(season.clubs.map((c) => c.id).toSet().length, 20);
      expect(season.clubs.map((c) => c.name).toSet().length, 20);
      expect(season.fixtures.length, 38);
      expect(season.fixtures.map((f) => f.opponentId).toSet().length, 19);
      expect(
        season.fixtures.take(19).map((f) => f.opponentId).toSet().length,
        19,
      );
      expect(season.fixtures.where((f) => f.isHome).length, 19);
      expect(
        season.fixtures.map((f) => f.week),
        List.generate(38, (i) => i + 1),
      );
      expect(season.leagueFixtures.length, 380);
      expect(
        season.leagueFixtures
            .map((f) => '${f.homeId}:${f.awayId}')
            .toSet()
            .length,
        380,
      );
      for (var week = 1; week <= 38; week++) {
        final fixtures = season.matchesInWeek(week);
        expect(fixtures.length, 10);
        expect(
          {
            for (final f in fixtures) ...[f.homeId, f.awayId],
          }.length,
          20,
        );
        expect(fixtures.any((f) => f.homeId == f.awayId), isFalse);
        final userMatch = fixtures.singleWhere(
          (f) => f.homeId == season.user.id || f.awayId == season.user.id,
        );
        final own = season.fixtures[week - 1];
        expect(own.isHome, userMatch.homeId == season.user.id);
        expect(
          own.opponentId,
          own.isHome ? userMatch.awayId : userMatch.homeId,
        );
      }
      for (final club in season.clubs) {
        final home = season.leagueFixtures.where((f) => f.homeId == club.id);
        expect(home.length, 19);
        expect(home.where((f) => f.week <= 19).length, inInclusiveRange(9, 10));
      }
      for (var i = 0; i < 19; i++) {
        expect(
          season.fixtures[i].opponentId,
          season.fixtures[i + 19].opponentId,
        );
        expect(season.fixtures[i].isHome, !season.fixtures[i + 19].isHome);
      }
    }
  });

  test(
    'All 380 results agree with the final table and preserve source state',
    () {
      final service = ManagerSeasonService(random: Random(91));
      final original = service.createSeason();
      var season = original;
      for (var week = 1; week <= 38; week++) {
        final fixture = season.nextFixture!;
        season = service.applyUserResult(
          season,
          opponentId: fixture.opponentId,
          expectedWeek: week,
          userGoals: week % 4,
          oppGoals: week % 3,
        );
        expect(season.clubs.every((c) => c.played == week), isTrue);
        expect(season.leagueFixtures.where((f) => f.played).length, week * 10);
        expect(season.currentWeek, week + 1);
      }
      expect(original.clubs.every((c) => c.played == 0), isTrue);
      expect(original.leagueFixtures.any((f) => f.played), isFalse);
      expect(season.isComplete, isTrue);
      expect(season.nextFixture, isNull);
      for (final club in season.clubs) {
        var points = 0, goals = 0, conceded = 0, wins = 0, draws = 0;
        for (final f in season.leagueFixtures) {
          if (f.homeId != club.id && f.awayId != club.id) continue;
          final own = f.homeId == club.id ? f.homeGoals! : f.awayGoals!;
          final other = f.homeId == club.id ? f.awayGoals! : f.homeGoals!;
          goals += own;
          conceded += other;
          if (own > other) {
            points += 3;
            wins++;
          }
          if (own == other) {
            points++;
            draws++;
          }
        }
        expect(club.points, points);
        expect(club.gf, goals);
        expect(club.ga, conceded);
        expect(club.won, wins);
        expect(club.drawn, draws);
        expect(club.won + club.drawn + club.lost, 38);
      }
      expect(
        season.clubs.fold<int>(0, (sum, c) => sum + c.gf),
        season.clubs.fold<int>(0, (sum, c) => sum + c.ga),
      );
      final restored = ManagerSeason.fromJson(
        jsonDecode(jsonEncode(season.toJson())),
      );
      expect(jsonEncode(restored.toJson()), jsonEncode(season.toJson()));
      expect(
        () => service.applyUserResult(
          season,
          opponentId: original.fixtures.first.opponentId,
          userGoals: 1,
          oppGoals: 0,
        ),
        throwsStateError,
      );
    },
  );

  test('Out-of-order, stale-week and negative scores are rejected', () {
    final service = ManagerSeasonService(random: Random(7));
    final season = service.createSeason();
    expect(
      () => service.applyUserResult(
        season,
        opponentId: season.fixtures[1].opponentId,
        userGoals: 1,
        oppGoals: 0,
      ),
      throwsStateError,
    );
    expect(
      () => service.applyUserResult(
        season,
        opponentId: season.nextFixture!.opponentId,
        expectedWeek: 2,
        userGoals: 1,
        oppGoals: 0,
      ),
      throwsStateError,
    );
    expect(
      () => service.applyUserResult(
        season,
        opponentId: season.nextFixture!.opponentId,
        userGoals: -1,
        oppGoals: 0,
      ),
      throwsArgumentError,
    );
    expect(season.user.played, 0);
  });

  test(
    'Difficulty shifts opponent strength while retaining the same schedule',
    () {
      final easy = ManagerSeasonService(random: Random(4))
          .createSeason(difficulty: ManagerDifficulty.easy);
      final hard = ManagerSeasonService(random: Random(4))
          .createSeason(difficulty: ManagerDifficulty.hard);
      for (var i = 1; i < 20; i++) {
        expect(hard.clubs[i].strength - easy.clubs[i].strength, 10);
      }
      expect(
        easy.fixtures.map((f) => f.opponentId),
        hard.fixtures.map((f) => f.opponentId),
      );
    },
  );
}
