import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/three_modes_page.dart';
import 'package:shared_xi/services/three_modes_service.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

class FakeModes extends ThreeModesService {
  FakeModes(this.mode, {this.active = false});
  final String mode;
  bool active;
  String? searched;
  Map<String, dynamic>? lastMutation;
  final List<String> positions = [
    'FWD',
    'FWD',
    'FWD',
    'MID',
    'MID',
    'MID',
    'DEF',
    'DEF',
    'DEF',
    'DEF',
    'GK',
  ];
  Map<String, dynamic> get session => {
    'id': 'test-run',
    'mode': mode,
    'entry': 'random',
    'targetId': 'A',
    'title': mode == 'squad_vault'
        ? 'Gizli kulüp'
        : mode == 'coach_xi'
        ? 'Pep Guardiola'
        : 'A harfi',
    'formation': '433',
    'formations': ['433', '442', '352', '4231', '451'],
    'revision': 0,
    'finished': false,
    'score': 0,
    'wrong': 0,
    'hints': [],
    'freeHint': true,
    'adCredits': 0,
    'adRemaining': 2,
    'remaining': 5,
    'stars': 5,
    'coverage': 'Doğrulanamayan bağlar yanlış sayılmaz.',
    'historyNote': 'Farklı dönemlerin kadrosu; aynı sezon değildir.',
    'slots': List.generate(
      11,
      (i) => {
        'slot': i,
        'position': positions[i],
        'player': null,
        'country': mode == 'squad_vault' && i < 3
            ? ['Brazil', 'England', 'France'][i]
            : null,
      },
    ),
  };
  @override
  Future<Map<String, dynamic>> load(String mode) async => {
    'version': 'test',
    'mode': mode,
    'session': active ? session : null,
    'linked': true,
    'dailyUsed': false,
    'leagueSnapshot': 'test',
    'entries': [
      {
        'id': 'A',
        'name': mode == 'coach_xi'
            ? 'Pep Guardiola'
            : mode == 'squad_vault'
            ? 'Kilitli kasa'
            : 'A',
        'formations': ['433', '442'],
        'count': 120,
        'league': 'Premier League',
        'record': null,
        if (mode == 'coach_xi') ...{
          'clubs': ['Manchester City', 'FC Barcelona', 'Bayern Munich'],
          'spells': [
            {
              'id': '281_2016',
              'club': 'Manchester City',
              'period': '2016–2026',
              'count': 80,
            },
          ],
        },
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> mutate(
    String name,
    Map<String, dynamic> input,
  ) async {
    lastMutation = input;
    active = true;
    return {'session': session};
  }

  @override
  Future<Map<String, dynamic>> search(Map<String, dynamic> input) async {
    searched = '${input['query']}';
    return {
      'results': [
        {
          'id': 1,
          'name': mode == 'squad_vault' ? 'Arsenal' : 'Lionel Messi',
          'country': 'Argentina',
          'position': 'FWD',
          'league': 'Premier League',
        },
      ],
    };
  }

  @override
  Future<void> watchHint(
    String mode,
    String sessionId, {
    String? boostId,
  }) async {}
}

/// A finished run whose result earned the Altın medal and rewards.
class FinishedModes extends FakeModes {
  FinishedModes(super.mode) : super(active: true);
  @override
  Map<String, dynamic> get session => {
    ...super.session,
    'finished': true,
    'result': {
      'score': mode == 'squad_vault' ? 4 : 11,
      'newMedals': mode == 'squad_vault' ? [] : ['3'],
      'coins': 10,
      'xp': 20,
    },
  };
}

/// A coach whose started game is one tenure (the hard mode).
class HardCoachModes extends FakeModes {
  HardCoachModes() : super('coach_xi');
  @override
  Map<String, dynamic> get session => {
    ...super.session,
    'spell': {
      'id': '281_2016',
      'club': 'Manchester City',
      'period': '2016–2026',
    },
  };
}

final boundary = GlobalKey();
Future<void> open(
  WidgetTester t,
  FakeModes f, {
  double width = 390,
  double scale = 1,
  bool light = false,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: boundary,
        child: ThreeModesPage(mode: f.mode, service: f),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/three_modes_qa/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final emoji = File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
    if (emoji.existsSync()) {
      await (FontLoader('Noto Color Emoji')
            ..addFont(emoji.readAsBytes().then((b) => ByteData.sublistView(b))))
          .load();
    }
    for (final entry in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2))).load();
    }
  });
  for (final (mode, unit) in [
    ('coach_xi', 'hoca'),
    ('letter11', 'harf'),
    ('squad_vault', 'kasa'),
  ]) {
    testWidgets('$mode landing shows a collection tile and labelled choices', (
      t,
    ) async {
      await open(t, FakeModes(mode));
      expect(find.text('KOLEKSİYON'), findsOneWidget);
      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('$unit tamamlandı'), findsOneWidget);
      final segmented = find.byWidgetPredicate((w) => w is HubSegmented);
      if (mode == 'squad_vault') {
        expect(segmented, findsNothing);
        expect(find.text('FORMASYON'), findsNothing);
      } else {
        expect(segmented, findsOneWidget);
        expect(find.text('ZORLUK'), findsOneWidget);
        expect(find.text('FORMASYON'), findsOneWidget);
        await t.ensureVisible(find.text('Kolay'));
        await t.tap(find.text('Kolay'));
        await t.pumpAndSettle();
        expect(
          t.getSemantics(find.text('Kolay')),
          isSemantics(isSelected: true, isButton: true),
        );
      }
      expect(t.takeException(), isNull);
    });
  }
  for (final (mode, title, subtitle) in [
    ('coach_xi', '11/11 kadro', 'Yeni madalya: Altın'),
    ('letter11', '11/11 kadro', 'Yeni madalya: Altın'),
    ('squad_vault', '4 yıldız', null),
  ]) {
    testWidgets('$mode finished run shows a result card', (t) async {
      await open(t, FinishedModes(mode));
      await t.scrollUntilVisible(
        find.byType(HubResultCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final card = find.byType(HubResultCard);
      expect(
        t.widget<HubResultCard>(card).tone,
        mode == 'squad_vault' ? HubResultTone.good : HubResultTone.gold,
      );
      for (final text in [
        'OYUN TAMAMLANDI',
        title,
        ?subtitle,
        '+10 Link Coin',
        '+20 XP',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      await capture(t, '${mode}_result');
      expect(t.takeException(), isNull);
    });
  }
  for (final mode in ['coach_xi', 'letter11', 'squad_vault']) {
    testWidgets(
      '$mode landing and resumed pitch render in both themes and large type',
      (t) async {
        for (final light in [false, true]) {
          final fake = FakeModes(mode);
          await open(t, fake, light: light);
          await capture(t, '${mode}_${light ? 'light' : 'dark'}_home');
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await open(t, FakeModes(mode, active: true), light: light);
          await capture(t, '${mode}_${light ? 'light' : 'dark'}_pitch');
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        }
        await open(t, FakeModes(mode, active: true), width: 320, scale: 2);
        await t.drag(find.byType(ListView).first, const Offset(0, -700));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('a coach tenure starts the hard game and shows its era', (
    t,
  ) async {
    final fake = HardCoachModes();
    await open(t, fake);
    final collection = find.text('Hoca koleksiyonu');
    await t.scrollUntilVisible(
      collection,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(collection);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Pep Guardiola'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Pep Guardiola').last);
    await t.pumpAndSettle();
    await capture(t, 'coach_tenure_sheet');
    expect(
      find.text('Kulüpler: Manchester City · FC Barcelona · Bayern Munich'),
      findsOneWidget,
    );
    final spell = find.text('Manchester City · 2016–2026');
    await t.ensureVisible(spell);
    await t.tap(spell);
    await t.pumpAndSettle();
    expect(fake.lastMutation!['spell'], '281_2016');
    expect(fake.lastMutation!['difficulty'], 'hard');
    expect(fake.lastMutation!['entry'], 'archive');
    await t.scrollUntilVisible(
      find.text('Zor · Manchester City · 2016–2026'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Zor · Manchester City · 2016–2026'), findsOneWidget);
    await capture(t, 'coach_tenure_game');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'search keeps unrelated known players visible and validates only selected identity',
    (t) async {
      final fake = FakeModes('letter11', active: true);
      await open(t, fake);
      await t.scrollUntilVisible(
        find.byType(TextField),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(find.byType(TextField), 'Messi');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(fake.searched, 'Messi');
      await t.ensureVisible(find.text('Lionel Messi'));
      await t.tap(find.text('Lionel Messi'));
      await t.pumpAndSettle();
      expect(fake.lastMutation!['action'], 'place');
      expect(fake.lastMutation!['playerId'], 1);
      expect(fake.lastMutation!['slot'], 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'daily entry and vault guess use the same persisted server contract',
    (t) async {
      final fake = FakeModes('letter11');
      await open(t, fake);
      final daily = find.text('Günün harfi · Ücretsiz');
      await t.scrollUntilVisible(
        daily,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(daily);
      await t.pumpAndSettle();
      expect(fake.lastMutation!['entry'], 'daily');
      await t.pumpWidget(const SizedBox());
      final vault = FakeModes('squad_vault', active: true);
      await open(t, vault);
      await t.scrollUntilVisible(
        find.byType(TextField),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(find.byType(TextField), 'Arsenal');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await t.ensureVisible(find.widgetWithText(ListTile, 'Arsenal'));
      await t.tap(find.widgetWithText(ListTile, 'Arsenal'));
      await t.pumpAndSettle();
      expect(vault.lastMutation!['action'], 'guess');
      expect(vault.lastMutation!['clubId'], 1);
    },
  );
}
