import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/build_xi_formation_selection_page.dart';
import 'package:shared_xi/screens/build_xi_page.dart';
import 'package:shared_xi/screens/build_xi_theme_selection_page.dart';
import 'package:shared_xi/services/squad_challenge_progress_service.dart';
import 'package:shared_xi/services/squad_challenge_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

import 'support/squad_fixture.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  final vertical = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .last;
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: vertical,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, int slot, int player) async {
  final target = find.byKey(Key('squad-slot-$slot'));
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('squad-player-search')),
    'Futbolcu $player',
  );
  await tester.pumpAndSettle();
  // Match the result label, excluding the identical EditableText search value.
  final candidate = find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == 'Futbolcu $player',
  );
  await reveal(tester, candidate);
  await tester.tap(candidate);
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final catalog = squadFixture();

  for (final (size, scale, dark) in [
    (const Size(390, 844), 1.0, true),
    (const Size(320, 568), 2.0, false),
    (const Size(700, 400), 2.0, true),
  ]) {
    testWidgets(
      'Offline practice completes and returns without a stacked formation route: $size / $scale',
      (tester) async {
        final gateway = FakeSquadGateway()..userId = null;
        final progress = SquadChallengeProgressService();
        await open(
          tester,
          BuildXiThemeSelectionPage(
            gateway: gateway,
            loadCatalog: () async => catalog,
            progress: progress,
          ),
          size: size,
          scale: scale,
          dark: dark,
        );
        expect(gateway.loads, 0);
        await tester.ensureVisible(find.text('Antrenman'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Antrenman'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Deneme Ligi'));
        await tester.tap(find.text('Deneme Ligi'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('4-3-3'));
        await tester.tap(find.text('4-3-3'));
        await tester.pumpAndSettle();
        expect(find.byType(BuildXiPage), findsOneWidget);
        for (var i = 0; i < 11; i++) await select(tester, i, i + 1);
        await tester.tap(find.text('Kadroyu onayla'));
        await tester.pumpAndSettle();
        expect(find.text('Kadro hazır.'), findsOneWidget);
        expect((await progress.records())['fixture'], greaterThan(0));
        expect(gateway.starts, 0);
        expect(gateway.submissions, isEmpty);
        await tester.tap(find.text('Antrenmana dön'));
        await tester.pumpAndSettle();
        expect(find.byType(BuildXiThemeSelectionPage), findsOneWidget);
        expect(find.byType(BuildXiFormationSelectionPage), findsNothing);
        expect(find.byType(BuildXiPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Paid entry requires consent; backing out and resuming keeps the draft and one charge',
    (tester) async {
      final gateway = FakeSquadGateway()..free = 0;
      final drafts = SquadDraftStore();
      await open(
        tester,
        BuildXiThemeSelectionPage(
          gateway: gateway,
          loadCatalog: () async => catalog,
          drafts: drafts,
          progress: SquadChallengeProgressService(),
        ),
      );
      await reveal(tester, find.text('Başla · 20 Link Coin'));
      await tester.tap(find.text('Başla · 20 Link Coin'));
      await tester.pumpAndSettle();
      expect(find.text('20 Link Coinle ek deneme?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(gateway.starts, 0);
      expect(gateway.coins, 100);
      await tester.tap(find.text('Başla · 20 Link Coin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20 Link Coin kullan'));
      await tester.pumpAndSettle();
      expect(gateway.starts, 1);
      expect(gateway.quotedPrices, [20]);
      expect(gateway.coins, 80);
      await select(tester, 0, 1);
      final runId = gateway.active!.id;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect((await drafts.load('alice', runId))[0], 1);
      await reveal(tester, find.text('Göreve devam et · Ücretsiz'));
      await tester.tap(find.text('Göreve devam et · Ücretsiz'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Futbolcu 1'));
      expect(find.text('Futbolcu 1'), findsOneWidget);
      expect(gateway.starts, 1);
      expect(gateway.quotedPrices, [20]);
      expect(gateway.coins, 80);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ambiguous submission freezes edits and retries the exact XI', (
    tester,
  ) async {
    final gateway = FakeSquadGateway()..interruptFinish = true;
    final response = await gateway.start(
      catalog.version,
      squadMission.id,
      'run',
    );
    final drafts = SquadDraftStore();
    await drafts.save('alice', 'run', List.generate(11, (i) => i + 1));
    await open(
      tester,
      BuildXiPage(
        catalog: catalog,
        theme: catalog.themes.values.first,
        formation: catalog.formations.values.first,
        run: response.run,
        gateway: gateway,
        ownerId: 'alice',
        drafts: drafts,
      ),
    );
    await tester.tap(find.text('Kadroyu onayla'));
    await tester.pumpAndSettle();
    expect(gateway.coins, 120);
    expect(find.text('Aynı kadroyu yeniden gönder'), findsOneWidget);
    final slot = find.byKey(const Key('squad-slot-0'));
    await reveal(tester, slot);
    expect(tester.widget<InkWell>(slot).onTap, isNull);
    await tester.tap(find.text('Aynı kadroyu yeniden gönder'));
    await tester.pumpAndSettle();
    expect(gateway.submissions.length, 2);
    expect(gateway.submissions.first, gateway.submissions.last);
    expect(gateway.coins, 120);
    expect(find.text('Görev tamamlandı!'), findsOneWidget);
    expect(await drafts.load('alice', 'run'), List<int?>.filled(11, null));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Lost start response recovers the existing run without another free entry',
    (tester) async {
      final gateway = FakeSquadGateway()..interruptStart = true;
      await open(
        tester,
        BuildXiThemeSelectionPage(
          gateway: gateway,
          loadCatalog: () async => catalog,
          progress: SquadChallengeProgressService(),
        ),
      );
      await reveal(tester, find.text('Başla · 1 ücretsiz deneme'));
      await tester.tap(find.text('Başla · 1 ücretsiz deneme'));
      await tester.pumpAndSettle();
      expect(gateway.free, 2);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Göreve devam et · Ücretsiz'));
      await tester.tap(find.text('Göreve devam et · Ücretsiz'));
      await tester.pumpAndSettle();
      expect(find.byType(BuildXiPage), findsOneWidget);
      expect(gateway.free, 2);
      expect(gateway.starts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Premium return refreshes server entitlement and offline errors keep practice accessible',
    (tester) async {
      final gateway = FakeSquadGateway();
      await open(
        tester,
        BuildXiThemeSelectionPage(
          gateway: gateway,
          loadCatalog: () async => catalog,
          onPremium: (_) async => gateway.premium = true,
          progress: SquadChallengeProgressService(),
        ),
      );
      await reveal(tester, find.text('Premium avantajını incele'));
      await tester.tap(find.text('Premium avantajını incele'));
      await tester.pumpAndSettle();
      expect(gateway.loads, 2);
      await reveal(tester, find.text('Göreve başla · Premium'));
      expect(find.text('Göreve başla · Premium'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      gateway.offline = true;
      await open(
        tester,
        BuildXiThemeSelectionPage(
          gateway: gateway,
          loadCatalog: () async => catalog,
          progress: SquadChallengeProgressService(),
        ),
      );
      expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
      await tester.tap(find.text('Antrenman'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Deneme Ligi'));
      await tester.tap(find.text('Deneme Ligi'));
      await tester.pumpAndSettle();
      expect(find.byType(BuildXiFormationSelectionPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
