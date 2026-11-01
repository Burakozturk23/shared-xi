import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/online/online_mode_route.dart';
import 'package:shared_xi/online/pvp_page.dart';
import 'package:shared_xi/services/pvp_service.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

class PvpFixture extends PvpService {
  PvpFixture({this.stage = 'playing', this.ranked = false});
  String stage;
  bool ranked;
  int polls = 0;
  String? enteredMode, enteredKind;
  Map<String, dynamic> player(int i) => {
    'id': '${200000 + i}',
    'name': ['Lionel Messi', 'Kevin De Bruyne', 'Cristiano Ronaldo'][i % 3],
    'country': 'Argentina',
    'position': 'MID',
    'rating': 84,
    'cost': 10,
  };
  Map<String, dynamic> criterion(int i) => {
    'id': 'club:$i',
    'label': [
      'Manchester United',
      'Borussia Mönchengladbach',
      'Paris Saint-Germain',
    ][i % 3],
  };
  Map<String, dynamic> snapshot(String mode) => {
    'id': 'AABBCCDD',
    'mode': mode,
    'playKind': ranked ? 'ranked' : 'friend',
    'myUid': 'alice',
    'revision': 2,
    'host': 'alice',
    'guest': 'bob',
    'names': {'alice': 'Sen', 'bob': 'Arkadaşın'},
    'status': stage,
    'ready': {'alice': true},
    'choices': {'left': 'club:0', 'right': 'club:1'},
    'scores': {'alice': 2, 'bob': 1},
    'owners': {},
    'used': {},
    'serverNow': 10000,
    'startsAt': 5000,
    'endsAt': 95000,
    'turnDeadline': 50000,
    'turnUid': 'alice',
    'round': 0,
    'roundDeadline': 35000,
    'rows': List.generate(3, criterion),
    'cols': List.generate(3, criterion),
    'criteria': List.generate(
      mode == 'cinko'
          ? 25
          : mode == 'loto'
          ? 16
          : mode == 'random_five'
          ? 5
          : 2,
      criterion,
    ),
    'players': List.generate(mode == 'loto' ? 16 : 9, player),
    'wrongMoves': {'alice': 1, 'bob': 3},
    if (mode == 'random_five') 'fivePoints': [0, 1, 2, 4, 6, 8],
    if (mode.startsWith('grid_')) ...{
      'gridRules': 2,
      'gridWrong': {'alice': 1, 'bob': 2},
      if (mode == 'grid_random') 'rareBonus': 1,
      if (mode == 'grid_reverse')
        'owners': {
          'r0': {'uid': 'bob', 'criterionId': 'country:england'},
        },
      if (mode == 'grid_reverse' && stage == 'finished')
        'accepted': {
          'r0': ['England'],
          'c1': ['Manchester United', 'England'],
        },
    },
    'maxWrong': 8,
    'lockUntil': 12000,
    'pairOptions': ['club:0', 'club:2'],
    if (mode == 'cinko') ...{
      'cinkoRules': 2,
      'secondBonus': 1,
      'lastMove': {
        'uid': 'bob',
        'player': {'id': '4', 'name': 'Rüştü Reçber'},
        'correct': [3],
        'wrong': [4],
        'points': 0,
      },
    },
    if (stage == 'finished') ...{
      'found': [
        {'id': '1', 'name': 'Arda Turan', 'uid': 'alice'},
        {'id': '2', 'name': 'Emre Belözoğlu', 'uid': 'bob'},
      ],
      'missed': [
        {'id': '3', 'name': 'Hakan Şükür'},
      ],
    },
    // Club Manager pool: 3 GK, 7 DEF, 8 MID, 7 ATT; the first of each is a star.
    'pool': List.generate(25, (i) {
      final pos = i < 3
          ? 'GK'
          : i < 10
          ? 'DEF'
          : i < 18
          ? 'MID'
          : 'ATT';
      final star = [0, 3, 4, 10, 11, 18, 19].contains(i);
      return {
        ...player(i),
        'id': '${300000 + i}',
        'name': 'Oyuncu $i',
        'position': pos,
        'rating': star ? 85 - i % 3 : 60 + i % 10,
        'cost': star
            ? 14
            : i % 2 == 0
            ? 10
            : 6,
      };
    }),
    if (mode == 'club_manager') 'managerRules': 2,
    if (mode == 'club_manager' && stage == 'finished')
      'simulation': {
        'goals': {'alice': 1, 'bob': 1},
        'powers': {'alice': 71.24, 'bob': 69.5},
        'xg': {'alice': 1.42, 'bob': 1.18},
        'penalties': {'alice': 5, 'bob': 4},
      },
    'budget': 120,
    'submitted': false,
    'ruleVersion': 'PVP_RULES_V1',
    'dataRevision': 'pvp-test',
    'result': 'win',
    'reason': 'Süre tamamlandı.',
    'reward': {
      'status': 'verified',
      'coins': ranked ? 3 : 0,
      'xp': ranked ? 6 : 0,
      'eloDelta': ranked ? 16 : 0,
    },
    'series': {
      'game': 2,
      'limit': 3,
      'wins': {'alice': 1},
    },
    'rematch': {'alice': true},
  };
  @override
  Future<Map<String, dynamic>> load(String mode) async => {
    'dataRevision': 'pvp-test',
    'linked': true,
    'availability': {'friendEnabled': true, 'rankedEnabled': true},
    'clubs': List.generate(3, criterion),
    'countries': [
      {'id': 'country:england', 'label': 'England'},
    ],
  };
  @override
  Future<Map<String, dynamic>> enter(
    String mode,
    String kind,
    String action, {
    String? code,
    String profile = 'standard',
  }) async {
    enteredMode = mode;
    enteredKind = kind;
    return {'room': snapshot(mode)};
  }

  @override
  Future<Map<String, dynamic>> act(
    Map<String, dynamic> room,
    String action, [
    Map<String, dynamic> extra = const {},
  ]) async {
    if (action == 'poll') polls++;
    return {'room': snapshot('${room['mode']}')};
  }
}

final boundary = GlobalKey();
Future<void> mount(
  WidgetTester t,
  OnlinePlayMode mode,
  PvpFixture f, {
  bool light = false,
  bool large = false,
  bool setup = false,
}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: boundary,
        child: PvpPage(
          key: UniqueKey(),
          mode: mode,
          playKind: f.ranked ? 'ranked' : 'friend',
          joinCode: setup ? null : 'AABBCCDD',
          service: f,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final img =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/pvp_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in [
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(e.$1)..addFont(rootBundle.load(e.$2))).load();
    }
  });
  final modes = OnlinePlayMode.values.take(9);
  test('all nine menu and invite routes retain mode, kind and code', () {
    for (final mode in modes)
      for (final kind in ['friend', 'ranked']) {
        final page =
            onlineModePage(
                  mode,
                  playKind: kind,
                  joinCode: kind == 'friend' ? 'AABBCCDD' : null,
                )
                as PvpPage;
        expect(page.mode, mode);
        expect(page.playKind, kind);
        expect(page.joinCode, kind == 'friend' ? 'AABBCCDD' : null);
      }
    expect(
      () => onlineModePage(OnlinePlayMode.sharedXi, playKind: 'invalid'),
      throwsArgumentError,
    );
  });
  for (final mode in modes) {
    for (final large in [false, true])
      testWidgets(
        '${mode.wireName} board and result ${large ? '320px large text' : '390px'}',
        (t) async {
          final fixture = PvpFixture();
          await mount(t, mode, fixture, large: large);
          expect(fixture.enteredMode, mode.wireName);
          expect(fixture.enteredKind, 'friend');
          expect(t.takeException(), isNull);
          await capture(t, '${mode.wireName}_${large ? 'large' : 'normal'}');
          // Exercise the offscreen controls as well as the initial viewport.
          await t.drag(find.byType(ListView).first, const Offset(0, -850));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          fixture.stage = 'finished';
          await t.pump(const Duration(seconds: 6));
          await t.pumpAndSettle();
          await t.drag(find.byType(ListView).first, const Offset(0, 1200));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await capture(
            t,
            '${mode.wireName}_result_${large ? 'large' : 'normal'}',
          );
          final old = fixture.polls;
          await t.pump(const Duration(seconds: 6));
          await t.pumpAndSettle();
          expect(
            fixture.polls,
            greaterThan(old),
            reason:
                'A finished friend match must still observe rematch consent.',
          );
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump();
        },
      );
  }
  for (final ranked in [true, false]) {
    testWidgets('finished ${ranked ? 'ranked' : 'friend'} match shows a '
        'result card', (t) async {
      await mount(
        t,
        OnlinePlayMode.sharedXi,
        PvpFixture(ranked: ranked, stage: 'finished'),
      );
      final card = find.byType(HubResultCard);
      expect(t.widget<HubResultCard>(card).tone, HubResultTone.win);
      for (final text in [
        ranked ? 'DERECELİ MAÇ' : 'DOSTLUK MAÇI',
        'Kazandın',
        'Sen 2 – 1 Arkadaşın',
        if (ranked) ...['+3 Link Coin', '+6 XP', 'Elo +16'],
        if (!ranked) 'Dostluk maçı · Elo ve ödül yok',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
  }
  testWidgets('online Loto shows both wrong-move counts and the lock', (
    t,
  ) async {
    await mount(t, OnlinePlayMode.loto, PvpFixture());
    final counter = find.textContaining('Yanlış hamle: 1 / 8 · rakip 3.');
    await t.scrollUntilVisible(
      counter,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(counter, findsOneWidget);
    expect(find.text('Yanlış hamle: 2 sn bekle.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'online Random Five explains the club bonus and the wrong-name lock',
    (t) async {
      await mount(t, OnlinePlayMode.randomFive, PvpFixture());
      final points = find.textContaining(
        '3 kulüp 4, 4 kulüp 6, 5 kulüp 8 puan',
      );
      await t.scrollUntilVisible(
        points,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Yanlış hamle: 1 / 8'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets(
    'online Grid counts wrong answers, pays rare names and lists accepted criteria',
    (t) async {
      await mount(t, OnlinePlayMode.gridReverse, PvpFixture());
      expect(
        find.text(
          'Yanlış cevap: 1 · rakip 2. Skor eşitse az yanlış yapan kazanır.',
        ),
        findsOneWidget,
      );
      final axis = find.text('Satır 1: England · Arkadaşın');
      await t.scrollUntilVisible(
        axis,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(axis, findsOneWidget);
      await mount(t, OnlinePlayMode.gridRandom, PvpFixture());
      expect(find.textContaining('+1 puan daha getirir'), findsOneWidget);
      await mount(t, OnlinePlayMode.gridReverse, PvpFixture(stage: 'finished'));
      final accepted = find.text('Her eksenin kabul edilen kriterleri');
      await t.scrollUntilVisible(
        accepted,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(accepted);
      await t.pumpAndSettle();
      expect(find.text('Manchester United · England'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets(
    'online Club Manager fills the XI within budget and explains the tactic cycle',
    (t) async {
      await mount(t, OnlinePlayMode.clubManager, PvpFixture());
      expect(find.text('Kaleci 0/1'), findsOneWidget);
      expect(find.textContaining('yüksek pres tempoyu'), findsOneWidget);
      final fill = find.text('Boşları bütçeye göre doldur');
      await t.scrollUntilVisible(
        fill,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(fill);
      await t.pumpAndSettle();
      final count = find.textContaining('11 / 11 oyuncu');
      await t.scrollUntilVisible(
        count,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(count, findsOneWidget);
      expect(find.textContaining('bütçe aşıldı'), findsNothing);
      expect(find.text('Kaleci 1/1'), findsOneWidget);
      expect(find.text('Forvet 3/3'), findsOneWidget);
      await mount(t, OnlinePlayMode.clubManager, PvpFixture(stage: 'finished'));
      final pens = find.text('Penaltılar: 5 – 4');
      await t.scrollUntilVisible(
        pens,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sen · güç 71.2 · xG 1.42'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets('online Çinko picks cells by hand and explains the rules', (
    t,
  ) async {
    await mount(t, OnlinePlayMode.cinko, PvpFixture());
    expect(
      find.textContaining('Doğru kutu +1, yanlış kutu −1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ikinci başlayan maça 1 puanla başlar'),
      findsOneWidget,
    );
    expect(
      find.text('Arkadaşın: Rüştü Reçber · 1 doğru, 1 yanlış · 0'),
      findsOneWidget,
    );
    await t.tap(find.bySemanticsLabel(RegExp(r'^1\. hücre')));
    await t.pump();
    expect(find.text('Seçilen kutu: 1'), findsOneWidget);
    expect(find.text('Pas · 0 puan'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'friend pair choice lists only playable options; result shows who found whom and the missed players',
    (t) async {
      await mount(t, OnlinePlayMode.sharedXi, PvpFixture(stage: 'ready'));
      expect(
        find.textContaining(
          'en az 6 ortak futbolcusu olan seçenekler listelenir (2)',
        ),
        findsOneWidget,
      );
      await mount(t, OnlinePlayMode.sharedXi, PvpFixture(stage: 'finished'));
      final missed = find.text('Kimsenin bulamadığı: Hakan Şükür');
      await t.scrollUntilVisible(
        missed,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Senin bulduğun: Arda Turan'), findsOneWidget);
      expect(find.text('Arkadaşın buldu: Emre Belözoğlu'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets(
    'Club Country host and guest choices remain distinct and ranked setup never creates friend room',
    (t) async {
      await mount(t, OnlinePlayMode.clubCountry, PvpFixture(stage: 'ready'));
      expect(find.text('Kulübünü seç'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, 'club_country_lobby');
      await mount(
        t,
        OnlinePlayMode.clubManager,
        PvpFixture(ranked: true),
        large: true,
        setup: true,
      );
      expect(find.text('Rakip ara'), findsOneWidget);
      expect(find.text('Oda oluştur'), findsNothing);
      expect(t.takeException(), isNull);
      await capture(t, 'manager_ranked_setup_large');
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
}
