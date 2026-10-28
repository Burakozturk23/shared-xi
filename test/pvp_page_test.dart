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
    'pool': List.generate(25, player),
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
