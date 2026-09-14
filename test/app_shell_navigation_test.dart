import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/main.dart';
import 'package:shared_xi/screens/app_settings_page.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/screens/onboarding_page.dart';
import 'package:shared_xi/screens/sign_in_page.dart';
import 'package:shared_xi/widgets/pitch_tile.dart';

Future<AppPreferences> openApp(
  WidgetTester tester, {
  bool firstLaunch = false,
}) async {
  tester.view.physicalSize = const Size(416, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await AppPreferences.load();
  if (!firstLaunch) await prefs.finishOnboarding();
  addTearDown(prefs.dispose);
  await tester.pumpWidget(SharedXIApp(preferences: prefs));
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'User-approved groups contain every game once in the requested order',
    () {
      const expected = {
        'Kadro & Yönetim': [
          'Club Manager',
          'Squad Challenge',
          'Teknik Direktör XI',
          'Kadro Kasası',
          'Letter 11',
        ],
        'Kariyer & Oyuncu': [
          'Career Puzzle',
          'Transfer Detective',
          'Mystery Player',
          'Chain',
          'Fake Club',
        ],
        'Harf & Kelime': ['Futbol Lingo', 'Passaparola'],
        'Hız & Eşleştirme': ['Burst', 'Pyramid', 'Matching'],
        'Seçim & Sıralama': [
          'This or That?',
          'Higher or Lower',
          'Blind Ranking',
        ],
        'Hikâye': ['Story Mode'],
      };
      expect(GameCatalog.groups.map((group) => group.title), expected.keys);
      for (final group in expected.entries) {
        expect(
          GameCatalog.games
              .where((game) => game.category == group.key)
              .map((game) => game.title),
          group.value,
          reason: group.key,
        );
      }
      expect(GameCatalog.games.where((game) => game.category.isEmpty), [
        GameCatalog.vsBot,
      ]);
      expect(GameCatalog.games.length, 20);
      expect(GameCatalog.games.map((game) => game.title).toSet().length, 20);
    },
  );

  testWidgets('Android back revisits onboarding steps without completing it', (
    tester,
  ) async {
    final prefs = await openApp(tester, firstLaunch: true);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Bağlantıyı\nsen seç.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Her gün\nyeni bir meydan okuma.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('İki kulüp.\nTek bağlantı.'), findsOneWidget);
    expect(prefs.onboardingComplete, isFalse);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    final restored = await AppPreferences.load();
    addTearDown(restored.dispose);
    expect(restored.onboardingComplete, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(SharedXIApp(preferences: restored));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Groups open their own list and global search survives tab back',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Oyunlar').last);
      await tester.pumpAndSettle();
      expect(find.text('Botla oyna'), findsOneWidget);
      expect(find.byType(PitchTile), findsNWidgets(6));
      expect(find.text('Club Manager'), findsNothing);
      await tester.tap(find.text('Kadro & Yönetim'));
      await tester.pumpAndSettle();
      expect(find.text('Club Manager'), findsOneWidget);
      expect(find.text('Vs Bot'), findsNothing);
      await tester.enterText(find.byType(TextField), 'letter');
      await tester.pumpAndSettle();
      expect(find.text('Letter 11'), findsOneWidget);
      expect(find.text('Club Manager'), findsNothing);
      await tester.enterText(find.byType(TextField), 'lingo');
      await tester.pumpAndSettle();
      expect(find.text('Oyun bulunamadı'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Club Manager'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Botla oyna'), findsOneWidget);
      expect(find.byType(PitchTile), findsNWidgets(6));
      await tester.enterText(find.byType(TextField), 'lingo');
      await tester.pumpAndSettle();
      expect(find.text('Futbol Lingo'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.text('Oyunlar').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'lingo',
      );
      expect(find.text('Futbol Lingo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'vs bot');
      await tester.pumpAndSettle();
      expect(find.text('Vs Bot'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'botla oyna');
      await tester.pumpAndSettle();
      expect(find.text('Vs Bot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Both online play actions retain the persistent-account gate', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Online').last);
    await tester.pumpAndSettle();
    for (final label in ['Mod seç', 'Birlikte oyna']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(LinkballSignInPage), findsOneWidget);
      expect(
        tester
            .widget<LinkballSignInPage>(find.byType(LinkballSignInPage))
            .allowSkip,
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LinkballSignInPage), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Theme updates live and onboarding replay returns to settings', (
    tester,
  ) async {
    final prefs = await openApp(tester);
    await tester.tap(find.text('Oyunlar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Açık'));
    await tester.pumpAndSettle();
    expect(prefs.themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(AppSettingsPage))).brightness,
      Brightness.light,
    );
    await tester.scrollUntilVisible(
      find.text('Oyunları tanı'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Oyunları tanı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('İki kulüp.\nTek bağlantı.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(AppSettingsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(GamesCatalogPage))).brightness,
      Brightness.light,
    );
    final restored = await AppPreferences.load();
    addTearDown(restored.dispose);
    expect(restored.themeMode, ThemeMode.light);
    expect(restored.onboardingComplete, isTrue);
    expect(tester.takeException(), isNull);
  });
}
