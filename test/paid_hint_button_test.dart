import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Satoshi')..addFont(rootBundle.load('assets/fonts/Satoshi-Variable.ttf'));
    await font.load();
  });
  for (final strong in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('support choice typed product, 320px 180% ${strong ? "strong" : "basic"} $dark', (t) async {
        t.view.physicalSize = const Size(320, 800); t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey(); Map<String, dynamic>? used;
        final sku = strong ? 'boost_strong' : 'boost_basic';
        await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light, fontFamily: 'Satoshi'),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8)), child: child!),
          home: Scaffold(body: PaidHintButton(session: {'id': 'run', 'revision': 1, 'adCredits': 0,
            'support': {'version': 1, 'adLimit': 2, 'adRemaining': 2, 'products': [
              {'id': sku, 'priceCoins': strong ? 60 : 25, 'ads': !strong}]}},
            sku: sku, label: 'Doğrulanmış kariyer bağlantısı', currentUser: () => 'alice',
            loadBalance: () async => {'stock': 2}, onWatch: () async {},
            onUse: (data) async { used = data; })),
        )));
        await t.tap(find.byType(OutlinedButton)); await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Destek çantası'), findsOneWidget);
        if (strong) expect(find.text('Reklam izle · 1 destek hakkı'), findsNothing);
        final coinButton = find.widgetWithText(FilledButton, 'Coin ile al ve kullan · ${strong ? 60 : 25} Coin');
        await t.ensureVisible(coinButton); await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/game_design_qa/boost_${strong ? "strong" : "basic"}_${dark ? "dark" : "light"}.png');
          await file.parent.create(recursive: true); await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        await t.tap(coinButton); await t.pumpAndSettle();
        expect(used, {'boostId': sku, 'paymentSource': 'coins', 'expectedPriceCoins': strong ? 60 : 25});
      });
    }
  }
  testWidgets('account changes while sheet is open cannot use the old quote', (t) async {
    String user = 'alice'; bool used = false;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: PaidHintButton(
      session: {'id': 'run', 'revision': 1, 'support': {'version': 1,
        'products': [{'id': 'boost_basic', 'priceCoins': 25, 'ads': true}]}},
      sku: 'boost_basic', label: 'Ülke', currentUser: () => user,
      loadBalance: () async => {'stock': 1}, onUse: (_) async { used = true; },
    ))));
    await t.tap(find.byType(OutlinedButton)); await t.pumpAndSettle();
    user = 'bob';
    await t.tap(find.text('Çantamdan kullan · 1 adet')); await t.pumpAndSettle();
    expect(used, false);
  });
}
