import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/match_entity.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/screens/discovery_selection_page.dart';
import 'package:shared_xi/screens/shared_players_result_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

const _arsenal = Club(
  id: 11,
  name: 'Arsenal',
  league: 'Premier League',
  country: 'England',
);
const _barcelona = Club(
  id: 131,
  name: 'Barcelona',
  league: 'LaLiga',
  country: 'Spain',
);

Club _club(int id, String name) =>
    Club(id: id, name: name, league: 'Lig', country: 'Ülke');

Player _player(
  int id,
  String name, {
  required List<(int, int, int?)> career,
  double peak = 0,
  int goals = 0,
}) => Player.fromJson({
  'id': id,
  'name': name,
  'position': 'Attack',
  'countries': ['France'],
  'clubIds': [for (final c in career) c.$1],
  'peakMarketValue': peak,
  'careerGoals': goals,
  'careerTimeline': [
    for (final c in career)
      {'clubId': c.$1, 'startYear': c.$2, 'endYear': c.$3},
  ],
});

Future<void> _show(WidgetTester t, Widget page, {double height = 1800}) async {
  t.view.physicalSize = Size(390, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: OrtakSahaTheme.dark, home: page));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('discovery shows catalog size, search and every popular pair', (
    t,
  ) async {
    await _show(
      t,
      DiscoverySelectionPage(
        catalogLoader: () async => (
          [
            _club(418, 'Real Madrid'),
            _barcelona,
            _club(985, 'Manchester United'),
            _club(31, 'Liverpool'),
            _club(27, 'Bayern'),
            _club(506, 'Juventus'),
            _club(583, 'PSG'),
            _club(281, 'Manchester City'),
            _club(631, 'Chelsea'),
            _arsenal,
          ],
          ['France', 'Spain'],
        ),
      ),
    );
    expect(find.text('10 kulüp · 2 ülke'), findsOneWidget);
    expect(find.text('Real Madrid × Barcelona'), findsOneWidget);
    // Four pairs show first; the rest open on demand.
    expect(find.text('Chelsea × Arsenal'), findsNothing);
    await t.ensureVisible(find.text('Tümü (5)'));
    await t.tap(find.text('Tümü (5)'));
    await t.pumpAndSettle();
    expect(find.text('Chelsea × Arsenal'), findsOneWidget);
    // The search bar opens the picker for the first empty slot.
    await t.ensureVisible(find.text('Kulüp adı ara'));
    await t.tap(find.text('Kulüp adı ara'));
    await t.pumpAndSettle();
    expect(find.text('Kulüp seç'), findsOneWidget);
  });

  testWidgets('results analyse direct moves, records and career paths', (
    t,
  ) async {
    final henry = _player(
      14,
      'Thierry Henry',
      career: [(11, 1999, 2007), (131, 2007, 2010)],
      peak: 50e6,
      goals: 411,
    );
    final petit = _player(
      15,
      'Emmanuel Petit',
      career: [(11, 1997, 2000), (999, 2000, 2001), (131, 2001, 2002)],
      peak: 12e6,
      goals: 30,
    );
    await _show(
      t,
      SharedPlayersResultPage(
        entity1: MatchEntity.club(_arsenal),
        entity2: MatchEntity.club(_barcelona),
        resultLoader: () async =>
            ([petit, henry], {11: 'Arsenal', 131: 'Barcelona', 999: 'Kulüp X'}),
      ),
      height: 2400,
    );
    expect(find.text('2 ortak oyuncu'), findsOneWidget);
    expect(find.text('EN DEĞERLİ'), findsOneWidget);
    // Header record and the player's card.
    expect(find.text('€50M'), findsNWidgets(2));
    expect(find.text('EN GOLCÜ'), findsOneWidget);
    expect(find.text('411 gol'), findsOneWidget);
    expect(find.text('1999–2007'), findsOneWidget);
    expect(find.text('Doğrudan geçiş'), findsOneWidget);
    expect(find.text('Arada 1 kulüp'), findsOneWidget);
    // The most valuable player leads by default.
    expect(
      t.getTopLeft(find.text('Thierry Henry').last).dy,
      lessThan(t.getTopLeft(find.text('Emmanuel Petit')).dy),
    );
    await t.tap(find.text('Doğrudan (1)'));
    await t.pumpAndSettle();
    expect(find.text('Emmanuel Petit'), findsNothing);
    expect(find.text('Thierry Henry'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('club × country results share the club × club analysis', (
    t,
  ) async {
    // Country flags load through the network image cache.
    final dir = Directory.systemTemp.createTempSync('flags').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir,
        );
    final henry = _player(
      14,
      'Thierry Henry',
      career: [(5, 1994, 1999), (11, 1999, 2007), (131, 2007, 2010)],
      peak: 50e6,
      goals: 411,
    );
    final vieira = _player(
      16,
      'Patrick Vieira',
      career: [(11, 1996, 2005), (506, 2005, 2006)],
      peak: 40e6,
      goals: 60,
    );
    final saliba = _player(
      17,
      'William Saliba',
      career: [(11, 2019, null)],
      peak: 80e6,
      goals: 5,
    );
    await _show(
      t,
      SharedPlayersResultPage(
        entity1: MatchEntity.club(_arsenal),
        entity2: MatchEntity.country('France'),
        resultLoader: () async => (
          [henry, vieira, saliba],
          {5: 'Monaco', 11: 'Arsenal', 131: 'Barcelona', 506: 'Juventus'},
        ),
      ),
      height: 2600,
    );
    expect(find.text('EN UZUN DÖNEM'), findsOneWidget);
    expect(find.text('9 yıl'), findsOneWidget);
    // Henry's path runs through Arsenal with the clubs either side.
    expect(find.text('Monaco'), findsOneWidget);
    expect(find.text('Barcelona'), findsOneWidget);
    expect(find.text('Kulüpte 8 yıl'), findsOneWidget);
    expect(find.text('Halen kulüpte'), findsOneWidget);
    await t.tap(find.text('Halen kulüpte (1)'));
    await t.pumpAndSettle();
    // Vieira stays only as the header record; his card (Juventus) is gone.
    expect(find.text('Juventus'), findsNothing);
    expect(find.text('Monaco'), findsNothing);
    expect(find.text('William Saliba'), findsWidgets);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(minutes: 1));
  });
}
