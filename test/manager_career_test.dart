import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/manager_squad_draft.dart';
import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/models/manager_season.dart';
import 'package:shared_xi/models/manager_transfer.dart';
import 'package:shared_xi/services/manager_career_store.dart';
import 'package:shared_xi/services/manager_season_service.dart';

import 'support/manager_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const difficulty = ManagerDifficulty.medium;
  final formation = ManagerFormations.all.first;
  final roster = managerRoster();
  late ManagerCareerStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = ManagerCareerStore(
      seasons: ManagerSeasonService(random: Random(7)),
    );
  });

  Future<ManagerCareerState> ready() async {
    final career = await store.startIfNeeded(difficulty);
    return store.saveSquad(
      difficulty: difficulty,
      seasonId: career.season!.id,
      formation: formation,
      assignments: managerXi(roster, formation),
    );
  }

  test(
    'Legacy 19-match season is archived once; roster, money and totals survive',
    () async {
      final modern = ManagerSeasonService(random: Random(3)).createSeason();
      final clubs = modern.clubs.take(19).toList();
      clubs.first.played = 3;
      clubs.first.won = 2;
      clubs.first.lost = 1;
      clubs.first.points = 6;
      clubs.first.gf = 4;
      clubs.first.ga = 2;
      final oldSeason = ManagerSeason(
        clubs: clubs,
        formatVersion: 1,
        currentWeek: 4,
        fixtures: [
          for (var i = 0; i < 19; i++)
            SeasonFixture(
              week: i + 1,
              opponentId: clubs[(i % 18) + 1].id,
              played: i < 3,
              userGoals: i < 3 ? 2 : null,
              oppGoals: i < 3 ? 0 : null,
            ),
        ],
      );
      final old = ManagerCareerState(
        difficulty: difficulty,
        budgetLink: 47,
        started: true,
        matchesPlayed: 23,
        wins: 10,
        draws: 8,
        losses: 5,
        squadPlayerIds: managerXi(
          roster,
          formation,
        ).values.map((p) => p.playerId).toList(),
        formationId: formation.id,
        benchPlayerIds: const [1001, 1002],
        season: oldSeason,
      );
      final raw = old.toJson();
      (raw['season'] as Map)
        ..remove('formatVersion')
        ..remove('id')
        ..remove('leagueFixtures');
      SharedPreferences.setMockInitialValues({
        'club_manager_career_v8_medium': jsonEncode(raw),
      });
      final migrated = await store.load(difficulty);
      expect(migrated.formatUpgradeNotice, isTrue);
      expect(migrated.season!.isCurrentFormat, isTrue);
      expect(migrated.season!.fixtures.length, 38);
      expect(migrated.season!.clubs.length, 20);
      expect(migrated.season!.user.played, 0);
      expect(migrated.budgetLink, 47);
      expect(migrated.squadPlayerIds, old.squadPlayerIds);
      expect(migrated.benchPlayerIds, [1001, 1002]);
      expect(
        [
          migrated.matchesPlayed,
          migrated.wins,
          migrated.draws,
          migrated.losses,
        ],
        [23, 10, 8, 5],
      );
      expect(migrated.archivedSeasons.single.user.points, 6);
      expect(migrated.archivedSeasons.single.fixtures.length, 19);
      expect(
        migrated.archivedSeasons.single.fixtures.where((f) => f.played).length,
        3,
      );
      final again = await store.load(difficulty);
      expect(again.archivedSeasons.length, 1);
      expect(again.season!.id, migrated.season!.id);
      await store.dismissUpgrade(difficulty);
      expect((await store.load(difficulty)).formatUpgradeNotice, isFalse);
    },
  );

  test(
    'Corrupt data is reported without overwriting the stored career',
    () async {
      SharedPreferences.setMockInitialValues({
        'club_manager_career_v8_medium': '{broken',
      });
      await expectLater(store.load(difficulty), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('club_manager_career_v8_medium'), '{broken');
    },
  );

  test(
    'Squad placement charges new players once and owned reserves remain free',
    () async {
      final career = await ready();
      expect(career.budgetLink, difficulty.budgetLink - 66);
      final draft = ManagerSquadDraft(
        career: career,
        formation: formation,
        roster: roster,
      );
      final keeper = draft.assignments['GK']!;
      draft.remove('GK');
      expect(draft.cash, career.budgetLink);
      final partial = await store.saveSquad(
        difficulty: difficulty,
        seasonId: career.season!.id,
        formation: formation,
        assignments: draft.assignments,
      );
      expect(partial.benchPlayerIds, contains(keeper.playerId));
      expect(partial.budgetLink, career.budgetLink);
      final restored = ManagerSquadDraft(
        career: partial,
        formation: formation,
        roster: roster,
      );
      restored.place('GK', keeper);
      expect(restored.purchaseCost, 0);
      final saved = await store.saveSquad(
        difficulty: difficulty,
        seasonId: career.season!.id,
        formation: formation,
        assignments: restored.assignments,
      );
      expect(saved.budgetLink, career.budgetLink);
      expect(saved.hasSquad, isTrue);
      expect(saved.benchPlayerIds, isNot(contains(keeper.playerId)));
      final repeated = await store.saveSquad(
        difficulty: difficulty,
        seasonId: career.season!.id,
        formation: formation,
        assignments: restored.assignments,
      );
      expect(repeated.budgetLink, saved.budgetLink);
    },
  );

  test(
    'Draft rejects bad positions and overspending without mutating the XI',
    () {
      final career = ManagerCareerState(difficulty: difficulty, budgetLink: 6);
      final draft = ManagerSquadDraft(
        career: career,
        formation: formation,
        roster: roster,
      );
      final keeper = roster.byId.values.firstWhere(
        (p) => p.positionGroup == 'GK',
      );
      draft.place('GK', keeper);
      expect(draft.cash, 0);
      expect(() => draft.place('ST', keeper), throwsStateError);
      expect(() => draft.place('ST', roster.byId[1004]!), throwsStateError);
      expect(draft.assignments.keys, ['GK']);
      draft.remove('GK');
      expect(draft.cash, 6);
      expect(draft.purchaseCost, 0);
    },
  );

  test('All formations have an affordable complete starter XI, including hard mode', () {
    for (final f in ManagerFormations.all) {
      final career = ManagerCareerState.fresh(ManagerDifficulty.hard);
      final draft = ManagerSquadDraft(
        career: career,
        formation: f,
        roster: roster,
      );
      final pool = roster.poolFor(
        formation: f,
        ownedIds: {},
        weekKey: 'first-week',
      );
      draft.autoFill(pool);
      expect(draft.complete, isTrue, reason: f.id);
      expect(draft.selectedIds.length, 11);
      expect(draft.cash, greaterThanOrEqualTo(0));
      expect(
        draft.assignments.entries.every(
          (e) => ManagerFormation.groupOf(e.key) == e.value.positionGroup,
        ),
        isTrue,
      );
    }
  });

  test(
    'Changing formation keeps unmatched owned players on the bench',
    () async {
      final career = await ready();
      final other = ManagerFormations.all.firstWhere((f) => f.id == '541');
      final draft = ManagerSquadDraft(
        career: career,
        formation: other,
        roster: roster,
      );
      final pool = roster.poolFor(
        formation: other,
        ownedIds: career.ownedIds,
        weekKey: 'week',
      );
      draft.autoFill(pool);
      final saved = await store.saveSquad(
        difficulty: difficulty,
        seasonId: career.season!.id,
        formation: other,
        assignments: draft.assignments,
      );
      expect(saved.ownedIds, containsAll(career.ownedIds));
      expect(
        saved.squadPlayerIds.toSet().intersection(saved.benchPlayerIds.toSet()),
        isEmpty,
      );
      expect(saved.squadPlayerIds.length, 11);
    },
  );

  test(
    'Concurrent purchases cannot double-charge or overdraw the career',
    () async {
      var career = await store.startIfNeeded(difficulty);
      await store.save(career.copyWith(budgetLink: 40));
      career = await store.prepareMarket(
        difficulty: difficulty,
        marketKey: career.currentMarketKey,
        offers: [
          ManagerTransferOffer(
            player: roster.byId[1001]!,
            askLink: 30,
            note: 'A',
          ),
          ManagerTransferOffer(
            player: roster.byId[1002]!,
            askLink: 22,
            note: 'B',
          ),
        ],
      );
      final results = await Future.wait([
        store
            .buy(difficulty, 1001)
            .then<Object>((s) => s, onError: (Object e) => e),
        store
            .buy(difficulty, 1001)
            .then<Object>((s) => s, onError: (Object e) => e),
        store
            .buy(difficulty, 1002)
            .then<Object>((s) => s, onError: (Object e) => e),
      ]);
      expect(results.whereType<StateError>().length, 1);
      final saved = await store.load(difficulty);
      expect(saved.budgetLink, 10);
      expect(saved.benchPlayerIds, [1001]);
      expect(saved.ownedIds.length, 1);
      // An error must not poison the mutation queue.
      final sold = await store.sellReserve(difficulty, roster.byId[1001]!);
      expect(sold.budgetLink, 22);
      await expectLater(
        store.sellReserve(difficulty, roster.byId[1001]!),
        throwsStateError,
      );
      final bought = await store.buy(difficulty, 1002);
      expect(bought.budgetLink, 0);
    },
  );

  test('Weekly offers survive reopen; transferred bench player costs zero to field', () async {
    var career = await ready();
    career = await store.prepareMarket(
      difficulty: difficulty,
      marketKey: career.currentMarketKey,
      offers: [
        ManagerTransferOffer(
          player: roster.byId[1001]!,
          askLink: 16,
          note: 'A',
        ),
      ],
    );
    final reopened = await store.prepareMarket(
      difficulty: difficulty,
      marketKey: career.currentMarketKey,
      offers: [
        ManagerTransferOffer(
          player: roster.byId[1002]!,
          askLink: 20,
          note: 'B',
        ),
      ],
    );
    expect(reopened.marketOffers.single.playerId, 1001);
    career = await store.buy(difficulty, 1001);
    final cash = career.budgetLink;
    final draft = ManagerSquadDraft(
      career: career,
      formation: formation,
      roster: roster,
    );
    final previous = draft.assignments['GK']!.playerId;
    draft.place('GK', roster.byId[1001]!);
    expect(draft.cash, cash);
    career = await store.saveSquad(
      difficulty: difficulty,
      seasonId: career.season!.id,
      formation: formation,
      assignments: draft.assignments,
    );
    expect(career.budgetLink, cash);
    expect(career.squadPlayerIds, contains(1001));
    expect(career.benchPlayerIds, contains(previous));
    expect(career.benchPlayerIds, isNot(contains(1001)));
    await expectLater(
      store.sellReserve(difficulty, roster.byId[1001]!),
      throwsStateError,
    );
    final fixture = career.season!.nextFixture!;
    career = await store.applyMatchResult(
      difficulty: difficulty,
      seasonId: career.season!.id,
      week: fixture.week,
      opponentId: fixture.opponentId,
      userGoals: 0,
      oppGoals: 0,
    );
    expect(career.marketKey, isNot(career.currentMarketKey));
    await expectLater(store.buy(difficulty, 1002), throwsStateError);
  });

  test(
    'A concurrent result is credited exactly once, including its win bonus',
    () async {
      final career = await ready();
      final f = career.season!.nextFixture!;
      Future<ManagerCareerState> result(int goals) => store.applyMatchResult(
        difficulty: difficulty,
        seasonId: career.season!.id,
        week: f.week,
        opponentId: f.opponentId,
        userGoals: goals,
        oppGoals: 0,
      );
      await Future.wait([result(2), result(2)]);
      final saved = await store.load(difficulty);
      expect(saved.matchesPlayed, 1);
      expect(saved.wins, 1);
      expect(saved.season!.clubs.every((c) => c.played == 1), isTrue);
      expect(saved.budgetLink, career.budgetLink + difficulty.winBonusLink);
      await expectLater(result(3), throwsStateError);
      await expectLater(
        store.applyMatchResult(
          difficulty: difficulty,
          seasonId: 'stale-season',
          week: f.week,
          opponentId: f.opponentId,
          userGoals: 2,
          oppGoals: 0,
        ),
        throwsStateError,
      );
      expect((await store.load(difficulty)).matchesPlayed, 1);
    },
  );

  test(
    '38 persisted weeks end once; next season retains cash, roster and totals',
    () async {
      var career = await ready();
      final initial = career;
      await expectLater(store.nextSeason(difficulty), throwsStateError);
      for (var i = 1; i <= 38; i++) {
        final fixture = career.season!.nextFixture!;
        career = await store.applyMatchResult(
          difficulty: difficulty,
          seasonId: career.season!.id,
          week: fixture.week,
          opponentId: fixture.opponentId,
          userGoals: i % 3,
          oppGoals: 1,
        );
        career = await store.load(difficulty);
        expect(career.matchesPlayed, i);
        expect(career.season!.clubs.every((c) => c.played == i), isTrue);
      }
      expect(career.season!.isComplete, isTrue);
      expect(
        career.budgetLink,
        initial.budgetLink + career.wins * difficulty.winBonusLink,
      );
      final next = await store.nextSeason(difficulty);
      expect(next.season!.id, isNot(career.season!.id));
      expect(next.season!.user.played, 0);
      expect(next.archivedSeasons.single.isComplete, isTrue);
      expect(next.archivedSeasons.single.fixtures.length, 38);
      expect(next.budgetLink, career.budgetLink);
      expect(next.squadPlayerIds, career.squadPlayerIds);
      expect(next.matchesPlayed, 38);
      expect(next.seasonNumber, 2);
    },
  );
}
