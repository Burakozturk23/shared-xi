import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/controllers/daily_challenge_controller.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/daily_challenge_state.dart';
import 'package:shared_xi/models/match_entity.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/screens/app_settings_page.dart';
import 'package:shared_xi/screens/daily_challenge_game_page.dart';
import 'package:shared_xi/screens/discovery_selection_page.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/screens/onboarding_page.dart';
import 'package:shared_xi/screens/shared_players_result_page.dart';
import 'package:shared_xi/screens/welcome_page.dart';
import 'package:shared_xi/theme/app_theme.dart';

const arsenal = Club(
  id: 11,
  name: 'Arsenal',
  league: 'Premier League',
  country: 'England',
);
const barcelona = Club(
  id: 131,
  name: 'Barcelona',
  league: 'LaLiga',
  country: 'Spain',
);
final henry = Player.fromJson({
  'id': 14,
  'name': 'Thierry Henry',
  'position': 'Attack',
  'countries': ['France'],
  'clubIds': [11, 131],
});

class FakeDailyController extends DailyChallengeController {
  DailyChallengeState current = DailyChallengeState(
    isLoading: false,
    entity1: MatchEntity.club(arsenal),
    entity2: MatchEntity.club(barcelona),
    matchingPlayers: [henry],
  );
  @override
  DailyChallengeState get state => current;
  @override
  Future<void> initialize() async {}
  @override
  void updateSuggestions(String query) {}
  @override
  void clearSuggestions() {}
  @override
  void submitAnswer(String input) {
    current = input == 'Henry'
        ? current.copyWith(
            foundPlayers: [henry],
            foundPlayerIds: {henry.id},
            feedback: 'Doğru!',
            feedbackIsSuccess: true,
          )
        : current.copyWith(
            wrongAttempts: {...current.wrongAttempts, input},
            feedback: 'Bu eşleşmede yer almıyor.',
            feedbackIsSuccess: false,
          );
    notifyListeners();
  }
}

Future<void> frame(
  WidgetTester tester,
  Widget page,
  AppPreferences preferences, {
  Size size = const Size(416, 896),
  double scale = 1,
  bool dark = true,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    PreferencesScope(
      preferences: preferences,
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: capture, child: child!),
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> screenshot(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/ortak_saha_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Preferences survive recreation and onboarding completion is explicit',
    () async {
      final prefs = await AppPreferences.load();
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.onboardingComplete, isFalse);
      await prefs.setTheme(ThemeMode.light);
      await prefs.setSound(false);
      await prefs.setHaptics(false);
      await prefs.setNotification('daily', true);
      await prefs.finishOnboarding();
      final restored = await AppPreferences.load();
      expect(restored.themeMode, ThemeMode.light);
      expect(restored.sound, isFalse);
      expect(restored.haptics, isFalse);
      expect(restored.notification('daily'), isTrue);
      expect(restored.notification('social'), isFalse);
      expect(restored.onboardingComplete, isTrue);
      restored.dispose();
      prefs.dispose();
    },
  );

  test(
    'Existing mode catalog keeps data and authentication entry requirements',
    () {
      expect(GameCatalog.games.length, 20);
      expect(GameCatalog.daily.requiresAuth, isTrue);
      expect(GameCatalog.daily.requiresRepository, isTrue);
      expect(GameCatalog.discovery.requiresRepository, isFalse);
      expect(GameCatalog.games.map((game) => game.title).toSet().length, 20);
    },
  );

  testWidgets('Four onboarding steps support back, completion and skip', (
    tester,
  ) async {
    final prefs = await AppPreferences.load();
    var completed = 0;
    await frame(tester, OnboardingPage(onComplete: () => completed++), prefs);
    expect(find.text('İki kulüp.\nTek bağlantı.'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Her gün\nyeni bir meydan okuma.'), findsOneWidget);
    await tester.tap(find.byTooltip('Önceki adım'));
    await tester.pumpAndSettle();
    expect(find.text('İki kulüp.\nTek bağlantı.'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Futbolu bildiğin\ngibi oyna.'), findsOneWidget);
    expect(prefs.onboardingComplete, isFalse);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(prefs.onboardingComplete, isTrue);
    await frame(
      tester,
      OnboardingPage(
        key: const ValueKey('replay'),
        onComplete: () => completed++,
      ),
      prefs,
    );
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(completed, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Core shell, onboarding and settings remain usable with large text',
    (tester) async {
      final prefs = await AppPreferences.load();
      for (final size in [const Size(360, 640), const Size(700, 400)]) {
        for (final scale in [1.0, 2.0]) {
          for (final page in <Widget>[
            const WelcomePage(observeAuth: false),
            OnboardingPage(onComplete: () {}),
            const AppSettingsPage(),
            const Scaffold(body: GamesCatalogPage()),
            GamesCatalogPage(group: GameCatalog.groups.first),
          ]) {
            await frame(tester, page, prefs, size: size, scale: scale);
            expect(
              tester.takeException(),
              isNull,
              reason: '${page.runtimeType} $size scale=$scale',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'Discovery search selects distinct clubs and preserves first club between modes',
    (tester) async {
      final prefs = await AppPreferences.load();
      await frame(
        tester,
        DiscoverySelectionPage(
          catalogLoader: () async => ([arsenal, barcelona], ['France']),
        ),
        prefs,
      );
      final selects = find.text('Seç');
      await tester.tap(selects.first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ars');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arsenal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Arsenal'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Barcelona'));
      await tester.pumpAndSettle();
      expect(find.text('Arsenal'), findsWidgets);
      expect(find.text('Barcelona'), findsWidgets);
      await tester.tap(find.text('Kulüp – Ülke'));
      await tester.pumpAndSettle();
      expect(find.text('Arsenal'), findsWidgets);
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'France'));
      await tester.pumpAndSettle();
      expect(find.text('France'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Discovery failure is recoverable without exposing database errors',
    (tester) async {
      final prefs = await AppPreferences.load();
      var loads = 0;
      await frame(
        tester,
        DiscoverySelectionPage(
          catalogLoader: () async {
            if (++loads == 1) throw StateError('private sqlite details');
            return ([arsenal, barcelona], ['France']);
          },
        ),
        prefs,
      );
      expect(find.text('Kulüpler yüklenemedi'), findsOneWidget);
      expect(find.textContaining('private sqlite'), findsNothing);
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Kulüp – Kulüp'), findsOneWidget);
    },
  );

  testWidgets(
    'Results filters can be cleared and player details retain career clubs',
    (tester) async {
      final prefs = await AppPreferences.load();
      await frame(
        tester,
        SharedPlayersResultPage(
          entity1: MatchEntity.club(arsenal),
          entity2: MatchEntity.club(barcelona),
          resultLoader: () async =>
              ([henry], {11: 'Arsenal', 131: 'Barcelona'}),
        ),
        prefs,
      );
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Filtreleri temizle'));
      await tester.tap(find.text('Filtreleri temizle'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thierry Henry'));
      await tester.tap(find.text('Thierry Henry'));
      await tester.pumpAndSettle();
      expect(find.text('Forma giydiği kulüpler'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wrong daily answer remains editable and correct answer clears input',
    (tester) async {
      final prefs = await AppPreferences.load();
      await frame(
        tester,
        DailyChallengeGamePage(controllerFactory: FakeDailyController.new),
        prefs,
      );
      await tester.enterText(find.byType(TextField), 'Yanlış');
      await tester.ensureVisible(find.text('Yanıtı kontrol et'));
      await tester.tap(find.text('Yanıtı kontrol et'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Yanlış',
      );
      await tester.enterText(find.byType(TextField), 'Henry');
      await tester.ensureVisible(find.text('Yanıtı kontrol et'));
      await tester.tap(find.text('Yanıtı kontrol et'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Doğru!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Legacy children inherit dark appearance and popping restores chosen theme',
    (tester) async {
      final observer = RouteAppearanceObserver();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
        ),
      );
      nav.currentState!.push(
        LinkballRoute<void>(
          modern: false,
          builder: (_) => const Scaffold(body: Text('Legacy')),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.legacy.value, isTrue);
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Child')),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.legacy.value, isTrue);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.legacy.value, isTrue);
      nav.currentState!.push(
        LinkballRoute<void>(
          builder: (_) => const Scaffold(body: Text('Modern')),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.legacy.value, isFalse);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.legacy.value, isTrue);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.legacy.value, isFalse);
      await tester.pumpWidget(const SizedBox());
      observer.dispose();
    },
  );

  testWidgets('Dark and light screen review', (tester) async {
    final prefs = await AppPreferences.load();
    final capture = GlobalKey();
    for (final dark in [true, false]) {
      final suffix = dark ? 'dark' : 'light';
      for (final (name, page) in <(String, Widget)>[
        ('home', const WelcomePage(observeAuth: false)),
        ('games', const Scaffold(body: GamesCatalogPage())),
        ('squad-group', GamesCatalogPage(group: GameCatalog.groups.first)),
        ('onboarding', OnboardingPage(onComplete: () {})),
        (
          'discovery',
          DiscoverySelectionPage(
            prefillClub: arsenal,
            catalogLoader: () async => ([arsenal, barcelona], ['France']),
          ),
        ),
        (
          'results',
          SharedPlayersResultPage(
            entity1: MatchEntity.club(arsenal),
            entity2: MatchEntity.club(barcelona),
            resultLoader: () async =>
                ([henry], {11: 'Arsenal', 131: 'Barcelona'}),
          ),
        ),
        (
          'daily',
          DailyChallengeGamePage(controllerFactory: FakeDailyController.new),
        ),
        ('settings', const AppSettingsPage()),
      ]) {
        await frame(tester, page, prefs, dark: dark, capture: capture);
        expect(tester.takeException(), isNull, reason: '$name $suffix');
        await screenshot(tester, capture, '$name-$suffix');
      }
    }
  });
}
