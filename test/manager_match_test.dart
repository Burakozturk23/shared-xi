import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/models/manager_tactics.dart';
import 'package:shared_xi/services/manager_match_service.dart';

import 'support/manager_fixture.dart';

void main() {
  final xi = managerXi(
    managerRoster(),
    ManagerFormations.all.first,
  ).values.toList();
  const opponent = ManagerOpponent(
    name: 'Rivals',
    leagueHint: 'Test',
    style: OpponentStyle.balanced,
    basePower: 65,
  );
  test(
    'Home/away labels, win bonuses, shots and events use the correct side',
    () {
      for (final home in [true, false]) {
        for (var seed = 0; seed < 50; seed++) {
          final r = ManagerMatchService.instance.simulate(
            xi: xi,
            difficulty: ManagerDifficulty.medium,
            budgetLink: 14,
            opponent: opponent,
            homeName: 'My XI',
            seed: seed,
            userIsHome: home,
            homeAdvantage: 3,
            chargeSquadCost: false,
          );
          final s = r.stats;
          expect(r.homeName, home ? 'My XI' : 'Rivals');
          expect(r.awayName, home ? 'Rivals' : 'My XI');
          expect(r.userGoals, home ? s.goalsHome : s.goalsAway);
          expect(r.isWin, r.userGoals > r.opponentGoals);
          expect(r.isLoss, r.userGoals < r.opponentGoals);
          expect(r.remainingAfter, 14 + (r.isWin ? 18 : 0));
          expect(r.spentOnXi, 0);
          expect(s.shotsOnHome, inInclusiveRange(s.goalsHome, s.shotsHome));
          expect(s.shotsOnAway, inInclusiveRange(s.goalsAway, s.shotsAway));
          expect(s.possessionHome + s.possessionAway, 100);
          expect(
            r.events.where((e) => e.isGoal && e.isHome).length,
            s.goalsHome,
          );
          expect(
            r.events.where((e) => e.isGoal && !e.isHome).length,
            s.goalsAway,
          );
          expect(
            r.events.map((e) => e.minute),
            orderedEquals(r.events.map((e) => e.minute).toList()..sort()),
          );
        }
      }
    },
  );
  test(
    'Online-compatible defaults retain home perspective and initial XI cost',
    () {
      final r = ManagerMatchService.instance.simulate(
        xi: xi,
        difficulty: ManagerDifficulty.medium,
        budgetLink: 120,
        opponent: opponent,
        seed: 3,
      );
      expect(r.userIsHome, isTrue);
      expect(r.spentOnXi, 66);
      expect(r.remainingAfter, 120 - 66 + r.winBonus);
    },
  );
  test('Incomplete and duplicate teams cannot kick off', () {
    expect(
      () => ManagerMatchService.instance.simulate(
        xi: xi.take(10).toList(),
        difficulty: ManagerDifficulty.medium,
        budgetLink: 100,
      ),
      throwsArgumentError,
    );
    expect(
      () => ManagerMatchService.instance.simulate(
        xi: List.filled(11, xi.first),
        difficulty: ManagerDifficulty.medium,
        budgetLink: 100,
      ),
      throwsArgumentError,
    );
  });
}
