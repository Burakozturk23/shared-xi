import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/app/bot_game_catalog.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/main.dart';
import 'package:shared_xi/repositories/repository.dart';
import 'package:shared_xi/screens/bot_game_detail_page.dart';
import 'package:shared_xi/screens/vs_bot_grid_mode_selection_page.dart';
import 'package:shared_xi/screens/vs_bot_mode_selection_page.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/bot_mode_card.dart';
import 'package:shared_xi/widgets/pitch_ui.dart';

int _gameStarts = 0;

class _StartedGame extends StatefulWidget {
  const _StartedGame();

  @override
  State<_StartedGame> createState() => _StartedGameState();
}

class _StartedGameState extends State<_StartedGame> {
  @override
  void initState() {
    super.initState();
    _gameStarts++;
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Game started')),
  );
}

Future<AppPreferences> _openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(416, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await AppPreferences.load();
  addTearDown(prefs.dispose);
  await prefs.finishOnboarding();
  await prefs.setTheme(ThemeMode.light);
  await tester.pumpWidget(SharedXIApp(preferences: prefs));
  await tester.pumpAndSettle();
  return prefs;
}

Finder get _verticalScroll => find.byWidgetPredicate(
  (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
).last;

Future<void> _openCard(WidgetTester tester, String title) async {
  final card = find.widgetWithText(BotModeCard, title);
  await tester.scrollUntilVisible(card, 200, scrollable: _verticalScroll);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _gameStarts = 0;
  });

  test('Migrated bot entries prepare V4 sessions and preserve account gates', () {
    expect(GameCatalog.vsBot.modern, isTrue);
    expect(GameCatalog.vsBot.requiresRepository, isFalse);
    expect(GameCatalog.vsBot.requiresAuth, isFalse);
    expect(BotGameCatalog.all.length, 7);
    expect(BotGameCatalog.all.map((g) => g.entry.page.runtimeType).toSet().length, 7);
    for (final game in BotGameCatalog.all) {
      final migrated = [BotGameCatalog.loto, BotGameCatalog.teamRace,
        BotGameCatalog.classicGrid, BotGameCatalog.cinko].contains(game);
      expect(game.entry.requiresRepository, !migrated);
      expect(game.entry.requiresAuth, isFalse);
      expect(game.entry.requiresPersistentAccount, isFalse);
      expect(game.entry.modern, migrated);
    }
  });

  testWidgets('All bot rules open without starting games and Android back retains context', (tester) async {
    await _openApp(tester);
    final repositoryWasReady = Repository.instance.isInitialized;
    await tester.tap(find.text('Oyunlar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Botla oyna'));
    await tester.pumpAndSettle();
    expect(find.byType(VsBotModeSelectionPage), findsOneWidget);

    for (final game in [
      BotGameCatalog.loto,
      BotGameCatalog.teamRace,
      BotGameCatalog.cinko,
      BotGameCatalog.five,
    ]) {
      await _openCard(tester, game.entry.title);
      expect(tester.widget<BotGameDetailPage>(find.byType(BotGameDetailPage)).game, same(game));
      expect(find.byType(game.entry.page.runtimeType), findsNothing);
      expect(find.widgetWithText(PitchAction, game.action), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(BotGameDetailPage))).brightness, Brightness.light);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VsBotModeSelectionPage), findsOneWidget);
    }

    await _openCard(tester, 'Grid');
    expect(find.byType(VsBotGridModeSelectionPage), findsOneWidget);
    for (final game in BotGameCatalog.gridVariants) {
      await _openCard(tester, game.entry.title);
      expect(tester.widget<BotGameDetailPage>(find.byType(BotGameDetailPage)).game, same(game));
      expect(find.byType(game.entry.page.runtimeType), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VsBotGridModeSelectionPage), findsOneWidget);
    }
    expect(Repository.instance.isInitialized, repositoryWasReady);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VsBotModeSelectionPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The explicit play action starts once and returns to light rules', (tester) async {
    await _openApp(tester);
    const game = BotGameDefinition(
      entry: GameEntry(
        title: 'Test game',
        subtitle: '',
        icon: Icons.sports_esports_outlined,
        page: _StartedGame(),
        requiresRepository: false,
      ),
      tags: ['Test'],
      goal: 'Read before playing',
      steps: [('One', 'Read the rule')],
      scoring: 'Test scoring',
    );
    Navigator.of(tester.element(find.byType(NavigationBar))).push(
      LinkballRoute(builder: (_) => const BotGameDetailPage(game: game)),
    );
    await tester.pumpAndSettle();
    expect(_gameStarts, 0);
    await tester.tap(find.text('Oyuna başla'));
    await tester.tap(find.text('Oyuna başla'));
    await tester.pumpAndSettle();
    expect(_gameStarts, 1);
    expect(find.text('Game started'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(_StartedGame))).brightness, Brightness.dark);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BotGameDetailPage), findsOneWidget);
    expect(find.widgetWithText(PitchAction, 'Oyuna başla'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(BotGameDetailPage))).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bot menus and every rules page support large text and safe-area actions', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (size, scale, dark) in [
      (const Size(416, 896), 1.0, true),
      (const Size(416, 896), 1.0, false),
      (const Size(320, 568), 2.0, true),
      (const Size(700, 400), 2.0, false),
    ]) {
      for (final page in <Widget>[
        const VsBotModeSelectionPage(),
        const VsBotGridModeSelectionPage(),
        for (final game in BotGameCatalog.all) BotGameDetailPage(game: game),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child!,
          ),
          home: page,
        ));
        await tester.pumpAndSettle();
        if (page is BotGameDetailPage) {
          final action = find.widgetWithText(PitchAction, page.game.action);
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getRect(action).bottom, lessThanOrEqualTo(size.height - 24));
          await tester.scrollUntilVisible(
            find.text('Skor ve kazanma'),
            200,
            scrollable: _verticalScroll,
          );
          await tester.pumpAndSettle();
          expect(find.text('Skor ve kazanma').hitTestable(), findsOneWidget);
        } else {
          final lastTitle = page is VsBotModeSelectionPage
              ? BotGameCatalog.five.entry.title
              : BotGameCatalog.randomGrid.entry.title;
          final lastCard = find.widgetWithText(BotModeCard, lastTitle);
          await tester.scrollUntilVisible(lastCard, 200, scrollable: _verticalScroll);
          await tester.pumpAndSettle();
          expect(lastCard.hitTestable(), findsOneWidget,
              reason: size.toString() + ' scale=' + scale.toString() + ' card=' + tester.getRect(lastCard).toString());
        }
        expect(tester.takeException(), isNull,
            reason: page.runtimeType.toString() + ' ' + size.toString() + ' scale=' + scale.toString());
      }
    }
  });
}
