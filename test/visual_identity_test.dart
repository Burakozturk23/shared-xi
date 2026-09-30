import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/club_visual_identity.dart';
import 'package:shared_xi/data/player_kit_identity.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/match_entity.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/screens/shared_players_result_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/club_badge.dart';
import 'package:shared_xi/widgets/player_avatar.dart';

Club club(int id, String name) =>
    Club(id: id, name: name, league: '', country: '');
Player player(int id, {String? avatarKey}) => Player.fromJson({
  'id': id,
  'name': 'Oyuncu $id',
  'position': 'Attack',
  'countries': ['Türkiye'],
  'avatarKey': avatarKey,
});

Future<void> capture(GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  final image =
      await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('.dart_tool/identity_qa/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  test(
    'rival clubs retain distinct colors and unknown clubs do not impersonate them',
    () {
      final madrid = ClubVisualIdentity.forClub(club(418, 'Real Madrid'));
      final barcelona = ClubVisualIdentity.forClub(club(131, 'FC Barcelona'));
      expect(madrid.primary, const Color(0xFFF7F5EC));
      expect(barcelona.primary, const Color(0xFFA32042));
      expect(ClubVisualIdentity.forClub(club(36, 'Fenerbahce')).label, 'FB');
      expect(ClubVisualIdentity.forClub(club(141, 'Galatasaray')).label, 'GS');
      expect(ClubVisualIdentity.forClub(club(114, 'Besiktas JK')).label, 'BJK');
      expect(
        ClubVisualIdentity.forClub(club(64918, 'Athletic Club')).label,
        isNot('ATH'),
      );
      expect(ClubVisualIdentity.initials(''), '?');
    },
  );

  test('kit initials preserve Unicode names and handle empty values', () {
    expect(PlayerKitIdentity.initials('Cristiano Ronaldo'), 'CR');
    expect(PlayerKitIdentity.initials('Hakan Çalhanoğlu'), 'HÇ');
    expect(PlayerKitIdentity.initials('  Arda   Güler  '), 'AG');
    expect(PlayerKitIdentity.initials('Pelé'), 'P');
    expect(PlayerKitIdentity.initials(''), '?');
    expect(PlayerKitIdentity.position('unknown').$2, 'F');
  });

  for (final size in [28.0, 34.0, 48.0, 64.0, 96.0]) {
    testWidgets('kit fits at $size px with large system text', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3)),
        child: Scaffold(body: PlayerAvatar(
          player: player(8198, avatarKey: 'intentionally_missing'), size: size,
        )),
      )));
      await tester.pumpAndSettle();
      expect(find.text('O8'), findsOneWidget);
      expect(find.text('HC'), size >= 64 ? findsOneWidget : findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.bySemanticsLabel('Oyuncu 8198, Hücum, Turkey'), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [true, false]) {
    testWidgets(
      'shared player kits and detail fit narrow screens, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
            home: RepaintBoundary(
              key: key,
              child: SharedPlayersResultPage(
                entity1: MatchEntity.club(club(418, 'Real Madrid')),
                entity2: MatchEntity.club(club(131, 'FC Barcelona')),
                resultLoader: () async =>
                    ([for (var i = 1; i <= 4; i++) player(i)], <int, String>{}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlayerAvatar), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => capture(key, dark ? 'shared-dark' : 'shared-light'),
        );
        await tester.tap(find.text('Oyuncu 1'));
        await tester.pumpAndSettle();
        expect(find.text('Temsili illüstrasyon'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('badge collection fits large text and small rendering sizes', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: OrtakSahaTheme.dark,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  children: [
                    for (final id in ClubVisualIdentity.catalog.keys)
                      ClubBadge(club: club(id, 'Club $id'), size: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => capture(key, 'club-collection'));
  });
}
