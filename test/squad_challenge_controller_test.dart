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

  test(
    'Passportless checks all occupied countries; malformed drafts restore only legal picks',
    () {
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
    },
  );

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

  test('One club credits three links; picker gain and stars follow it', () {
    final single = squadFixture();
    final players = {
      for (final e in single.players.entries)
        e.key: SquadPlayer(
          id: e.value.id,
          name: e.value.name,
          position: e.value.position,
          detailedPosition: e.value.detailedPosition,
          countries: e.value.countries,
          clubs: const [77],
        ),
    };
    final data = SquadCatalog(
      version: single.version,
      players: players,
      themes: single.themes,
      formations: single.formations,
      continents: single.continents,
      clubNames: const {77: 'Tek Kulüp'},
    );
    const mission = SquadMission(
      id: 'cap',
      day: '',
      themeId: 'fixture',
      formationId: '4-3-3',
      label: '',
      reward: 20,
      budget: 200,
      links: 4,
      countries: 3,
      twoStar: 6,
      threeStar: 9,
      maxLinks: 14,
    );
    final c = BuildXiController(
      catalog: data,
      theme: data.themes.values.first,
      formation: data.formations.values.first,
      mission: mission,
    );
    addTearDown(c.dispose);
    for (var i = 0; i < 11; i++) c.assignPlayer(i, data.players[i + 1]!);
    final b = c.previewBreakdown();
    expect(b.rawLinks, 14);
    expect(b.links, 3);
    expect(b.cappedClubs, {77});
    expect(c.meetsGoal, isFalse);
    expect(c.previewStars, 0);
    expect(c.linksAt(2), greaterThan(0));
    // The fixture's two shared clubs credit six: one star.
    final two = BuildXiController(
      catalog: catalog,
      theme: catalog.themes.values.first,
      formation: catalog.formations.values.first,
      mission: mission,
    );
    addTearDown(two.dispose);
    for (var i = 0; i < 10; i++) two.assignPlayer(i, catalog.players[i + 1]!);
    expect(two.linkGainIf(10, catalog.players[11]!), greaterThanOrEqualTo(0));
    two.assignPlayer(10, catalog.players[11]!);
    expect(two.previewBreakdown().links, 6);
    expect(two.previewStars, 2);
    expect(mission.starsFor(9, 3), 3);
    expect(mission.starsFor(9, 2), 0);
  });

  test('Bare and group-prefixed positions match the same slot', () {
    final lb = catalog.formations.values.first.slots[1];
    const bare = SquadPlayer(
      id: 1,
      name: 'Bek',
      position: 'Defender',
      detailedPosition: 'Left-Back',
      countries: ['X'],
      clubs: [],
    );
    expect(bare.fits(lb), isTrue);
    const wrong = SquadPlayer(
      id: 2,
      name: 'Stoper',
      position: 'Defender',
      detailedPosition: 'Centre-Back',
      countries: ['X'],
      clubs: [],
    );
    expect(wrong.fits(lb), isFalse);
  });

  test(
    'Every daily theme has a legal hard XI; client scores match the server contract',
    () {
      final data = SquadCatalog.fromJson(
        jsonDecode(
              File(
                'assets/data/squad_challenge_catalog.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final cases =
          jsonDecode(
                File(
                  'test/support/squad_scoring_cases.json',
                ).readAsStringSync(),
              )
              as List;
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
            'rawLinks': b.rawLinks,
            'countries': b.countries,
            'score': b.total,
          },
          row['score'],
          reason: m.themeId,
        );
        c.dispose();
      }
    },
  );
}
