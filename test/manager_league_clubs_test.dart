import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/manager_league_clubs.dart';
import 'package:shared_xi/data/popular_clubs_pool.dart';
import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/models/manager_season.dart';
import 'package:shared_xi/services/manager_match_service.dart';
import 'package:shared_xi/services/manager_season_service.dart';

import 'support/manager_fixture.dart';

// The solo league plays real popular clubs (no more Northgate FC or Canark XI).
void main() {
  test(
    'league clubs are popular clubs rated by a known XI, strongest first',
    () {
      expect(managerLeagueClubs.length, greaterThanOrEqualTo(30));
      expect(
        managerLeagueClubs.map((c) => c.id).toSet().length,
        managerLeagueClubs.length,
      );
      for (final c in managerLeagueClubs) {
        expect(popularClubIds, contains(c.id));
        expect(c.forwards, isNotEmpty, reason: c.name);
        expect(c.rating, inInclusiveRange(72, 99));
      }
      final ratings = managerLeagueClubs.map((c) => c.rating).toList();
      expect(ratings, [...ratings]..sort((a, b) => b.compareTo(a)));
      expect(managerLeagueClubs.first.name, 'FC Barcelona');
    },
  );

  test(
    'a season deals 19 distinct real clubs; strength follows their rating',
    () {
      for (var seed = 0; seed < 20; seed++) {
        final season = ManagerSeasonService(
          random: Random(seed),
        ).createSeason();
        final opponents = season.clubs.where((c) => !c.isUser).toList();
        expect(opponents.length, 19);
        expect(opponents.map((c) => c.clubId).toSet().length, 19);
        for (final c in opponents) {
          final club = ManagerSeasonService.clubOf(c)!;
          expect(c.name, club.name);
          expect(c.leagueHint, club.league);
          expect(c.strength, inInclusiveRange(55, 85));
          expect(
            c.strength,
            ManagerSeasonService.strengthOf(club).roundToDouble(),
          );
        }
        // The club survives a save and a reload.
        final back = ManagerSeason.fromJson(
          jsonDecode(jsonEncode(season.toJson())) as Map<String, dynamic>,
        );
        expect(
          back.clubs.map((c) => c.clubId),
          season.clubs.map((c) => c.clubId),
        );
      }
      final hard = ManagerSeasonService(
        random: Random(1),
      ).createSeason(difficulty: ManagerDifficulty.hard);
      final medium = ManagerSeasonService(random: Random(1)).createSeason();
      expect(
        hard.clubs.where((c) => !c.isUser).first.strength,
        medium.clubs.where((c) => !c.isUser).first.strength + 5,
      );
    },
  );

  test(
    'a real club scores through its known players; a made-up one stays nameless',
    () {
      final xi = managerXi(
        managerRoster(),
        ManagerFormations.all.first,
      ).values.toList();
      final season = ManagerSeasonService(random: Random(3)).createSeason();
      final real = season.clubs.firstWhere((c) => !c.isUser);
      final opponent = ManagerSeasonService.instance.toOpponent(real);
      final club = ManagerSeasonService.clubOf(real)!;
      expect(opponent.club, same(club));
      final names = {...club.forwards, ...club.midfielders};
      var goals = 0;
      for (var seed = 0; seed < 60; seed++) {
        final r = ManagerMatchService.instance.simulate(
          xi: xi,
          difficulty: ManagerDifficulty.medium,
          budgetLink: 14,
          opponent: opponent,
          seed: seed,
          chargeSquadCost: false,
        );
        for (final e in r.events.where((e) => e.isGoal && !e.isHome)) {
          goals++;
          expect(names.any(e.text.contains), isTrue, reason: e.text);
          expect(e.text, startsWith('GOL! ${club.name} · '));
        }
      }
      expect(goals, greaterThan(0));
      final old = SeasonClub.fromJson({
        'id': 'opp_0',
        'name': 'Northgate FC',
        'leagueHint': 'Ortak Saha Ligi',
        'style': 'balanced',
        'strength': 70,
      });
      expect(old.clubId, isNull);
      final made = ManagerSeasonService.instance.toOpponent(old);
      expect(made.club, isNull);
      for (var seed = 0; seed < 30; seed++) {
        final r = ManagerMatchService.instance.simulate(
          xi: xi,
          difficulty: ManagerDifficulty.medium,
          budgetLink: 14,
          opponent: made,
          seed: seed,
          chargeSquadCost: false,
        );
        for (final e in r.events.where((e) => e.isGoal && !e.isHome)) {
          expect(e.text, 'GOL! Northgate FC hücumu skoru değiştirdi.');
        }
      }
    },
  );
}
