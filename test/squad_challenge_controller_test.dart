import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/build_xi_controller.dart';
import 'package:shared_xi/models/squad_challenge.dart';

import 'support/squad_fixture.dart';

void main() {
  final catalog = squadFixture();
  BuildXiController create({SquadCatalog? data, List<int?>? draft}) {
    final c = data ?? catalog;
    return BuildXiController(
      catalog: c,
      theme: c.themes.values.first,
      formation: c.formations.values.first,
      draft: draft,
    );
  }

  test('Strict positions, duplicates and replacement credit are enforced', () {
    final c = create();
    addTearDown(c.dispose);
    c.assignPlayer(2, catalog.players[3]!);
    expect(() => c.assignPlayer(4, catalog.players[3]!), throwsStateError);
    expect(() => c.assignPlayer(3, catalog.players[3]!), throwsStateError);
    c.assignPlayer(0, catalog.players[12]!);
    expect(c.state.usedBudget, 23);
    c.assignPlayer(0, catalog.players[1]!);
    expect(c.state.usedBudget, 16);
    c.removePlayer(0);
    expect(c.state.usedBudget, 8);
    expect(c.eligiblePlayersFor(0, 'kaleci').map((p) => p.id), [12]);
  });

  test('Canonical player data rejects forged position and country fields', () {
    final c = create();
    addTearDown(c.dispose);
    const forged = SquadPlayer(
      id: 1,
      name: 'Fake',
      position: 'Defender',
      detailedPosition: 'Defender - Right-Back',
      countries: ['Fake'],
      clubs: [],
    );
    expect(() => c.assignPlayer(4, forged), throwsStateError);
    c.assignPlayer(0, forged);
    expect(c.state.slotPlayers[0], same(catalog.players[1]));
  });

  test('Passportless checks all occupied countries; malformed drafts restore only legal picks', () {
    final unique = squadFixture(unique: true);
    final c = create(
      data: unique,
      draft: [12, 2, 3, 3, 99999, null, null, null, null, null, null],
    );
    addTearDown(c.dispose);
    expect(c.playerIds, [
      12,
      null,
      3,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ]);
    expect(c.canAssign(1, unique.players[2]!), isFalse);
    c.removePlayer(0);
    c.assignPlayer(1, unique.players[2]!);
    expect(c.state.filledCount, 2);
  });

  test(
    'Budget overflow cannot replace a valid squad and finish locks edits',
    () {
      final c = BuildXiController(
        catalog: catalog,
        theme: catalog.themes.values.first,
        formation: catalog.formations.values.first,
        mission: const SquadMission(
          id: 'limit',
          day: '',
          themeId: 'fixture',
          formationId: '4-3-3',
          label: '',
          reward: 20,
          budget: 88,
          links: 4,
          countries: 3,
        ),
      );
      addTearDown(c.dispose);
      for (var i = 0; i < 11; i++) c.assignPlayer(i, catalog.players[i + 1]!);
      expect(c.meetsGoal, isTrue);
      expect(c.state.remainingBudget, 0);
      expect(() => c.assignPlayer(0, catalog.players[12]!), throwsStateError);
      expect(c.state.usedBudget, 88);
      c.finish();
      c.removePlayer(0);
      expect(c.state.filledCount, 11);
      expect(c.state.breakdown!.total, c.previewBreakdown().total);
      expect(() => c.assignPlayer(0, catalog.players[1]!), throwsStateError);
    },
  );

  test('Every daily theme has a legal hard XI; client scores match the server contract', () {
    final data = SquadCatalog.fromJson(
      jsonDecode(
        File('assets/data/squad_challenge_catalog.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    final cases = jsonDecode(
      File('test/support/squad_scoring_cases.json').readAsStringSync(),
    ) as List;
    expect(cases.length, 31);
    expect(data.themes.length, 32);
    expect(data.formations.length, 7);
    for (final row in cases) {
      final m = SquadMission.fromJson(
        Map<String, dynamic>.from(row['mission'] as Map),
      );
      final c = BuildXiController(
        catalog: data,
        theme: data.themes[m.themeId]!,
        formation: data.formations[m.formationId]!,
        mission: m,
      );
      for (final (i, id) in (row['ids'] as List).indexed)
        c.assignPlayer(i, data.players[id]!);
      expect(c.meetsGoal, isTrue, reason: m.themeId);
      final b = c.previewBreakdown();
      expect(
        {
          'cost': b.cost,
          'links': b.links,
          'countries': b.countries,
          'score': b.total,
        },
        row['score'],
        reason: m.themeId,
      );
      c.dispose();
    }
  });
}
