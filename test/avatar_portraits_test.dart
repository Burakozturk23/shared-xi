import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/player_portrait_catalog.dart';
import 'package:shared_xi/data/season_portrait_catalog.dart';
import 'package:shared_xi/models/store_collection.dart';
import 'package:shared_xi/models/user_avatar_catalog.dart';
import 'package:shared_xi/widgets/player_portrait.dart';
import 'package:shared_xi/widgets/user_avatar_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter-Body-Variable.ttf'))).load();
  });

  test(
    'profile catalog and purchasable avatars agree, portrait IDs resolve',
    () {
      final catalog =
          jsonDecode(
                File(
                  'functions/config/store_collection.json',
                ).readAsStringSync(),
              )
              as Map;
      final offers = (catalog['offers'] as List)
          .where((o) => o['itemType'] == 'avatar')
          .toList();
      expect(collectionAvatars.length, 56);
      expect(
        collectionAvatars.map((a) => a.id).toSet(),
        offers.map((o) => o['itemId']).toSet(),
      );
      expect(PlayerPortraitCatalog.avatarPlayerIds.length, 34);
      for (final entry in PlayerPortraitCatalog.avatarPlayerIds.entries) {
        expect(
          UserAvatarCatalog.contains(entry.key),
          isTrue,
          reason: entry.key,
        );
        expect(
          PlayerPortraitCatalog.forPlayerId(entry.value) != null ||
              SeasonPortraitCatalog.forPlayerId(entry.value) != null,
          isTrue,
          reason: entry.key,
        );
        final offer = offers.singleWhere((o) => o['itemId'] == entry.key);
        expect(offer['subtitle'], contains('portresi'));
      }
      // No approved Buffon image exists in either supplied collection.
      expect(UserAvatarCatalog.contains('persona_gianluigi_buffon'), isTrue);
      expect(
        PlayerPortraitCatalog.playerIdForAvatar('persona_gianluigi_buffon'),
        isNull,
      );
      expect(
        PlayerPortraitCatalog.playerIdForAvatar('persona_cristiano_ronaldo'),
        8198,
      );
      expect(
        PlayerPortraitCatalog.playerIdForAvatar('persona_lionel_messi'),
        28003,
      );
      expect(
        PlayerPortraitCatalog.playerIdForAvatar('persona_ronaldo_nazario'),
        3140,
      );
    },
  );

  testWidgets(
    'profile picker renders all available faces with locks and honest fallbacks',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final ids = [
        ...PlayerPortraitCatalog.avatarPlayerIds.keys,
        'persona_gianluigi_buffon',
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Material(
                  color: const Color(0xFF101E19),
                  child: SizedBox(
                    width: 850,
                    child: Wrap(
                      runSpacing: 14,
                      children: [
                        for (final id in ids)
                          SizedBox(
                            width: 170,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UserAvatarBadge(
                                  avatarId: id,
                                  radius: 40,
                                  showLocked: true,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  UserAvatarCatalog.byId(id)!.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = key.currentContext!;
        final assets = <String>{};
        for (final id in PlayerPortraitCatalog.avatarPlayerIds.values) {
          final asset =
              PlayerPortraitCatalog.forPlayerId(id) ??
              SeasonPortraitCatalog.forPlayerId(id)!.asset;
          assets.add(asset);
        }
        await Future.wait(
          assets.map((a) => precacheImage(AssetImage(a), context)),
        );
      });
      await tester.pumpAndSettle();
      expect(find.byType(PlayerPortrait), findsNWidgets(34));
      expect(find.byType(Image), findsNWidgets(34));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(35));
      expect(find.text('GB'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/identity_qa/profile-portraits.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
