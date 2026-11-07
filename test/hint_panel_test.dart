import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/hint_menu.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/hint_panel.dart';

Map<String, dynamic> session({
  int remaining = 1,
  bool ads = true,
  Map<String, int> credits = const {},
  bool usedA = false,
}) => {
  'id': 'run',
  'revision': 1,
  'hintMenu': {
    'version': 2,
    'board': 'b1',
    'items': [
      {'id': 'milliyet', 'label': 'Milliyet', 'type': 'milliyet', 'strong': false, 'price': 25,
        'used': usedA, 'result': usedA ? 'Fransa' : null, 'why': 'Aday listesini en çok bu daraltır.'},
      {'id': 'baska_kulup', 'label': 'Başka bir kulübü', 'type': 'kulup', 'strong': false, 'price': 25,
        'used': false, 'result': null, 'why': 'Ekranda olmayan bir kulübü.'},
      {'id': 'ilk_harf', 'label': 'İlk harf', 'type': 'isim', 'strong': true, 'price': 50,
        'used': false, 'result': null, 'why': 'Neredeyse çözdürür.'},
    ],
    'suggested': [usedA ? 'baska_kulup' : 'milliyet', 'ilk_harf'],
    'ads': {'allowed': ads, 'remaining': remaining, 'credits': credits},
    'assisted': usedA,
  },
};

void main() {
  test('HintMenu reads v2 only and filters by target', () {
    expect(HintMenu.fromSession({'support': {'version': 1}}), isNull);
    final m = HintMenu.fromSession(session())!;
    expect(m.items.map((i) => i.id), ['milliyet', 'baska_kulup', 'ilk_harf']);
    expect(m.suggested, ('milliyet', 'ilk_harf'));
    expect(m.adsRemaining, 1);
    final withTargets = HintMenu.fromSession({
      'hintMenu': {...session()['hintMenu'] as Map, 'byTarget': {'4': ['milliyet']}},
    })!;
    expect(withTargets.forTarget(4).map((i) => i.id), ['milliyet']);
    expect(withTargets.forTarget(null).length, 3);
  });

  Future<List<(String, String)>> open(
    WidgetTester t,
    Map<String, dynamic> s, {
    Map<String, int> bag = const {},
  }) async {
    final used = <(String, String)>[];
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      theme: OrtakSahaTheme.dark,
      home: Scaffold(
        body: HintButton(
          menu: HintMenu.fromSession(s)!,
          loadBag: () async => bag,
          onUse: (id, source) async => used.add((id, source)),
          onWatch: (id) async => used.add((id, 'watch')),
        ),
      ),
    ));
    await t.tap(find.byKey(const ValueKey('hint-button')));
    await t.pumpAndSettle();
    return used;
  }

  testWidgets('shows two suggestion cards with why line, then all items as chips with stock or price', (t) async {
    await open(t, session(), bag: {'hint_milliyet': 2});
    expect(find.byKey(const ValueKey('hint-suggest-milliyet')), findsOneWidget);
    expect(find.byKey(const ValueKey('hint-suggest-ilk_harf')), findsOneWidget);
    expect(find.text('Aday listesini en çok bu daraltır.'), findsOneWidget);
    expect(find.byKey(const ValueKey('hint-chip-baska_kulup')), findsOneWidget);
    expect(find.textContaining('×2'), findsWidgets);
    expect(find.textContaining('50 Coin'), findsWidgets);
  });

  testWidgets('used item is dimmed and shows its result', (t) async {
    await open(t, session(usedA: true));
    expect(find.textContaining('Fransa'), findsOneWidget);
    final chip = t.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('hint-chip-milliyet')),
        matching: find.byType(Opacity)).first);
    expect(chip.opacity, lessThan(1));
  });

  testWidgets('stock: one tap uses it without a dialog and the panel closes', (t) async {
    final used = await open(t, session(), bag: {'hint_milliyet': 1});
    await t.tap(find.byKey(const ValueKey('hint-suggest-milliyet')));
    await t.pumpAndSettle();
    expect(used, [('milliyet', 'stock')]);
    expect(find.byKey(const ValueKey('hint-panel')), findsNothing);
  });

  testWidgets('empty bag shows Reklam izle · +1 and a small Coin ile al link', (t) async {
    final used = await open(t, session());
    await t.tap(find.byKey(const ValueKey('hint-chip-baska_kulup')));
    await t.pumpAndSettle();
    expect(find.text('Reklam izle · +1'), findsOneWidget);
    expect(find.byKey(const ValueKey('hint-pay-coins-link')), findsOneWidget);
    await t.tap(find.text('Reklam izle · +1'));
    await t.pumpAndSettle();
    expect(used, [('baska_kulup', 'watch')]);
  });

  testWidgets('ads exhausted shows Coin ile al as the main action', (t) async {
    final used = await open(t, session(remaining: 0));
    await t.tap(find.byKey(const ValueKey('hint-chip-baska_kulup')));
    await t.pumpAndSettle();
    expect(find.text('Reklam izle · +1'), findsNothing);
    expect(find.byKey(const ValueKey('hint-pay-coins')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('hint-pay-coins')));
    await t.pumpAndSettle();
    expect(used, [('baska_kulup', 'coins')]);
  });

  testWidgets('strong item with empty bag says 2 reklam', (t) async {
    await open(t, session(remaining: 2));
    await t.tap(find.byKey(const ValueKey('hint-suggest-ilk_harf')));
    await t.pumpAndSettle();
    expect(find.text('Reklam izle · +1 (2 reklam gerekir)'), findsOneWidget);
  });

  testWidgets('verified ad credits pay with the ad source', (t) async {
    final used = await open(t, session(credits: {'ilk_harf': 2}));
    await t.tap(find.byKey(const ValueKey('hint-suggest-ilk_harf')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('hint-pay-ad')));
    await t.pumpAndSettle();
    expect(used, [('ilk_harf', 'ad')]);
  });

  testWidgets('no Joker in the bag: no Joker anywhere', (t) async {
    await open(t, session());
    expect(find.textContaining('Joker'), findsNothing);
  });

  testWidgets('Joker ×N appears when the bag has one and needs a tap', (t) async {
    final used = await open(t, session(), bag: {'hint_joker': 3});
    expect(find.textContaining('Joker ×3'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('hint-chip-baska_kulup')));
    await t.pumpAndSettle();
    expect(used, isEmpty);
    await t.tap(find.byKey(const ValueKey('hint-pay-joker')));
    await t.pumpAndSettle();
    expect(used, [('baska_kulup', 'joker')]);
  });
}
