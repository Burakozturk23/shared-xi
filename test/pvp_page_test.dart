import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/online/online_mode_route.dart';
import 'package:shared_xi/online/pvp_page.dart';
import 'package:shared_xi/services/pvp_service.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

class PvpFixture extends PvpService {
  PvpFixture({
    this.stage = 'playing',
    this.ranked = false,
    this.lock = 12000,
    this.turn = 'alice',
    this.submitted = false,
    this.pending = false,
  });
  String turn;
  bool submitted, pending;
  final actions = <String>[];
  Map<String, dynamic>? answerReceipt;
  String stage;
  int lock;
  final answers = <String>[];
  Map<String, dynamic> lastExtra = {};
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
    if (mode == 'loto') ...{
      'owners': {
        '0': {
          'uid': 'alice',
          'playerId': '200002',
          'player': {'id': '200002', 'name': 'Cristiano Ronaldo'},
        },
        '5': {
          'uid': 'bob',
          'playerId': '200004',
          'player': {'id': '200004', 'name': 'Kevin De Bruyne'},
        },
      },
      'used': {
        '200002': {'uid': 'alice', 'playerId': '200002'},
        '200004': {'uid': 'bob', 'playerId': '200004'},
      },
      'lotoLines': {'c1': 'bob'},
      'lineBonus': 2,
    },
    'serverNow': 10000,
    'startsAt': 5000,
    'endsAt': 95000,
    'turnDeadline': 50000,
    'turnUid': turn,
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
          'r0': {
            'uid': 'bob',
            'criterionId': 'country:england',
            'criterion': {
              'id': 'country:england',
              'label': 'England',
              'type': 'country',
            },
          },
        },
      if (mode == 'grid_classic')
        'owners': {
          '0': {
            'uid': 'alice',
            'playerId': '7',
            'player': {'id': '7', 'name': 'Sergio Ramos'},
          },
          '4': {
            'uid': 'bob',
            'playerId': '8',
            'player': {'id': '8', 'name': 'Thiago Alcântara'},
          },
        },
      if (mode == 'grid_random') ...{
        'randomBoard': 1,
        'anchors': [2, 4, 6],
        'dead': [5],
        'rows': [criterion(0), null, null],
        'cols': [null, null, criterion(1)],
        'owners': {
          '2': {
            'uid': 'alice',
            'playerId': '9',
            'player': {'id': '9', 'name': 'Seydou Keita'},
          },
        },
        'pending': pending
            ? {
                'criteria': [
                  criterion(2),
                  {
                    'id': 'country:england',
                    'label': 'England',
                    'type': 'country',
                  },
                ],
              }
            : null,
      },
      if (mode == 'grid_reverse' && stage == 'finished')
        'accepted': {
          'r0': ['England'],
          'c1': ['Manchester United', 'England'],
        },
    },
    'maxWrong': 8,
    'lockUntil': lock,
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
      'owners': {
        '3': {
          'uid': 'bob',
          'playerId': '4',
          'player': {'id': '4', 'name': 'Rüştü Reçber'},
        },
      },
      // Cell 24 has no unused answer left.
      'open': [
        for (var i = 0; i < 24; i++)
          if (i != 3) i,
      ],
      'moves': [
        {
          'uid': 'bob',
          'player': {'id': '4', 'name': 'Rüştü Reçber'},
          'correct': [3],
          'wrong': [4],
          'points': 0,
        },
        {'uid': 'alice', 'pass': true, 'timeout': true, 'points': 0},
      ],
    },
    if (stage == 'playing' && mode == 'random_five')
      'found': [
        {
          'id': '1',
          'name': 'Lazar Marković',
          'uid': 'alice',
          'clubs': 3,
          'clubIds': ['club:0', 'club:1', 'club:2'],
          'points': 4,
          'second': 14,
        },
        {
          'id': '2',
          'name': 'Christian Benteke',
          'uid': 'bob',
          'clubs': 1,
          'clubIds': ['club:0'],
          'points': 1,
          'second': 20,
        },
      ],
    if (stage == 'playing' && mode.startsWith('club_')) ...{
      'answerCount': 8,
      'found': [
        {
          'id': '1',
          'name': 'Arda Turan',
          'uid': 'alice',
          'country': 'Turkey',
          'position': 'MID',
          'second': 14,
        },
        {'id': '2', 'name': 'Emre Belözoğlu', 'uid': 'bob', 'second': 32},
      ],
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
    if (mode == 'club_manager') 'rivalLocked': true,
    if (mode == 'club_manager' && stage == 'finished')
      'simulation': {
        'goals': {'alice': 1, 'bob': 1},
        'powers': {'alice': 71.24, 'bob': 69.5},
        'xg': {'alice': 1.42, 'bob': 1.18},
        'penalties': {'alice': 5, 'bob': 4},
      },
    'budget': 120,
    'submitted': submitted,
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
    if (action != 'poll') actions.add(action);
    if (action == 'answer') answers.add('${extra['playerId']}');
    if (action == 'answer' || action == 'squad') lastExtra = extra;
    return {
      'room': snapshot('${room['mode']}'),
      if (action == 'answer' && answerReceipt != null) 'receipt': answerReceipt,
    };
  }

  final searches = <String>[];
  @override
  Future<List<Map<String, dynamic>>> search(
    String mode,
    String query, {
    String? roomId,
  }) async {
    searches.add(query);
    return [player(0), player(1)];
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

/// Fails every image fetch at once, so flags fall back to their emoji.
class OfflineImageCache extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.error(StateError('No network images in tests'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Arena boards show country flags through CachedNetworkImage; keep its
  // disk cache, plugin calls and cleanup timers out of widget tests.
  CachedNetworkImageProvider.defaultCacheManager = OfflineImageCache();
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
    final f = PvpFixture();
    await mount(t, OnlinePlayMode.loto, f);
    expect(find.text('Yanlış 1/8'), findsOneWidget);
    expect(find.text('Yanlış 3/8'), findsOneWidget);
    expect(find.text('2 sn bekle'), findsOneWidget);
    // Locked: a picked player cannot be placed.
    await t.tap(find.byKey(const ValueKey('online-loto-player-200000')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('online-cell-3')));
    await t.pump();
    expect(f.answers, isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('online Loto: pick a player, then a cell places it', (t) async {
    final f = PvpFixture(lock: 0)
      ..answerReceipt = {
        'accepted': true,
        'correct': true,
        'points': 3,
        'lines': ['r0'],
      };
    await mount(t, OnlinePlayMode.loto, f);
    expect(find.text('Önce bir futbolcu seç'), findsOneWidget);
    // Placed players show on their cell with the owner and are no longer pickable.
    expect(find.text('SEN'), findsNWidgets(2)); // score card + cell
    expect(find.text('RAKİP'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('online-loto-player-200002')),
      findsNothing,
    );
    await t.tap(find.byKey(const ValueKey('online-loto-player-200000')));
    await t.pump();
    expect(
      find.text('Lionel Messi · uyduğu boş hücreye dokun'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('online-cell-3')));
    await t.pump();
    expect(f.lastExtra, {'playerId': '200000', 'targetId': '3'});
    expect(find.text('Doğru! +3 puan · Satır 1 tamamlandı'), findsOneWidget);
    // Completed lines and the bingo rule are on the board.
    expect(find.text('Sütun 2 · Rakip +2'), findsOneWidget);
    expect(
      find.textContaining('son boş hücresini dolduran +2'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'online Random Five explains the club bonus and the wrong-name lock',
    (t) async {
      final f = PvpFixture();
      await mount(t, OnlinePlayMode.randomFive, f);
      expect(find.text('CANLI 1v1'), findsOneWidget);
      expect(find.text('Yanlış 1/8'), findsOneWidget);
      // The points table: 1 club +1 … 5 clubs +8.
      expect(find.text('3 kulüp'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
      // Each club card counts the names found for it.
      expect(find.text('2 isim'), findsOneWidget);
      final mine = find.text('Lazar Marković');
      await t.scrollUntilVisible(
        mine,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sen +4'), findsOneWidget);
      expect(find.text('Rakip +1'), findsOneWidget);
      expect(
        find.text(
          '3 kulüp · Manchester United, Borussia Mönchengladbach, Paris Saint-Germain',
        ),
        findsOneWidget,
      );
      // Locked for 2 s after a wrong name: a suggestion is not sent.
      expect(find.text('2 sn bekle'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets('online Random Five sends a suggestion with one tap', (t) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.randomFive, f);
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.text('Kevin De Bruyne'));
    await t.pump();
    expect(f.lastExtra, {'playerId': '200001'});
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'online Grid counts wrong answers, pays rare names and lists accepted criteria',
    (t) async {
      await mount(t, OnlinePlayMode.gridReverse, PvpFixture());
      expect(find.text('Yanlış 1'), findsOneWidget);
      expect(find.text('Yanlış 2'), findsOneWidget);
      expect(find.text('England'), findsOneWidget);
      await mount(t, OnlinePlayMode.gridReverse, PvpFixture(stage: 'finished'));
      final accepted = find.text('Her eksenin kabul edilen kriterleri');
      await t.scrollUntilVisible(
        accepted,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(accepted);
      await t.pumpAndSettle();
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
      final f = PvpFixture();
      await mount(t, OnlinePlayMode.clubManager, f);
      expect(find.text('CANLI 1v1'), findsOneWidget);
      expect(find.text('KADRO KUR'), findsOneWidget);
      // The rival's lock shows, never its XI.
      expect(find.text('Kilitledi'), findsOneWidget);
      expect(find.text('Kaleci 0/1'), findsOneWidget);
      expect(find.text('11 oyuncu seç (0/11)'), findsOneWidget);
      final fill = find.text('Boşları bütçeye göre doldur');
      await t.scrollUntilVisible(
        fill,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(fill);
      await t.pump();
      expect(find.text('Kaleci 1/1'), findsOneWidget);
      expect(find.text('Forvet 3/3'), findsOneWidget);
      expect(find.textContaining('bütçe aşıldı'), findsNothing);
      // Position tabs list that position's players.
      await t.tap(find.text('Defans 4/4'));
      await t.pump();
      expect(find.text('Oyuncu 9'), findsWidgets);
      final cycle = find.textContaining('yüksek pres tempoyu');
      await t.scrollUntilVisible(
        cycle,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(cycle, findsOneWidget);
      await t.tap(find.text('XI ve taktiği kilitle'));
      await t.pump();
      expect(f.actions, ['squad']);
      expect((f.lastExtra['playerIds'] as List).length, 11);
      expect(f.lastExtra['formation'], '433');
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
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.cinko, f);
    expect(find.text('SIRA SENDE'), findsOneWidget);
    expect(find.text('Rüştü Reçber'), findsWidgets);
    expect(find.text('KAPALI'), findsOneWidget);
    expect(find.text('Önce bağlı kutuları seç'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('online-cell-0')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('online-cell-1')));
    await t.pump();
    expect(
      find.text('2 kutu seçili · doğrular +1, yanlışlar −1'),
      findsOneWidget,
    );
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.text('Kevin De Bruyne'));
    await t.pump();
    expect(f.lastExtra, {
      'playerId': '200001',
      'cells': [0, 1],
    });
    // The move list and the rules are below the board.
    final moves = find.text('Rakip · Rüştü Reçber · 1 doğru, 1 yanlış · 0');
    await t.scrollUntilVisible(
      moves,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(moves, findsOneWidget);
    expect(find.text('Sen · süre doldu · pas'), findsOneWidget);
    final rules = find.textContaining('Doğru kutu +1, yanlış kutu −1');
    await t.scrollUntilVisible(
      rules,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('ikinci başlayan maça 1 puanla başlar'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('online Çinko passes on the player turn', (t) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.cinko, f);
    final pass = find.text('Pas geç');
    await t.scrollUntilVisible(
      pass,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(pass);
    await t.pump();
    expect(f.actions, ['pass']);
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
      // Who found whom: one section per side with the found players.
      await t.scrollUntilVisible(
        find.text('SENİN BULDUKLARIN (1)'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Arda Turan'), findsOneWidget);
      expect(find.text('ARKADAŞIN BULDU (1)'), findsOneWidget);
      expect(find.text('Emre Belözoğlu'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets('typing a name shows suggestions without pressing search', (
    t,
  ) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.sharedXi, f);
    final field = find.widgetWithText(TextField, 'Futbolcu ara');
    await t.enterText(field, 'Me');
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(field, 'Mes');
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(field, 'Messi');
    expect(f.searches, isEmpty);
    // The found players are listed live, in order, with who found them.
    expect(find.text('BULUNAN 2 / 8'), findsOneWidget);
    expect(find.text('6 kalan'), findsOneWidget);
    expect(find.text('Arda Turan'), findsOneWidget);
    expect(find.text('Sen +1'), findsOneWidget);
    expect(find.text('Emre Belözoğlu'), findsOneWidget);
    expect(find.text('Rakip +1'), findsOneWidget);
    expect(find.text('0:14'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(f.searches, ['Messi']);
    expect(find.text('Lionel Messi'), findsOneWidget);
    expect(find.text('Kevin De Bruyne'), findsOneWidget);
    // The full name typed without accents picks the player directly.
    await t.enterText(field, 'lionel  MESSİ');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.text('Kevin De Bruyne'), findsNothing);
    expect(find.text('Gönder · Lionel Messi'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('tapping a suggestion sends it at once', (t) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.clubCountry, f);
    expect(find.text('CANLI 1v1'), findsOneWidget);
    expect(find.text('8 ortak oyuncu'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.text('Kevin De Bruyne'));
    await t.pump();
    expect(f.answers, ['200001']);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('a wrong-move lock holds suggestions back and counts down', (
    t,
  ) async {
    final f = PvpFixture();
    await mount(t, OnlinePlayMode.sharedXi, f);
    expect(find.text('2 sn bekle'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.text('Kevin De Bruyne'), warnIfMissed: false);
    await t.pump();
    expect(f.answers, isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Grid Classic: pick a cell, then a suggestion sends it', (
    t,
  ) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.gridClassic, f);
    expect(find.text('SIRA SENDE'), findsOneWidget);
    expect(find.text('Sergio Ramos'), findsOneWidget);
    expect(find.text('Thiago Alcântara'), findsOneWidget);
    expect(find.text('Önce boş bir hücre seç'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('online-cell-1')));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.text('Kevin De Bruyne'));
    await t.pump();
    expect(f.lastExtra, {'playerId': '200001', 'targetId': '1'});
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Grid Classic waits for the rival turn', (t) async {
    final f = PvpFixture(lock: 0, turn: 'bob');
    await mount(t, OnlinePlayMode.gridClassic, f);
    expect(find.text('RAKİPTE'), findsOneWidget);
    expect(find.text('Rakibin sırası'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('online-cell-1')));
    await t.pump();
    expect(find.text('Önce boş bir hücre seç'), findsNothing);
    expect(find.text('Rakibin sırası'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Grid Reverse: pick an axis, then a club sends it', (t) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.gridReverse, f);
    await t.tap(find.byKey(const ValueKey('online-axis-r1')));
    await t.pump();
    await t.enterText(
      find.widgetWithText(TextField, 'Kulüp veya ülke ara'),
      'paris',
    );
    await t.pump();
    await t.tap(find.text('Paris Saint-Germain'));
    await t.pump();
    expect(f.lastExtra, {'targetId': 'r1', 'criterionId': 'club:2'});
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('a turn-based Grid asks sooner while the rival plays', (t) async {
    final f = PvpFixture(lock: 0, turn: 'bob');
    await mount(t, OnlinePlayMode.gridClassic, f);
    final before = f.polls;
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(f.polls, greaterThan(before));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Grid Random board: draw a pair on your turn', (t) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.gridRandom, f);
    expect(find.text('SIRA SENDE'), findsOneWidget);
    expect(find.text('Seydou Keita'), findsOneWidget);
    expect(find.text('OYUNCU YOK'), findsOneWidget);
    expect(find.text('İkili çek ya da açık bir hücre seç'), findsOneWidget);
    await t.tap(find.text('Rastgele ikili çek'));
    await t.pump();
    expect(f.actions, ['draw']);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Grid Random board: put the drawn pair on an anchor', (t) async {
    final f = PvpFixture(lock: 0, pending: true);
    await mount(t, OnlinePlayMode.gridRandom, f);
    expect(find.text('Rastgele ikili çek'), findsNothing);
    expect(find.text('England'), findsWidgets);
    expect(find.text('İkiliyi koyacağın çapayı seç'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('online-cell-4')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('online-swap')));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    await t.tap(find.text('Kevin De Bruyne'));
    await t.pump();
    expect(f.lastExtra, {'playerId': '200001', 'targetId': '4', 'swap': true});
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Grid Random board waits on the rival turn', (t) async {
    final f = PvpFixture(lock: 0, turn: 'bob', pending: true);
    await mount(t, OnlinePlayMode.gridRandom, f);
    expect(find.text('RAKİPTE'), findsOneWidget);
    expect(find.text('Rastgele ikili çek'), findsNothing);
    expect(find.text('Rakibin sırası'), findsOneWidget);
    expect(find.textContaining('Rakip bu ikiliyi oynuyor'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
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
