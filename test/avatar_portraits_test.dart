import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/player_portrait_catalog.dart';
import 'package:shared_xi/data/season_portrait_catalog.dart';
import 'package:shared_xi/data/uploaded_portrait_catalog.dart';
import 'package:shared_xi/models/store_collection.dart';
import 'package:shared_xi/models/user_avatar_catalog.dart';
import 'package:shared_xi/widgets/user_avatar_badge.dart';

String assetFor(String id) {
  final uploaded = UploadedPortraitCatalog.forAvatarId(id);
  if (uploaded != null) return uploaded.asset;
  final player = PlayerPortraitCatalog.playerIdForAvatar(id)!;
  return PlayerPortraitCatalog.forPlayerId(player) ??
      SeasonPortraitCatalog.forPlayerId(player)!.asset;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Body-Variable.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('every visible avatar has a portrait and agrees with active server offers', () {
    final catalog = jsonDecode(File('functions/config/store_collection.json').readAsStringSync()) as Map;
    final offers = (catalog['offers'] as List)
        .where((o) => o['itemType'] == 'avatar' && o['enabled'] == true).toList();
    expect(collectionAvatars.length, 123);
    expect(collectionAvatars.map((a) => a.id).toSet(),
        offers.map((o) => o['itemId']).toSet());
    for (final avatar in collectionAvatars) {
      expect(File(assetFor(avatar.id)).existsSync(), isTrue, reason: avatar.id);
      expect(offers.singleWhere((o) => o['itemId'] == avatar.id)['subtitle'], contains('portresi'));
    }
    for (final id in ['persona_anthony_nwakaeme', 'persona_marek_hamsik']) {
      expect(UserAvatarCatalog.contains(id), isFalse);
    }
    for (final slug in ['metin_oktay', 'lefter_kucukandonyadis', 'gabriel_batistuta',
      'patrick_vieira', 'oliver_kahn', 'cafu', 'arda_turan', 'cesc_fabregas']) {
      expect(UserAvatarCatalog.contains('persona_$slug'), isTrue);
    }
    final coach = UploadedPortraitCatalog.forAvatarId('persona_pep_guardiola')!;
    final player = UploadedPortraitCatalog.forPlayerId(4000000062)!;
    expect(coach.asset, isNot(player.asset));
    expect(UploadedPortraitCatalog.forAvatarId('persona_pep_guardiola_player'), same(player));
    for (final id in [466279, 203655, 164148, 186623, 424784, 588097]) {
      expect(UploadedPortraitCatalog.forPlayerId(id), isNull, reason: 'Namesake $id');
    }
    expect(UploadedPortraitCatalog.coachPlayerIds['seed_zidane'], 3111);
    expect(UploadedPortraitCatalog.coachKeys['seed_xavi'], 'xavi');
  });

  for (var page = 0; page < 5; page++) {
    testWidgets('avatar portraits page $page decodes with locks and no monograms', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final avatars = collectionAvatars.skip(page * 30).take(30).toList();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter')),
        home: Scaffold(body: Center(child: RepaintBoundary(key: key,
          child: Material(color: const Color(0xFF101E19), child: SizedBox(width: 850,
            child: Wrap(runSpacing: 14, children: [
              for (final avatar in avatars) SizedBox(width: 170, height: 145,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  UserAvatarBadge(avatarId: avatar.id, radius: 44, showLocked: true),
                  const SizedBox(height: 6),
                  Text(avatar.title, textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ])),
            ])),
          ),
        ))),
      ));
      await tester.runAsync(() async {
        for (final asset in avatars.map((a) => assetFor(a.id)).toSet()) {
          final sourceWidth = UploadedPortraitCatalog.portraits.values
              .where((s) => s.asset == asset).firstOrNull?.sheetWidth;
          final provider = sourceWidth == null ? AssetImage(asset) as ImageProvider
              : ResizeImage(AssetImage(asset), width: sourceWidth > 1024 ? 1024 : sourceWidth.toInt());
          await precacheImage(provider, key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(avatars.length));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(avatars.length));
      expect(find.byType(RawImage).evaluate().where((e) => (e.widget as RawImage).image != null).length,
          avatars.length);
      expect(find.text('EÖ'), findsNothing);
      expect(find.text('MA'), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/identity_qa/profile-portraits-$page.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
