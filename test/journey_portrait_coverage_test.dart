import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/data/player_journey_chapters.dart';
import 'package:shared_xi/data/player_portrait_catalog.dart';
import 'package:shared_xi/data/season_portrait_catalog.dart';
import 'package:shared_xi/data/uploaded_portrait_catalog.dart';
import 'package:shared_xi/screens/journey_passport_page.dart';
import 'package:shared_xi/screens/player_journey_chapter_list_page.dart';
import 'package:shared_xi/screens/player_journey_list_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/pitch_ui.dart';
import 'package:shared_xi/widgets/player_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all 40 journey identities resolve to bundled portraits in list and passport',
    () async {
      final journeys = await loadPassportJourneys();
      expect(journeys.length, 40);
      for (final entry in playerJourneyChapters.expand((c) => c.journeys)) {
        final journey = journeys.singleWhere((j) => j.id == entry.id);
        expect(
          entry.subjectPlayerId,
          journey.playerId,
          reason: entry.subjectName,
        );
        final asset =
            UploadedPortraitCatalog.forPlayerId(journey.playerId)?.asset ??
            PlayerPortraitCatalog.forPlayerId(journey.playerId) ??
            SeasonPortraitCatalog.forPlayerId(journey.playerId)?.asset;
        expect(asset, isNotNull, reason: journey.name);
        expect(File(asset!).existsSync(), isTrue, reason: journey.name);
      }
      for (final slug in [
        'kaka',
        'jamie_vardy',
        'mesut_ozil',
        'christian_eriksen',
        'mohamed_salah',
        'radamel_falcao',
        'toni_kroos',
        'adriano',
        'wayne_rooney',
        'eden_hazard',
      ]) {
        final id = UploadedPortraitCatalog.avatarPlayerIds['persona_$slug']!;
        expect(
          UploadedPortraitCatalog.forAvatarId('persona_$slug'),
          same(UploadedPortraitCatalog.forPlayerId(id)),
        );
      }
    },
  );
  for (final light in [false, true]) {
    testWidgets(
      'portraits remain visible on locked careers; small screen $light',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        Widget app(Widget page) => MaterialApp(
          theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: page,
        );
        await tester.pumpWidget(app(const PlayerJourneyChapterListPage()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'chapters-$light');
        await tester.pumpWidget(
          app(PlayerJourneyListPage(chapter: playerJourneyChapters[1])),
        );
        await tester.pumpAndSettle();
        final locked = find.byKey(const ValueKey('journey-player-drogba'));
        await tester.scrollUntilVisible(locked, 200);
        await tester.pumpAndSettle();
        final row = tester.widget<PitchRow>(locked);
        expect(row.onTap, isNull); // Artwork must not unlock a career.
        expect(
          find.descendant(of: locked, matching: find.byType(PlayerAvatar)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: locked,
            matching: find.byIcon(Icons.lock_outline),
          ),
          findsOneWidget,
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'locked-portraits-$light');
        final journeys = await tester.runAsync(loadPassportJourneys);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: SingleChildScrollView(
                child: Wrap(
                  children: [
                    for (final j in journeys!)
                      SizedBox(
                        width: 80,
                        height: 120,
                        child: Column(
                          children: [
                            PlayerAvatar(player: passportPlayer(j), size: 64),
                            Text(
                              j.name,
                              textScaler: TextScaler.noScaling,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'portraits-top-$light');
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'portraits-bottom-$light');
      },
    );
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/journey_qa/portrait-refresh-$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
