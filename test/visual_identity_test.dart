import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/club_visual_identity.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/match_entity.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/screens/shared_players_result_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/club_badge.dart';
import 'package:shared_xi/widgets/player_avatar.dart';

Club club(int id, String name) => Club(id: id, name: name, league: '', country: '');
Player player(int id, {String? avatarKey}) => Player.fromJson({
  'id': id, 'name': 'Oyuncu $id', 'position': 'Attack',
  'countries': ['Türkiye'], 'avatarKey': avatarKey,
});

Future<void> capture(GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
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

  test('rival clubs retain distinct colors and unknown clubs do not impersonate them', () {
    final madrid = ClubVisualIdentity.forClub(club(418, 'Real Madrid'));
    final barcelona = ClubVisualIdentity.forClub(club(131, 'FC Barcelona'));
    expect(madrid.primary, const Color(0xFFF7F5EC));
    expect(barcelona.primary, const Color(0xFFA32042));
    expect(ClubVisualIdentity.forClub(club(36, 'Fenerbahce')).label, 'FB');
    expect(ClubVisualIdentity.forClub(club(141, 'Galatasaray')).label, 'GS');
    expect(ClubVisualIdentity.forClub(club(114, 'Besiktas JK')).label, 'BJK');
    expect(ClubVisualIdentity.forClub(club(64918, 'Athletic Club')).label, isNot('ATH'));
    expect(ClubVisualIdentity.initials(''), '?');
  });

  testWidgets('all bundled portraits decode and missing custom images fall back', (tester) async {
    for (final asset in PlayerAvatar.representativeAssets) {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 384);
      frame.image.dispose();
      codec.dispose();
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayerAvatar(
      player: player(1, avatarKey: 'intentionally_missing'),
    ))));
    await tester.runAsync(() async {
      await precacheImage(AssetImage(PlayerAvatar.representativeAssetFor(1)),
          tester.element(find.byType(PlayerAvatar)));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PlayerAvatar), findsOneWidget);
    expect(PlayerAvatar.representativeAssetFor(1), PlayerAvatar.representativeAssetFor(1));
    expect({for (var id = 1; id <= 100; id++) PlayerAvatar.representativeAssetFor(id)},
        PlayerAvatar.representativeAssets.toSet());
  });

  for (final dark in [true, false]) {
    testWidgets('shared player portraits and detail fit narrow screens, dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
        home: RepaintBoundary(key: key, child: SharedPlayersResultPage(
          entity1: MatchEntity.club(club(418, 'Real Madrid')),
          entity2: MatchEntity.club(club(131, 'FC Barcelona')),
          resultLoader: () async => ([for (var i = 1; i <= 4; i++) player(i)], <int, String>{}),
        )),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final asset in PlayerAvatar.representativeAssets) {
          await precacheImage(AssetImage(asset), tester.element(find.byType(Scaffold).first));
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(PlayerAvatar), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => capture(key, dark ? 'shared-dark' : 'shared-light'));
      await tester.tap(find.text('Oyuncu 1'));
      await tester.pumpAndSettle();
      expect(find.text('Temsili illüstrasyon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('badge collection fits large text and small rendering sizes', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: OrtakSahaTheme.dark,
      home: Scaffold(body: RepaintBoundary(key: key, child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Padding(padding: const EdgeInsets.all(24), child: Wrap(
          spacing: 16, runSpacing: 20,
          children: [for (final id in ClubVisualIdentity.catalog.keys)
            ClubBadge(club: club(id, 'Club $id'), size: 48)],
        )),
      ))),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => capture(key, 'club-collection'));
  });
}
