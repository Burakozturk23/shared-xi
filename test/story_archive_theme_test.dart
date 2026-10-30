import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/controllers/international_glory_controller.dart';
import 'package:shared_xi/controllers/turkish_nostalgia_controller.dart';
import 'package:shared_xi/models/international_match.dart';
import 'package:shared_xi/models/turkish_nostalgia_state.dart';
import 'package:shared_xi/screens/international_glory_page.dart';
import 'package:shared_xi/screens/turkish_nostalgia_page.dart';
import 'package:shared_xi/screens/story_mode_selection_page.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/story_archive_ui.dart';
import 'five_mode_expansion_test.dart' show ExpansionGateway;
import 'international_glory_test.dart' show MemoryInternationalStore;
import 'turkish_nostalgia_test.dart' show MemoryStore, drained;

Future<void> waitForArchive(WidgetTester t) async {
  // Catalog assets use real I/O rather than the widget test clock.
  await t.runAsync(() async {
    for (var i = 0; i < 100; i++) {
      await t.pump();
      if (find.byType(StoryArchiveHero).evaluate().isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  });
  await t.pumpAndSettle();
  expect(find.byType(StoryArchiveHero), findsOneWidget);
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/expansion_qa/theme-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final (name, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  for (final light in [false, true]) {
    for (final index in [3, 4]) {
      testWidgets(
        'story menu keeps modern theme for mode $index light=$light',
        (t) async {
          final observer = RouteAppearanceObserver();
          addTearDown(observer.dispose);
          await t.pumpWidget(
            MaterialApp(
              theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
              navigatorObservers: [observer],
              builder: (context, child) => ValueListenableBuilder<bool>(
                valueListenable: observer.legacy,
                builder: (context, legacy, _) => Theme(
                  data: legacy ? AppTheme.legacyDarkTheme : Theme.of(context),
                  child: child!,
                ),
              ),
              home: const StoryModeSelectionPage(),
            ),
          );
          await t.scrollUntilVisible(
            find.byKey(ValueKey('story-mode-$index')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await t.tap(find.byKey(ValueKey('story-mode-$index')));
          await waitForArchive(t);
          expect(observer.legacy.value, isFalse);
          final theme = Theme.of(t.element(find.byType(StoryArchiveHero)));
          expect(theme.brightness, light ? Brightness.light : Brightness.dark);
          expect(theme.extension<PitchColors>(), isNotNull);
          expect(theme.colorScheme.primary, PitchColors.lime);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        },
      );
    }
    for (final large in [false, true]) {
      testWidgets(
        'archive reward details and album filters light=$light large=$large',
        (t) async {
          t.view.physicalSize = Size(large ? 320 : 390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final catalogs = await t.runAsync(
            () async => [
              await NostalgiaCatalog.load(),
              await InternationalCatalog.load(),
            ],
          );
          final tn = TurkishNostalgiaController(
            catalog: catalogs![0] as NostalgiaCatalog,
            store: MemoryStore(),
            gateway: ExpansionGateway('nostalgia', 2),
          );
          final ig = InternationalGloryController(
            catalog: catalogs[1] as InternationalCatalog,
            store: MemoryInternationalStore(),
            gateway: ExpansionGateway('international', 2),
          );
          await tn.load();
          await drained(tn);
          await ig.load();
          addTearDown(tn.dispose);
          addTearDown(ig.dispose);
          final key = GlobalKey();
          Future<void> mount(Widget page) async {
            await t.pumpWidget(
              MaterialApp(
                theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
                  child: RepaintBoundary(key: key, child: child!),
                ),
                home: page,
              ),
            );
            await t.pumpAndSettle();
          }

          Future<void> reveal(Finder finder) async {
            await t.scrollUntilVisible(
              finder,
              200,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 60,
            );
            await t.pumpAndSettle();
          }

          await mount(TurkishNostalgiaPage(controller: tn));
          await capture(t, key, 'nostalgia-$light-$large');
          await reveal(find.text('Her görev · 6 Coin + 15 XP'));
          await t.tap(find.text('Her görev · 6 Coin + 15 XP'));
          await t.pumpAndSettle();
          expect(
            find.textContaining('Her bölüm: 15 Coin + 30 XP'),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await mount(InternationalGloryPage(controller: ig));
          await capture(t, key, 'international-$light-$large');
          await reveal(find.text('Her maç · 8 Coin + 20 XP'));
          await t.tap(find.text('Her maç · 8 Coin + 20 XP'));
          await t.pumpAndSettle();
          expect(find.text('40 maç · +120 Coin'), findsOneWidget);
          await reveal(find.byKey(const ValueKey('ig-album')));
          await t.tap(find.byKey(const ValueKey('ig-album')));
          await t.pumpAndSettle();
          await reveal(find.widgetWithText(FilterChip, 'EURO'));
          await t.tap(find.widgetWithText(FilterChip, 'EURO'));
          await t.pumpAndSettle();
          await reveal(find.text('0 / 10 hatıra'));
          expect(find.text('0 / 12 hatıra'), findsNothing);
          await capture(t, key, 'album-$light-$large');
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('profile album links override a saved unfinished task', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({
      'international_glory.v2.offline_guest': jsonEncode({
        'version': 2,
        'activeId': 'ig2_01',
        'phase': 'task',
      }),
    });
    await t.pumpWidget(
      MaterialApp(
        theme: OrtakSahaTheme.dark,
        home: const InternationalGloryPage(openAlbum: true),
      ),
    );
    await waitForArchive(t);
    expect(
      t.widget<StoryArchiveHero>(find.byType(StoryArchiveHero)).title,
      'Milletler Albümü',
    );
    expect(find.byKey(const ValueKey('ig-submit')), findsNothing);
    await t.pumpWidget(const SizedBox());
    SharedPreferences.setMockInitialValues({
      'turkish_nostalgia.v2.offline_guest': jsonEncode({
        'schema': 2,
        'activeId': 'tn2_c01',
        'phase': 'task',
      }),
    });
    await t.pumpWidget(
      MaterialApp(
        theme: OrtakSahaTheme.light,
        home: const TurkishNostalgiaPage(showAlbum: true),
      ),
    );
    await waitForArchive(t);
    expect(
      t.widget<StoryArchiveHero>(find.byType(StoryArchiveHero)).title,
      'Nostalji Albümü',
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
