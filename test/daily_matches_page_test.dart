import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/football_calendar_page.dart';
import 'package:shared_xi/services/daily_matches_gateway.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';

class FakeDailyGateway implements DailyMatchesGateway {
  bool empty = false, failed = false;
  int calls = 0;
  String? lastPlacement;
  Map<String, dynamic>? lastInput;
  final round = <String, dynamic>{
    'key': '2026-09-30_1',
    'day': '2026-09-30',
    'fixtureId': 1,
    'total': 8,
    'lives': 3,
    'foundPlayers': <Map<String, dynamic>>[],
    'found': <int>[],
    'finished': false,
    'reward': 0,
    'hintUsed': false,
    'adHint': false,
    'doubled': false,
  };
  Map<String, dynamic> get match => {
    'fixtureId': 1,
    'homeClubId': 36,
    'awayClubId': 114,
    'homeName': 'Fenerbahçe',
    'awayName': 'Beşiktaş',
    'sharedCount': 8,
    'leagueName': 'Süper Lig',
    'leagueId': 203,
    'isDerby': true,
    'kickoff': '2026-09-30T20:00:00+03:00',
    'session': calls > 0 ? {...round} : null,
  };
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (failed) throw StateError('Bağlantı kurulamadı.');
    lastInput = input;
    if (action == 'status')
      return {
        'dayKey': '2026-09-30',
        'matches': empty ? [] : [match],
        'streak': 4,
        'remaining': 3,
        'bonus': {
          'enabled': true,
          'testingOnly': false,
          'remaining': 2,
          'pro': false,
        },
      };
    calls++;
    if (action == 'play') {
      if (input['action'] == 'answer') {
        final found = round['foundPlayers'] as List<Map<String, dynamic>>;
        found.add({
          'id': found.length + 1,
          'name': 'Oyuncu ${found.length + 1}',
          'country': 'Türkiye',
        });
      } else if (input['action'] == 'hint') {
        round['hintUsed'] = true;
        round['hint'] = 'Türkiye · G ile başlıyor';
      } else if (input['action'] == 'finish') {
        round['finished'] = true;
        round['reward'] = 30;
      }
    }
    return {
      'session': {...round},
    };
  }

  @override
  Future<void> watch(String placement, {String? key}) async {
    lastPlacement = placement;
    if (placement == 'daily_double') round['doubled'] = true;
  }
}

class CalendarGateway extends FakeDailyGateway {
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    final result = await super.call(action, input);
    if (action != 'status') return result;
    return {
      ...result,
      'feed': {
        'state': empty ? 'no-playable' : 'ready',
        'snapshotUsed': true,
        'snapshotUpdatedAt': DateTime.utc(
          2026,
          10,
          20,
          21,
        ).millisecondsSinceEpoch,
        'sources': {
          'turkey': {'state': 'error'},
        },
        'competitions': ['Premier League', 'Şampiyonlar Ligi'],
      },
      'calendar': [
        {
          ...match,
          'status': 'NS',
          'source': 'api-football',
          'playable': !empty,
        },
        {
          'fixtureId': 4000575370,
          'homeName': 'Real Madrid',
          'awayName': 'RB Leipzig',
          'homeClubId': 418,
          'awayClubId': 23826,
          'leagueId': 2,
          'leagueName': 'Şampiyonlar Ligi',
          'kickoff': '2026-09-30T19:00:00Z',
          'status': 'NS',
          'source': 'football-data-snapshot',
          'playable': false,
        },
      ],
    };
  }
}

class EuropeanCalendarGateway extends CalendarGateway {
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    final result = await super.call(action, input);
    if (action != 'status') return result;
    return {
      ...result,
      'matches': [],
      'feed': {
        'state': 'no-playable',
        'sources': {
          'supplemental': {'state': 'ok'},
        },
        'competitions': ['Süper Lig', 'Avrupa Ligi', 'Konferans Ligi'],
      },
      'calendar': [
        for (final (id, league, home) in [
          (3, 'Avrupa Ligi', 'Avrupa Ev'),
          (848, 'Konferans Ligi', 'Konferans Ev'),
        ])
          {
            'fixtureId': id,
            'leagueId': id,
            'leagueName': league,
            'homeName': home,
            'awayName': 'Konuk',
            'kickoff': '2026-10-22T20:00:00+03:00',
            'status': 'NS',
            'source': 'api-football',
            'playable': false,
          },
        {...match, 'status': 'NS', 'playable': false},
      ],
    };
  }
}

final previewKey = GlobalKey();
Future<void> preview(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('.dart_tool/daily_qa');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> open(
  WidgetTester tester,
  FakeDailyGateway gateway, {
  double scale = 1,
  bool light = false,
  double width = 390,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: previewKey,
        child: FootballCalendarPage(gateway: gateway),
      ),
    ),
  );
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
  testWidgets(
    'paid daily match uses canonical revision and hides legacy free hint',
    (tester) async {
      final gateway = FakeDailyGateway();
      gateway.round.addAll({
        'id': '2026-09-30_1',
        'revision': 2,
        'support': {
          'version': 1,
          'products': [
            {'id': 'boost_basic', 'priceCoins': 25, 'ads': true},
          ],
          'adRemaining': 1,
        },
      });
      await open(tester, gateway, width: 320, scale: 1.8);
      await tester.scrollUntilVisible(
        find.text('Mücadeleye başla'),
        200,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mücadeleye başla'));
      await tester.pumpAndSettle();
      final target = find.byType(PaidHintButton).hitTestable();
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ücretsiz ipucunu göster'), findsNothing);
      await tester.widget<PaidHintButton>(target).onUse({
        'boostId': 'boost_basic',
        'paymentSource': 'coins',
        'expectedPriceCoins': 25,
      });
      await tester.pumpAndSettle();
      expect(gateway.lastInput?['revision'], 2);
      expect(gateway.lastInput?['key'], '2026-09-30_1');
      expect(gateway.lastInput?['expectedPriceCoins'], 25);
      expect(gateway.round['hintUsed'], true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real fixture menu renders and three answers allow early cash-out',
    (tester) async {
      final gateway = FakeDailyGateway();
      await open(tester, gateway);
      expect(find.text('Günün Maçları'), findsOneWidget);
      await preview(tester, 'daily-lobby');
      final start = find.text('Mücadeleye başla');
      await tester.scrollUntilVisible(start, 200);
      await tester.pumpAndSettle();
      expect(start.hitTestable(), findsOneWidget);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('Ödülümü al ve bitir'), findsNothing);
      await preview(tester, 'daily-game');
      for (var i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField), 'Oyuncu $i');
        await tester.ensureVisible(find.text('Cevabı kontrol et'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cevabı kontrol et'));
        await tester.pumpAndSettle();
      }
      final finish = find.text('Ödülümü al ve bitir');
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.tap(finish);
      await tester.pumpAndSettle();
      final card = find.byType(HubResultCard);
      expect(tester.widget<HubResultCard>(card).tone, HubResultTone.win);
      expect(
        find.descendant(of: card, matching: find.text('+30 Link Coin')),
        findsOneWidget,
      );
      expect(find.text('Maçı kazandın!'), findsOneWidget);
      expect(find.text('Hedef tamamlandı. Maç bitti.'), findsOneWidget);
      expect(
        find.text('Hedef tamam! Ek ödül için devam edebilirsin.'),
        findsNothing,
      );
      final bonus = find.text('Reklam izle · 60 coine katla');
      await tester.ensureVisible(bonus);
      await tester.pumpAndSettle();
      await tester.tap(bonus);
      await tester.pumpAndSettle();
      expect(gateway.lastPlacement, 'daily_double');
      expect(find.text('+60 Link Coin'), findsOneWidget);
      expect(find.text('2x bonusun kaydedildi.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await tester.pumpAndSettle();
      await preview(tester, 'daily-result');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty real-fixture day never invents a fallback match', (
    tester,
  ) async {
    await open(tester, FakeDailyGateway()..empty = true);
    expect(find.text('Bu seçime uygun maç yok'), findsOneWidget);
    expect(find.text('Mücadeleye başla'), findsNothing);
    await preview(tester, 'daily-empty');
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed request can be retried and large text has no overflow', (
    tester,
  ) async {
    final gateway = FakeDailyGateway()..failed = true;
    await open(tester, gateway, scale: 1.5);
    expect(find.text('Tekrar dene'), findsOneWidget);
    gateway.failed = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mücadeleye başla'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview(tester, 'daily-large-text');
  });
  for (final light in [false, true]) {
    testWidgets(
      'calendar and playable games stay separate, filters recover; theme $light',
      (tester) async {
        await open(
          tester,
          CalendarGateway(),
          light: light,
          width: light ? 320 : 390,
          scale: light ? 1.8 : 1,
        );
        expect(tester.takeException(), isNull);
        await preview(tester, 'daily-v2-lobby-$light');
        await tester.ensureVisible(find.text('Fikstür · 2'));
        await tester.pumpAndSettle();
        expect(find.text('Fikstür · 2').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Fikstür · 2'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Avrupa'));
        await tester.pumpAndSettle();
        expect(find.text('Avrupa').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Avrupa'));
        await tester.pumpAndSettle();
        expect(find.text('Real Madrid'), findsOneWidget);
        expect(find.text('Ortak oyuncuları bul'), findsNothing);
        await tester.ensureVisible(find.text('Real Madrid'));
        await tester.pumpAndSettle();
        await preview(tester, 'daily-v2-calendar-$light');
        await tester.ensureVisible(find.text('Oyna · 1'));
        await tester.pumpAndSettle();
        expect(find.text('Oyna · 1').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Oyna · 1'));
        await tester.pumpAndSettle();
        expect(find.text('Bu seçime uygun maç yok'), findsOneWidget);
        await tester.ensureVisible(find.text('Tümünü göster'));
        await tester.pumpAndSettle();
        expect(find.text('Tümünü göster').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Tümünü göster'));
        await tester.pumpAndSettle();
        expect(find.text('Mücadeleye başla'), findsOneWidget);
        await tester.ensureVisible(find.text('Takvim bilgisi'));
        await tester.pumpAndSettle();
        await preview(tester, 'daily-v2-source-$light');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'no playable games still offers an honest calendar instead of a fake game',
    (tester) async {
      await open(tester, CalendarGateway()..empty = true);
      expect(find.text('Bugün için uygun oyun bulunamadı'), findsOneWidget);
      await tester.ensureVisible(find.text('Fikstürü incele'));
      await tester.pumpAndSettle();
      expect(find.text('Fikstürü incele').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Fikstürü incele'));
      await tester.pumpAndSettle();
      expect(find.text('Real Madrid'), findsOneWidget);
      expect(find.text('Mücadeleye başla'), findsNothing);
      expect(find.text('Ortak oyuncuları bul'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'European cups appear in calendar and Europe filter even without eligible games',
    (tester) async {
      await open(tester, EuropeanCalendarGateway(), width: 320, scale: 1.5);
      await tester.ensureVisible(find.text('Fikstür · 3'));
      await tester.tap(find.text('Fikstür · 3'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Avrupa'));
      await tester.tap(find.text('Avrupa'));
      await tester.pumpAndSettle();
      expect(find.text('Avrupa Ligi'), findsOneWidget);
      expect(find.text('Konferans Ligi'), findsOneWidget);
      expect(find.text('Süper Lig'), findsNothing);
      expect(find.text('Ortak oyuncuları bul'), findsNothing);
      await tester.ensureVisible(find.text('Konferans Ev'));
      await tester.pumpAndSettle();
      await preview(tester, 'daily-europe-cups');
      await tester.ensureVisible(find.text('Takvim bilgisi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('güncellemesi bekleniyor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
