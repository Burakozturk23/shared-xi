import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/models/grid_criterion.dart';
import 'package:shared_xi/services/classic_grid_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/grid_club_pool.dart';
import 'package:shared_xi/widgets/grid_club_pool_picker.dart';

const clubs = [
  Club(id: 11, name: 'Arsenal', league: 'Premier League', country: 'England'),
  Club(id: 131, name: 'Barcelona', league: 'LaLiga', country: 'Spain'),
  Club(id: 999999, name: 'Unknown FC', league: 'League Two', country: 'England'),
  Club(id: 36, name: 'Fenerbahce', league: 'TR1', country: 'Turkey'),
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('default excludes unfamiliar clubs, broad retains them', () {
    expect(const GridClubPool().filter(clubs).map((c) => c.id), [11, 131, 36]);
    expect(const GridClubPool(kind: GridPoolKind.broad).filter(clubs), clubs);
  });
  test('multiple leagues are a union; country alone never matches', () {
    const pool = GridClubPool(kind: GridPoolKind.leagues, leagues: {'england', 'turkey'});
    expect(pool.filter(clubs).map((c) => c.id), [11, 36]);
    expect(GridClubPool.decode(pool.encode()).leagues, pool.leagues);
  });
  test('corrupt, obsolete and empty league settings recover to popular', () {
    for (final raw in [null, 'broken', '{"kind":"leagues","leagues":["removed"]}']) {
      expect(GridClubPool.decode(raw).kind, GridPoolKind.popular);
    }
  });
  test('shared setting persists and refuses an empty league selection', () async {
    const pool = GridClubPool(kind: GridPoolKind.leagues, leagues: {'spain', 'italy'});
    await GridClubPoolStore.save(pool);
    expect((await GridClubPoolStore.load()).leagues, pool.leagues);
    await expectLater(GridClubPoolStore.save(const GridClubPool(kind: GridPoolKind.leagues)), throwsArgumentError);
    expect((await GridClubPoolStore.load()).leagues, pool.leagues);
  });
  test('session filters club questions but keeps less familiar valid answers', () async {
    final catalog = [for (var i = 1; i <= 6; i++)
      Club(id: i, name: 'Team $i', league: 'Premier League', country: 'England'), clubs[2]];
    final answers = [for (var i = 1; i <= 100; i++) Player.fromJson({
      'id': i, 'name': 'Player $i', 'position': 'Attack', 'countries': ['France'],
      'clubIds': [1, 2, 3, 4, 5, 6],
    })];
    final session = await ClassicGridSession.load(
      random: Random(9),
      clubPool: const GridClubPool(kind: GridPoolKind.leagues, leagues: {'england'}),
      loadClubCatalog: () async => catalog,
      loadClubPlayers: (_) async => answers,
    );
    for (final criterion in [...session.rows, ...session.cols]) {
      if (criterion.type == GridCriterionType.club) expect(criterion.clubId, inInclusiveRange(1, 6));
    }
    expect(session.players.any((p) => p.id == 100), isTrue);
    expect(session.validPlayerIdsByCell.values.every((ids) => ids.contains(100)), isTrue);
  });
  testWidgets('picker requires a league, saves and restores selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GridClubPoolPicker())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kulüp havuzu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lig seç'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.ensureVisible(find.text('La Liga'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('La Liga'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Uygula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect((await GridClubPoolStore.load()).leagues, {'spain'});
    expect(find.textContaining('La Liga'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
