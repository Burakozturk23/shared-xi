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

  /// Random Five rounds (fiveRules 3): the five's number, and whether it closed.
  bool fiveRounds = false, fiveClosed = false;

  /// Loto: a player the rival placed since the last answer.
  String? rivalTook;

  /// Series: the room's series and the next game's room once it is open.
  Map<String, dynamic>? series;
  String? nextRoom;
  final entered = <String>[];

  /// Club Manager draft (managerRules 3): 'draft' or 'plan' while playing.
  bool draft = false;
  String draftPhase = 'draft';

  /// The 36-player draft pool: 4 GK, 11 DEF, 12 MID, 9 ATT.
  static const draftNames = [
    'Thibaut Courtois',
    'Alisson',
    'Kasper Schmeichel',
    'Gianluigi Donnarumma',
    'David Alaba',
    'Jan Vertonghen',
    'Samuel Umtiti',
    'Benjamin Pavard',
    'Sead Kolasinac',
    'Marcos Llorente',
    'Pervis Estupiñán',
    'Karim Rekik',
    'Martín Cáceres',
    'Cristiano Biraghi',
    'Mario Gaspar',
    'Dani Parejo',
    'Francis Coquelin',
    'Marcel Sabitzer',
    'Alex Oxlade-Chamberlain',
    'Christian Nørgaard',
    'Giovani Lo Celso',
    'Kwadwo Asamoah',
    'Charles Aránguiz',
    'Rémy Cabella',
    'Samir Nasri',
    'Leonardo Bittencourt',
    'Teun Koopmeiners',
    'Alexis Sánchez',
    'Mohamed Salah',
    'Luis Suárez',
    'Edin Dzeko',
    'Stephan El Shaarawy',
    'Danny Welbeck',
    'Wissam Ben Yedder',
    'Fernando Llorente',
    'Robinho',
  ];
  Map<String, dynamic> draftPlayer(int i) => {
    'id': '${400000 + i}',
    'name': draftNames[i],
    'country': 'Spain',
    'position': i < 4
        ? 'GK'
        : i < 15
        ? 'DEF'
        : i < 27
        ? 'MID'
        : 'ATT',
    'rating': 90 - i % 12,
  };
  // Alice: 1 GK, 4 DEF, 3 MID, 3 ATT when the draft is over; 3 picks each before.
  List<String> draftPicks(String side) {
    final full = side == 'alice'
        ? [0, 4, 5, 6, 7, 15, 16, 17, 27, 28, 29]
        : [1, 8, 9, 10, 11, 18, 19, 20, 21, 30, 31];
    final n = draftPhase == 'draft' && stage == 'playing' ? 3 : 11;
    return [for (final i in full.take(n)) '${400000 + i}'];
  }

  int fiveRound = 1;
  final actions = <String>[];
  Map<String, dynamic>? answerReceipt;
  Map<String, dynamic>? lobbyChoices;
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
    'choices': lobbyChoices ?? {'left': 'club:0', 'right': 'club:1'},
    if (lobbyChoices != null) 'ready': <String, dynamic>{},
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
        if (rivalTook != null)
          rivalTook!: {'uid': 'bob', 'playerId': rivalTook},
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
    if (mode == 'random_five' && fiveRounds) ...{
      'fiveRules': 3,
      'round': fiveRound,
      'totalRounds': 5,
      'answerMs': 25000,
      'revealMs': 4000,
      'roundDeadline': 30000,
      'roundClosed': fiveClosed,
      'nextRoundAt': fiveClosed ? 13000 : null,
      'rivalAnswered': true,
      'myAnswer': submitted && !fiveClosed
          ? {
              'id': '1',
              'name': 'Lazar Marković',
              'clubs': 2,
              'clubIds': ['club:0', 'club:1'],
              'points': 2,
              'second': 6,
            }
          : null,
      'rounds': [
        for (var n = 0; n < fiveRound + (fiveClosed ? 1 : 0); n++)
          {
            'round': n,
            'clubs': List.generate(5, criterion),
            'best': [
              {'id': '9', 'name': 'Xherdan Shaqiri', 'clubs': 4, 'points': 6},
            ],
            'answers': {
              'alice': {
                'id': '1',
                'name': 'Lazar Marković',
                'clubs': 2,
                'clubIds': ['club:0', 'club:1'],
                'points': 2,
                'second': 6,
              },
              'bob': {'timeout': true, 'points': 0, 'clubs': 0},
            },
          },
      ],
    },
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
    if (stage == 'playing' && mode == 'random_five' && !fiveRounds)
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
    if (!draft)
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
    if (mode == 'club_manager' && !draft) 'managerRules': 2,
    if (mode == 'club_manager' && draft) ...{
      'managerRules': 3,
      'phase': stage == 'playing' ? draftPhase : 'plan',
      'pool': List.generate(36, draftPlayer),
      'anchors': [
        {'id': 'club:281', 'label': 'Manchester City'},
        {'id': 'club:46', 'label': 'Inter Milan'},
      ],
      'picks': {'alice': draftPicks('alice'), 'bob': draftPicks('bob')},
      'pick': draftPhase == 'draft' ? 6 : 22,
      'totalPicks': 22,
      'turnUid': draftPhase == 'draft' ? turn : null,
      'turnDeadline': draftPhase == 'draft' ? 22000 : null,
      'planDeadline': draftPhase == 'plan' ? 30000 : null,
      'lastPick': {'uid': 'bob', 'playerId': '400008'},
      'legal': turn == 'alice' && draftPhase == 'draft'
          ? [
              for (var i = 0; i < 36; i++)
                if (![0, 1, 2, 3, 4, 5, 8, 15, 18].contains(i)) '${400000 + i}',
            ]
          : [],
      'formations': {
        'alice': draftPhase == 'draft' ? ['433', '442', '352', '451'] : '433',
        'bob': draftPhase == 'draft' ? ['433', '442', '352', '451'] : '442',
      },
      'chemistry': {
        'alice': {
          'score': 46,
          'pairs': [
            ['400000', '400004', 'club', 'Real Madrid'],
            ['400005', '400015', 'country', 'Spain'],
          ],
        },
        'bob': {'score': 31, 'pairs': []},
      },
      'poolLinks': [
        ['400000', '400006', 'club', 'Real Madrid'],
        ['400004', '400028', 'club', 'Liverpool FC'],
      ],
      'myPlan': submitted ? {'plan': 'attack', 'captain': '400027'} : null,
      'rivalPlanned': true,
      if (stage == 'finished')
        'simulation': {
          'rules': 3,
          'goals': {'alice': 2, 'bob': 1},
          'half': {'alice': 1, 'bob': 0},
          'xg': {'alice': 1.9, 'bob': 1.1},
          'shots': {'alice': 12, 'bob': 10},
          'possession': {'alice': 54, 'bob': 46},
          'edge': {'alice': .025, 'bob': -.015},
          'mvp': '400028',
          'teams': {
            'alice': {
              'formation': '433',
              'plan': 'attack',
              'captain': '400027',
              'power': 81.4,
              'rating': 84.2,
              'chem': 6.4,
              'chemistry': 46,
            },
            'bob': {
              'formation': '442',
              'plan': 'possession',
              'captain': '400030',
              'power': 78.9,
              'rating': 82.5,
              'chem': 4.3,
              'chemistry': 31,
            },
          },
          'events': [
            {
              'minute': 12,
              'uid': 'alice',
              'type': 'goal',
              'playerId': '400028',
              'assistId': '400016',
            },
            {
              'minute': 30,
              'uid': 'bob',
              'type': 'save',
              'playerId': '400030',
              'keeperId': '400000',
            },
            {
              'minute': 41,
              'uid': 'bob',
              'type': 'yellow',
              'playerId': '400009',
            },
            {'minute': 58, 'uid': 'bob', 'type': 'goal', 'playerId': '400031'},
            {
              'minute': 77,
              'uid': 'alice',
              'type': 'goal',
              'playerId': '400029',
              'assistId': '400028',
            },
          ],
        },
    },
    if (mode == 'club_manager') 'rivalLocked': true,
    if (mode == 'club_manager' && stage == 'finished' && !draft)
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
    'series':
        series ??
        {
          'game': 2,
          'limit': 3,
          'wins': {'alice': 1},
        },
    if (nextRoom != null) 'nextRoom': nextRoom,
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
    entered.add(action);
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
    if (['answer', 'squad', 'choose', 'pick', 'plan'].contains(action))
      lastExtra = extra;
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
  bool settle = true,
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
  if (!settle) {
    // A running animation (the draft match) would play to its end in pumpAndSettle.
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    return;
  }
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
        PvpFixture(ranked: ranked, stage: 'finished')
          ..series = {'game': 1, 'limit': 1},
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
  testWidgets('online Loto: a pick the rival placed meanwhile is dropped', (
    t,
  ) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.loto, f);
    await t.tap(find.byKey(const ValueKey('online-loto-player-200000')));
    await t.pump();
    expect(
      find.text('Lionel Messi · uyduğu boş hücreye dokun'),
      findsOneWidget,
    );
    f.rivalTook = '200000';
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(find.text('Önce bir futbolcu seç'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('online-loto-player-200000')),
      findsNothing,
    );
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
  testWidgets(
    'Random Five rounds: the five spins in, one guess goes with its round',
    (t) async {
      final f = PvpFixture(lock: 0)..fiveRounds = true;
      await mount(t, OnlinePlayMode.randomFive, f);
      expect(find.text('BEŞLİ 2/5'), findsOneWidget);
      expect(find.text('BEŞLİ 2 / 5'), findsOneWidget);
      // No wrong-move cap in rounds.
      expect(find.textContaining('Yanlış'), findsNothing);
      expect(find.byKey(const ValueKey('five-reel-4')), findsOneWidget);
      // The reels land after the spin.
      await t.pump(const Duration(milliseconds: 1600));
      expect(find.text('Manchester United'), findsWidgets);
      await capture(t, 'five_rounds_open');
      expect(
        find.text('Rakip tahminini yaptı; beşli kapanınca açılır.'),
        findsOneWidget,
      );
      await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Kev');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      await t.tap(find.text('Kevin De Bruyne'));
      await t.pump();
      expect(f.lastExtra, {'playerId': '200001', 'round': 1});
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets('Random Five rounds: a locked guess waits for the rival', (
    t,
  ) async {
    final f = PvpFixture(lock: 0, submitted: true)..fiveRounds = true;
    await mount(t, OnlinePlayMode.randomFive, f);
    await t.pump(const Duration(milliseconds: 1600));
    expect(find.text('BEKLENİYOR'), findsOneWidget);
    await capture(t, 'five_rounds_locked');
    expect(find.text('Tahminin kilitlendi · rakibini bekle'), findsOneWidget);
    expect(find.text('Sen +2'), findsOneWidget);
    expect(
      find.text('2 kulüp · Manchester United, Borussia Mönchengladbach'),
      findsOneWidget,
    );
    // Waiting on the rival: asks every 2 s.
    final before = f.polls;
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(f.polls, greaterThan(before));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'Random Five rounds: a closed five opens both guesses, then the next spins in',
    (t) async {
      final f = PvpFixture(lock: 0)
        ..fiveRounds = true
        ..fiveClosed = true;
      await mount(t, OnlinePlayMode.randomFive, f);
      await t.pump(const Duration(milliseconds: 1600));
      expect(find.text('YENİ BEŞLİ'), findsOneWidget);
      await capture(t, 'five_rounds_closed');
      expect(find.text('Yeni beşli 3 sn'), findsOneWidget);
      expect(find.text('Sen +2'), findsOneWidget);
      expect(
        find.text('Rakip bu beşlide tahmin yapmadı · 0 puan'),
        findsOneWidget,
      );
      expect(
        find.text('En iyi cevaplar: Xherdan Shaqiri (4 kulüp)'),
        findsOneWidget,
      );
      // The earlier five sits in its own list.
      expect(find.text('Önceki beşliler'), findsOneWidget);
      // Next five: the reels spin again (the server moved on).
      f
        ..fiveClosed = false
        ..fiveRound = 2;
      await t.pump(const Duration(seconds: 3));
      await t.pump();
      await t.pump(const Duration(milliseconds: 450));
      await capture(t, 'five_rounds_spin');
      expect(find.text('BEŞLİ 3/5'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets('Random Five rounds: the result lists every five', (t) async {
    final f = PvpFixture(stage: 'finished', lock: 0)
      ..fiveRounds = true
      ..fiveRound = 4
      ..fiveClosed = true;
    await mount(t, OnlinePlayMode.randomFive, f);
    final last = find.text('BEŞLİ 5');
    await t.scrollUntilVisible(
      last,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(last, findsOneWidget);
    await t.pump();
    await capture(t, 'five_rounds_result');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('Club Manager draft: pick on your turn with links and a pitch', (
    t,
  ) async {
    final f = PvpFixture(lock: 0)..draft = true;
    await mount(t, OnlinePlayMode.clubManager, f);
    expect(find.text('SIRA SENDE'), findsOneWidget);
    expect(find.textContaining('Seçim 7/22'), findsOneWidget);
    expect(
      find.textContaining('Çapa kulüpler: Manchester City'),
      findsOneWidget,
    );
    expect(find.text('Uyum 46/100'), findsOneWidget);
    expect(find.byKey(const ValueKey('draft-pitch-me')), findsOneWidget);
    await capture(t, 'manager_draft');
    final filter = find.byKey(const ValueKey('draft-filter-ATT'));
    await t.scrollUntilVisible(
      filter,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(filter);
    await t.pump();
    final pick = find.byKey(const ValueKey('draft-player-400033'));
    await t.scrollUntilVisible(
      pick,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(pick);
    await t.pump();
    expect(find.text('Kadroya al: Wissam Ben Yedder'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('draft-action')));
    await t.pump();
    expect(f.actions.last, 'pick');
    expect(f.lastExtra, {'playerId': '400033'});
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'Club Manager draft: the rival picks, the bar waits and asks every 2 s',
    (t) async {
      final f = PvpFixture(lock: 0, turn: 'bob')..draft = true;
      await mount(t, OnlinePlayMode.clubManager, f);
      expect(find.text('RAKİP SEÇİYOR'), findsOneWidget);
      expect(find.textContaining('Rakip seçiyor ·'), findsOneWidget);
      expect(
        find.textContaining('Son seçim: Rakip · Sead Kolasinac'),
        findsOneWidget,
      );
      final before = f.polls;
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(f.polls, greaterThan(before));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets('Club Manager plan: a game plan and a captain lock together', (
    t,
  ) async {
    final f = PvpFixture(lock: 0)
      ..draft = true
      ..draftPhase = 'plan';
    await mount(t, OnlinePlayMode.clubManager, f);
    expect(find.text('PLAN SEÇ'), findsOneWidget);
    expect(find.text('Önce bir oyun planı seç'), findsOneWidget);
    final counter = find.byKey(const ValueKey('plan-counter'));
    await t.scrollUntilVisible(
      counter,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(counter);
    await t.pump();
    final captain = find.byKey(const ValueKey('captain-400028'));
    await t.scrollUntilVisible(
      captain,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(captain);
    await t.pump();
    await capture(t, 'manager_plan');
    await t.tap(find.byKey(const ValueKey('draft-action')));
    await t.pump();
    expect(f.actions.last, 'plan');
    expect(f.lastExtra, {'plan': 'counter', 'captain': '400028'});
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'Club Manager result: the match plays minute by minute, then the summary',
    (t) async {
      final f = PvpFixture(stage: 'finished', lock: 0)..draft = true;
      await mount(t, OnlinePlayMode.clubManager, f, settle: false);
      // The match plays first, at the top; the result card waits.
      expect(find.byKey(const ValueKey('manager-live-score')), findsOneWidget);
      expect(find.text('Kazandın'), findsNothing);
      await t.pump(const Duration(seconds: 6));
      await t.pump();
      await capture(t, 'manager_live');
      expect(find.text('1 – 0'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('manager-skip')));
      await t.pump();
      expect(find.text('2 – 1'), findsOneWidget);
      expect(find.text('MAÇIN OYUNCUSU'), findsOneWidget);
      expect(find.textContaining('GOL! Salah'), findsOneWidget);
      await t.pump();
      await capture(t, 'manager_result_v3');
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
  testWidgets('a finished countdown asks for the match at once', (t) async {
    // startsAt (5000) is already behind serverNow (10000).
    final f = PvpFixture(stage: 'countdown', lock: 0);
    await mount(t, OnlinePlayMode.sharedXi, f);
    final before = f.polls;
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(f.polls, greaterThan(before));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets('a live race asks every 3 s for the rival finds', (t) async {
    final f = PvpFixture(lock: 0);
    await mount(t, OnlinePlayMode.sharedXi, f);
    final before = f.polls;
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(f.polls, greaterThan(before));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  testWidgets(
    'friend Club lobby: pick at random or let ready pick, see the rival pick',
    (t) async {
      final f = PvpFixture(stage: 'ready', lock: 0)
        ..lobbyChoices = {'right': 'club:1'};
      await mount(t, OnlinePlayMode.sharedXi, f);
      // The rival's pick shows on its seat; mine is still open.
      expect(find.text('Borussia Mönchengladbach'), findsWidgets);
      final ready = find.text('Hazırım · kulübün rastgele seçilir');
      await t.ensureVisible(ready);
      expect(ready, findsOneWidget);
      await t.tap(find.text('Rastgele seç'));
      await t.pump();
      expect(f.actions, ['choose']);
      expect(['club:0', 'club:2'], contains(f.lastExtra['choice']));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
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

  group('three-game series', () {
    testWidgets('the room setup explains what a series is', (t) async {
      final f = PvpFixture(stage: 'waiting');
      await mount(t, OnlinePlayMode.gridClassic, f, setup: true);
      expect(find.textContaining('Tek maç oynanır'), findsOneWidget);
      await t.tap(find.text('Üç maçlık seri'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('İlk 2 galibiyeti alan seriyi kazanır'),
        findsOneWidget,
      );
    });

    testWidgets('a series game shows the series score while it is played', (
      t,
    ) async {
      final f = PvpFixture(stage: 'playing');
      await mount(t, OnlinePlayMode.gridClassic, f);
      expect(
        find.text('Üç maçlık seri · 2. maç · Sen 1 – 0 Arkadaşın'),
        findsOneWidget,
      );
      await capture(t, 'series_playing');
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('after a game the next one opens by itself', (t) async {
      final f = PvpFixture(stage: 'finished')
        ..series = {
          'game': 1,
          'limit': 3,
          'wins': {'alice': 1},
          'results': ['alice'],
          'over': false,
        }
        ..nextRoom = 'EEFF0011';
      await mount(t, OnlinePlayMode.gridClassic, f);
      expect(find.byKey(const ValueKey('online-series')), findsOneWidget);
      expect(find.text('ÜÇ MAÇLIK SERİ'), findsOneWidget);
      expect(find.text('Sıradaki: 2. maç'), findsOneWidget);
      expect(
        find.text('Bir galibiyet daha alırsan seriyi kazanırsın.'),
        findsOneWidget,
      );
      expect(find.text('Rövanş iste'), findsNothing);
      expect(find.textContaining('2. maça geç'), findsOneWidget);
      await capture(t, 'series_next');
      expect(f.entered, ['join']);
      await t.pump(const Duration(seconds: 12));
      await t.pump();
      expect(f.entered, ['join', 'resume']);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a decided series names its winner and offers a new one', (
      t,
    ) async {
      final f = PvpFixture(stage: 'finished')
        ..series = {
          'game': 3,
          'limit': 3,
          'wins': {'alice': 2, 'bob': 1},
          'results': ['alice', 'bob', 'alice'],
          'over': true,
          'winner': 'alice',
        };
      await mount(t, OnlinePlayMode.gridClassic, f);
      expect(find.text('Seriyi kazandın'), findsOneWidget);
      await capture(t, 'series_over');
      expect(find.text('Üç maçlık seri tamamlandı.'), findsOneWidget);
      expect(find.text('Rakibinin onayı bekleniyor'), findsOneWidget);
      expect(find.textContaining('maça geç'), findsNothing);
      await t.pump(const Duration(seconds: 12));
      expect(f.entered, ['join']);
      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
