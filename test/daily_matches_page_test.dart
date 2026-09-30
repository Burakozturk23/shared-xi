import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/football_calendar_page.dart';
import 'package:shared_xi/services/daily_matches_gateway.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

class FakeDailyGateway implements DailyMatchesGateway {
  bool empty = false, failed = false;
  int calls = 0;
  String? lastPlacement;
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
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: OrtakSahaTheme.dark,
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
      expect(find.text('30 Link Coin'), findsOneWidget);
      final bonus = find.text('Reklam izle · 60 coine katla');
      await tester.ensureVisible(bonus);
      await tester.pumpAndSettle();
      await tester.tap(bonus);
      await tester.pumpAndSettle();
      expect(gateway.lastPlacement, 'daily_double');
      expect(find.text('60 Link Coin'), findsOneWidget);
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
}
