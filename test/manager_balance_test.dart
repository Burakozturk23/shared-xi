import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/career_stop.dart';
import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_match.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/models/manager_tactics.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/services/manager_link_service.dart';
import 'package:shared_xi/services/manager_match_service.dart';
import 'package:shared_xi/services/manager_opponent_service.dart';

import 'support/manager_fixture.dart';

Player _player(int id, List<CareerStop> spells) => Player(
  id: id,
  name: 'P$id',
  countries: const [],
  position: 'Midfield',
  detailedPosition: '',
  clubs: [for (final s in spells) s.clubId],
  nationalTeams: const [],
  primaryNationalTeamId: null,
  aliases: const [],
  normalizedName: 'p$id',
  normalizedAliases: const [],
  marketValue: 0,
  peakMarketValue: 0,
  careerGoals: 0,
  careerTimeline: spells,
);

void main() {
  final xi = managerXi(
    managerRoster(),
    ManagerFormations.all.first,
  ).values.toList();
  final service = ManagerMatchService.instance;
  final home =
      service.powerOf(xi) *
      ManagerOpponentService.instance
          .matchupMultiplier(const ManagerTactics(), OpponentStyle.balanced)
          .clamp(.88, 1.14);

  /// Win / draw / loss shares over [n] seeded matches at a power gap.
  (double, double, double) shares(double gap, {int n = 1500}) {
    var w = 0, d = 0;
    for (var seed = 0; seed < n; seed++) {
      final r = service.simulate(
        xi: xi,
        difficulty: ManagerDifficulty.medium,
        budgetLink: 0,
        chargeSquadCost: false,
        opponent: ManagerOpponent(
          name: 'Rakip',
          leagueHint: '',
          style: OpponentStyle.balanced,
          basePower: home - gap,
        ),
        seed: seed,
      );
      if (r.isWin) w++;
      if (r.isDraw) d++;
    }
    return (w / n, d / n, (n - w - d) / n);
  }

  // Guards the difficulty curve: if a formula change moves it outside these
  // bands the build breaks instead of silently rebalancing the mode.
  test('result curve by power gap stays in its bands', () {
    final curve = {
      for (final gap in [-20.0, -10.0, 0.0, 10.0, 20.0]) gap: shares(gap),
    };
    expect(curve[-20]!.$1, lessThan(.12));
    expect(curve[0]!.$1, inInclusiveRange(.28, .46));
    expect(curve[0]!.$2, inInclusiveRange(.18, .35));
    expect(curve[20]!.$1, greaterThan(.70));
    final wins = curve.values.map((s) => s.$1).toList();
    for (var i = 1; i < wins.length; i++) {
      expect(wins[i], greaterThan(wins[i - 1]), reason: 'monotonic');
    }
  });

  test('the half-time decision never changes the first half', () {
    var pushGoals = 0, protectGoals = 0;
    for (var seed = 0; seed < 400; seed++) {
      ManagerMatchResult run(ManagerHalftimePlan plan) => service.simulate(
        xi: xi,
        difficulty: ManagerDifficulty.medium,
        budgetLink: 0,
        chargeSquadCost: false,
        opponent: ManagerOpponent(
          name: 'Rakip',
          leagueHint: '',
          style: OpponentStyle.counter,
          basePower: home,
        ),
        seed: seed,
        halftime: plan,
      );
      final runs = [for (final p in ManagerHalftimePlan.values) run(p)];
      for (final r in runs) {
        expect(r.halfTimeUser, runs.first.halfTimeUser);
        expect(r.halfTimeOpponent, runs.first.halfTimeOpponent);
        expect(
          r.events.where((e) => e.isGoal && e.minute <= 45).map((e) => e.text),
          runs.first.events
              .where((e) => e.isGoal && e.minute <= 45)
              .map((e) => e.text),
        );
      }
      pushGoals += runs[1].userGoals + runs[1].opponentGoals;
      protectGoals += runs[2].userGoals + runs[2].opponentGoals;
    }
    expect(pushGoals, greaterThan(protectGoals * 1.25));
  });

  test('scorers follow position and quality; no one assists himself', () {
    final byGroup = <String, int>{};
    final group = {for (final p in xi) p.name: p.positionGroup};
    for (var seed = 0; seed < 600; seed++) {
      final r = service.simulate(
        xi: xi,
        difficulty: ManagerDifficulty.medium,
        budgetLink: 0,
        chargeSquadCost: false,
        opponent: ManagerOpponent(
          name: 'Rakip',
          leagueHint: '',
          style: OpponentStyle.balanced,
          basePower: home - 10,
        ),
        seed: seed,
      );
      for (final e in r.events.where((e) => e.isGoal && e.isHome)) {
        final m = RegExp(
          r'^GOL! (.+?)(?: · asist (.+)\.| tek başına bitirdi\.)$',
        ).firstMatch(e.text)!;
        byGroup.update(group[m[1]]!, (n) => n + 1, ifAbsent: () => 1);
        expect(m[2], isNot(m[1]));
      }
    }
    expect(byGroup['ATT']!, greaterThan(byGroup['MID']!));
    expect(byGroup['MID']!, greaterThan(byGroup['DEF'] ?? 0));
    expect(byGroup['GK'] ?? 0, lessThan(5));
  });

  test('draws pay a third of the win bonus; the season reward ladder', () {
    expect(ManagerDifficulty.easy.drawBonusLink, 4);
    expect(ManagerDifficulty.medium.drawBonusLink, 6);
    expect(ManagerDifficulty.hard.drawBonusLink, 9);
    const m = ManagerDifficulty.medium;
    expect(m.seasonRewardLink(1), 40 + 40 + 30);
    expect(m.seasonRewardLink(8), 26 + 40);
    expect(m.seasonRewardLink(9), 24);
    expect(m.seasonRewardLink(20), 2);
  });

  test('same club in different years is no team-mate bond', () {
    final a = _player(1, const [
      CareerStop(clubId: 7, startYear: 2001, endYear: 2004),
    ]);
    final b = _player(2, const [
      CareerStop(clubId: 7, startYear: 2010, endYear: 2013),
    ]);
    final c = _player(3, const [CareerStop(clubId: 7, startYear: 2003)]);
    expect(ManagerLinkService.sharedSpell(a, b, 7), isFalse);
    expect(ManagerLinkService.sharedSpell(a, c, 7), isTrue);
    expect(
      ManagerLinkService.sharedSpell(b, c, 7),
      isTrue,
      reason: 'open spell runs to the data year',
    );
  });
}
