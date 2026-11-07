import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/season_pass.dart';
import 'package:shared_xi/models/achievement_catalog.dart';
import 'package:shared_xi/models/achievement_models.dart';
import 'package:shared_xi/screens/season_pass_page.dart';
import 'package:shared_xi/screens/achievements_page.dart';
import 'package:shared_xi/services/experience/season_gateway.dart';
import 'package:shared_xi/services/experience/badges_gateway.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

class SeasonFake extends SeasonGateway {
  bool pro = false, fail = false, grace = false;
  int daysLeft = 20;
  final previousIds = <String>[];
  int claims = 0;
  final claimed = <String>{};
  @override
  bool get connected => true;
  @override
  Future<SeasonPass> load() async {
    if (fail) throw StateError('unavailable');
    return SeasonPass(
      id: '2026-10',
      endsOn: '2026-10-31',
      sp: 550,
      todaySp: 90,
      level: 5,
      daysLeft: daysLeft,
      pro: pro,
      previous: grace && !claimed.contains('old_free')
          ? SeasonPrevious(
              id: '2026-09',
              level: 2,
              claimDaysLeft: 2,
              tiers: List.generate(
                20,
                (i) => SeasonTier(
                  step: i + 1,
                  requiredSp: (i + 1) * 100,
                  unlocked: i == 1,
                  freeCoins: 20,
                  proCoins: 40,
                  freeClaimed: false,
                  proClaimed: false,
                ),
              ),
            )
          : null,
      tiers: List.generate(
        20,
        (i) => SeasonTier(
          step: i + 1,
          requiredSp: (i + 1) * 100,
          unlocked: i < 5,
          freeCoins: (i + 1) % 5 == 0 ? 60 : 20,
          proCoins: (i + 1) % 5 == 0 ? 100 : 40,
          freeClaimed: claimed.contains('${i + 1}_free'),
          proClaimed: claimed.contains('${i + 1}_pro'),
        ),
      ),
    );
  }

  @override
  Future<SeasonPass> claim(String id, int step, String lane) async {
    claims++;
    if (id == '2026-09') {
      previousIds.add('$id/$step/$lane');
      claimed.add('old_$lane');
    } else {
      claimed.add('${step}_$lane');
    }
    return load();
  }
}

class BadgesFake extends BadgesGateway {
  @override
  bool get connected => true;
  @override
  Future<BadgeSnapshot> load() async => BadgeSnapshot(
    {
      for (final d in AchievementCatalog.all)
        d.id: AchievementProgress(
          id: d.id,
          value: d.signal == 'ranked_wins' ? 1 : 0,
          rawValue: d.signal == 'ranked_wins' ? 1 : 0,
          target: d.target,
          unlocked: d.id == 'first_victory',
        ),
    },
    {},
    {},
  );
}

final previewKey = GlobalKey();
Future<void> open(WidgetTester t, Widget page, {double scale = 1}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: OrtakSahaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: previewKey, child: page),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 240);
  await t.pumpAndSettle();
}

Future<void> preview(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.dart_tool/season_qa').create(recursive: true);
    await File(
      '.dart_tool/season_qa/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  testWidgets('free track claims once and Pro stays locked', (t) async {
    final g = SeasonFake();
    await open(t, SeasonPassPage(gateway: g));
    expect(find.text('50 SP sonra sıradaki ödül'), findsOneWidget);
    await preview(t, 'season-home');
    final button = find.byKey(const ValueKey('season-1-free'));
    await reveal(t, button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(g.claims, 1);
    expect(find.text('Alındı'), findsOneWidget);
    final pro = find.byKey(const ValueKey('season-1-pro'));
    expect(t.widget<FilledButton>(pro).onPressed, isNull);
    await preview(t, 'season-rewards');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'season shows the pace, warns at month end and claims last month in the grace days',
    (t) async {
      final g = SeasonFake()
        ..grace = true
        ..daysLeft = 2;
      await open(t, SeasonPassPage(gateway: g));
      // 550 SP on day 30 of 31: about tier 5 at month end; 725 SP a day is out of reach.
      expect(
        find.textContaining('Bu tempoyla ay sonunda Kademe 5'),
        findsOneWidget,
      );
      expect(find.textContaining('rotanın tamamı yetişmez'), findsOneWidget);
      final previous = find.text('Geçen ayın ödüllerini al');
      await reveal(t, previous);
      await t.tap(previous);
      await t.pumpAndSettle();
      expect(g.previousIds, ['2026-09/2/free']);
      expect(find.byKey(const ValueKey('season-previous')), findsNothing);
      // Back to the top: the list moved up when the grace card closed.
      await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await t.pumpAndSettle();
      final ending = find.byKey(const ValueKey('season-ending'));
      await reveal(t, ending);
      expect(ending, findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Pro shares progress and unlocks earned second-track reward', (
    t,
  ) async {
    final g = SeasonFake()..pro = true;
    await open(t, SeasonPassPage(gateway: g));
    expect(find.text('Pro rotan açık'), findsOneWidget);
    final button = find.byKey(const ValueKey('season-1-pro'));
    await reveal(t, button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(g.claimed, contains('1_pro'));
    await t.tap(find.byTooltip('Yenile'));
    await t.pumpAndSettle();
    expect(g.claims, 1);
    expect(find.text('Alındı'), findsOneWidget);
  });
  testWidgets('retry and large text retain accessible reward actions', (
    t,
  ) async {
    final g = SeasonFake()..fail = true;
    await open(t, SeasonPassPage(gateway: g), scale: 1.5);
    expect(find.text('Sezon yüklenemedi'), findsOneWidget);
    g.fail = false;
    await t.tap(find.byTooltip('Yenile'));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(const ValueKey('season-1-free')));
    await preview(t, 'season-large');
    expect(t.takeException(), isNull);
  });
  testWidgets('badge overview groups achievements and exposes 750-win target', (
    t,
  ) async {
    await open(t, AchievementsPage(gateway: BadgesFake()));
    expect(find.text('1 rozet senin.'), findsOneWidget);
    await preview(t, 'badges-home');
    await reveal(t, find.widgetWithText(ChoiceChip, 'Galibiyet'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Galibiyet'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Linkball İkonu'));
    expect(find.text('750 dereceli galibiyet kazan.'), findsOneWidget);
    await t.tap(find.text('Linkball İkonu'));
    await t.pumpAndSettle();
    expect(find.text('Koleksiyona dön'), findsOneWidget);
    expect(t.takeException(), isNull);
    await preview(t, 'badge-details');
  });
}
