import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/models/manager_transfer.dart';
import 'package:shared_xi/screens/club_manager_hub_page.dart';
import 'package:shared_xi/screens/club_manager_match_page.dart';
import 'package:shared_xi/screens/club_manager_prematch_page.dart';
import 'package:shared_xi/screens/club_manager_season_page.dart';
import 'package:shared_xi/screens/club_manager_squad_page.dart';
import 'package:shared_xi/screens/club_manager_transfer_page.dart';
import 'package:shared_xi/services/manager_career_store.dart';
import 'package:shared_xi/services/manager_season_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/pitch_ui.dart';

import 'support/manager_fixture.dart';

Finder get vertical => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

// Emulates an ambiguous save response: the result was persisted but the caller
// received an error. Retrying must show the same score and not credit it twice.
class InterruptedResultStore extends ManagerCareerStore {
  final attempts = <(int, int)>[];
  @override
  Future<ManagerCareerState> applyMatchResult({
    required ManagerDifficulty difficulty,
    required String seasonId,
    required int week,
    required String opponentId,
    required int userGoals,
    required int oppGoals,
  }) async {
    attempts.add((userGoals, oppGoals));
    final saved = await super.applyMatchResult(
      difficulty: difficulty,
      seasonId: seasonId,
      week: week,
      opponentId: opponentId,
      userGoals: userGoals,
      oppGoals: oppGoals,
    );
    if (attempts.length == 1) throw StateError('Kayıt yanıtı kesildi.');
    return saved;
  }
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
  late ManagerCareerStore store;
  final roster = managerRoster();
  final formation = ManagerFormations.all.first;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = ManagerCareerStore(
      seasons: ManagerSeasonService(random: Random(7)),
    );
  });

  for (final (size, scale, dark) in [
    (const Size(390, 844), 1.0, true),
    (const Size(320, 568), 2.0, false),
    (const Size(700, 400), 2.0, true),
  ]) {
    testWidgets('Career to result and back at $size / $scale text', (
      tester,
    ) async {
      var rosterLoads = 0;
      await open(
        tester,
        ClubManagerHubPage(
          store: store,
          loadRoster: () async {
            rosterLoads++;
            return roster;
          },
        ),
        size: size,
        scale: scale,
        dark: dark,
      );
      expect(find.text('38 HAFTA · 20 TAKIM'), findsOneWidget);
      expect(rosterLoads, 0);
      await reveal(tester, find.text('Kolay kariyer başlat'));
      await tester.tap(find.text('Kolay kariyer başlat'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubManagerSeasonPage), findsOneWidget);
      expect(rosterLoads, 0);

      await tester.tap(find.text('Fikstür'));
      await tester.pumpAndSettle();
      await reveal(tester, find.widgetWithText(ChoiceChip, 'Rövanş'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rövanş'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Hafta 38'));
      expect(find.text('Hafta 38').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Puan durumu'));
      await tester.tap(find.text('Puan durumu'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(DataTable));
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 20);
      await tester.ensureVisible(find.text('Kulübüm'));
      await tester.tap(find.text('Kulübüm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kadronu kur'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('4-3-3'));
      await tester.tap(find.text('4-3-3'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubManagerSquadPage), findsOneWidget);
      expect(rosterLoads, 1);
      await reveal(tester, find.text('Uygun 11’i tamamla'));
      await tester.tap(find.text('Uygun 11’i tamamla'));
      await tester.pumpAndSettle();
      expect(
        (await store.load(ManagerDifficulty.easy)).squadPlayerIds,
        isEmpty,
      );
      await tester.tap(find.text('Kaydet ve maç planına geç'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubManagerPrematchPage), findsOneWidget);
      final ready = await store.load(ManagerDifficulty.easy);
      expect(ready.squadPlayerIds.length, 11);
      expect(ready.budgetLink, ManagerDifficulty.easy.budgetLink - 66);

      await tester.tap(find.text('Maça çık'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubManagerMatchPage), findsOneWidget);
      expect(find.text('Sezona dön').hitTestable(), findsOneWidget);
      final played = await store.load(ManagerDifficulty.easy);
      expect(played.matchesPlayed, 1);
      expect(played.season!.clubs.every((c) => c.played == 1), isTrue);
      expect(played.budgetLink, ready.budgetLink + played.wins * 12);
      await tester.tap(find.text('Sezona dön'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubManagerSeasonPage), findsOneWidget);
      expect(find.byType(ClubManagerSquadPage), findsNothing);
      expect(find.byType(ClubManagerPrematchPage), findsNothing);
      expect(find.text('Hafta 2 / 38'), findsOneWidget);
      expect(find.text('Maça hazırlan').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ClubManagerSeasonPage), findsNothing);
      expect(find.byType(ClubManagerHubPage), findsOneWidget);
      expect((await store.load(ManagerDifficulty.easy)).matchesPlayed, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Discarding an unsaved XI keeps the career budget and roster', (
    tester,
  ) async {
    await open(
      tester,
      ClubManagerSeasonPage(
        difficulty: ManagerDifficulty.hard,
        store: store,
        loadRoster: () async => roster,
      ),
    );
    await tester.tap(find.text('Kadronu kur'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('4-3-3'));
    await tester.tap(find.text('4-3-3'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Uygun 11’i tamamla'));
    await tester.tap(find.text('Uygun 11’i tamamla'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Kadro değişiklikleri kaydedilsin mi?'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(ClubManagerSquadPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri bırak'));
    await tester.pumpAndSettle();
    expect(find.byType(ClubManagerSeasonPage), findsOneWidget);
    final saved = await store.load(ManagerDifficulty.hard);
    expect(saved.squadPlayerIds, isEmpty);
    expect(saved.budgetLink, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Transfer appears on bench; owned offer is disabled and survives reopen',
    (tester) async {
      final career = await store.startIfNeeded(ManagerDifficulty.medium);
      await store.prepareMarket(
        difficulty: ManagerDifficulty.medium,
        marketKey: career.currentMarketKey,
        offers: [
          ManagerTransferOffer(
            player: roster.byId[1001]!,
            askLink: 16,
            note: 'Test',
          ),
        ],
      );
      Widget page() => ClubManagerTransferPage(
        difficulty: ManagerDifficulty.medium,
        store: store,
        loadRoster: () async => roster,
      );
      await open(
        tester,
        page(),
        size: const Size(320, 568),
        scale: 2,
        dark: false,
      );
      await reveal(tester, find.text('Transfer et · 16 LINK'));
      await tester.tap(find.text('Transfer et · 16 LINK'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PitchAction>(find.widgetWithText(PitchAction, 'Kadronda'))
            .onPressed,
        isNull,
      );
      final bought = await store.load(ManagerDifficulty.medium);
      expect(bought.budgetLink, 104);
      expect(bought.benchPlayerIds, [1001]);
      // Let the temporary purchase notification leave the narrow viewport.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sat · +12 LINK'));
      expect(find.text('Sat · +12 LINK').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Sat · +12 LINK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect((await store.load(ManagerDifficulty.medium)).benchPlayerIds, [
        1001,
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, page());
      await reveal(tester, find.text('Kadronda'));
      expect(
        tester
            .widget<PitchAction>(find.widgetWithText(PitchAction, 'Kadronda'))
            .onPressed,
        isNull,
      );
      expect((await store.load(ManagerDifficulty.medium)).budgetLink, 104);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Retrying an interrupted result keeps its score and credits it once',
    (tester) async {
      final interrupted = InterruptedResultStore();
      var career = await interrupted.startIfNeeded(ManagerDifficulty.medium);
      final xi = managerXi(roster, formation);
      career = await interrupted.saveSquad(
        difficulty: ManagerDifficulty.medium,
        seasonId: career.season!.id,
        formation: formation,
        assignments: xi,
      );
      final fixture = career.season!.nextFixture!;
      final opponent = career.season!.clubs.firstWhere(
        (c) => c.id == fixture.opponentId,
      );
      await open(
        tester,
        ClubManagerMatchPage(
          xi: xi.values.toList(),
          difficulty: ManagerDifficulty.medium,
          budgetLink: career.budgetLink,
          formationId: formation.id,
          userName: 'Kuzey XI',
          opponent: ManagerSeasonService.instance.toOpponent(opponent),
          seasonId: career.season!.id,
          fixture: fixture,
          store: interrupted,
        ),
      );
      expect(find.text('Sonuç kaydedilemedi'), findsOneWidget);
      final first = await interrupted.load(ManagerDifficulty.medium);
      expect(first.matchesPlayed, 1);
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(find.text('Sezona dön'), findsOneWidget);
      expect(find.text('Kuzey XI'), findsOneWidget);
      expect(interrupted.attempts.length, 2);
      expect(interrupted.attempts.first, interrupted.attempts.last);
      final saved = await interrupted.load(ManagerDifficulty.medium);
      expect(saved.matchesPlayed, 1);
      expect(saved.budgetLink, first.budgetLink);
      expect(tester.takeException(), isNull);
    },
  );
}
