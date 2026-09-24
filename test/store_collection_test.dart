import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/economy_models.dart';
import 'package:shared_xi/models/store_models.dart';
import 'package:shared_xi/models/store_collection.dart';
import 'package:shared_xi/models/user_avatar_catalog.dart';
import 'package:shared_xi/screens/store_page.dart';
import 'package:shared_xi/services/store_gateway.dart';
import 'package:shared_xi/widgets/store_boost_panel.dart';
import 'package:shared_xi/widgets/profile_kit.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

List<StoreOffer> offers() =>
    ((jsonDecode(
                  File(
                    'functions/config/store_collection.json',
                  ).readAsStringSync(),
                )
                as Map)['offers']
            as List)
        .map((o) => StoreOffer.fromMap(Map<String, dynamic>.from(o as Map)))
        .toList();
EconomyInventoryItem item(String id, String type, [int count = 1]) =>
    EconomyInventoryItem(
      itemId: id,
      itemType: type,
      sourceType: 'purchase',
      sourceId: 'fixture',
      quantity: count,
    );

class ShopFake extends StoreGateway {
  final items = <String, EconomyInventoryItem>{};
  int coins = 1000, purchases = 0, consumes = 0;
  String selected = '', round = '';
  Completer<EconomyPurchaseResult>? pending;
  Completer<int>? consuming;
  bool failConsume = false;
  @override
  bool get connected => true;
  @override
  Future<void> view() async {}
  @override
  Future<void> started(StoreOffer o) async {}
  @override
  Future<void> completed(StoreOffer o) async {}
  @override
  Future<StoreCatalogSnapshot> load() async => StoreCatalogSnapshot(
    catalogVersion: 2,
    wallet: EconomyWallet(
      coins: coins,
      lifetimeEarned: 1000,
      lifetimeSpent: 1000 - coins,
    ),
    offers: offers(),
    inventory: {...items},
    selectedKitId: selected,
  );
  @override
  Future<EconomyPurchaseResult> purchase(StoreOffer o) async {
    purchases++;
    if (pending != null) return pending!.future;
    coins -= o.priceCoins;
    final owned = item(o.itemId, o.itemType, o.units);
    items[o.itemId] = owned;
    return EconomyPurchaseResult(
      purchased: true,
      alreadyOwned: false,
      priceCoins: o.priceCoins,
      coins: coins,
      item: owned,
    );
  }

  @override
  Future<void> equip(String id) async {
    selected = id;
  }

  @override
  Future<int> consume(String id, String modeId, String roundId) async {
    consumes++;
    round = roundId;
    if (failConsume) throw StateError('offline');
    return consuming?.future ?? Future.value(2);
  }
}

Future<GlobalKey> mount(
  WidgetTester t,
  Widget page, {
  bool dark = true,
  bool large = false,
}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
        child: child!,
      ),
      home: RepaintBoundary(key: key, child: page),
    ),
  );
  await t.pumpAndSettle();
  return key;
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/store_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'server avatar and kit IDs have client visuals and packs cost less than singles',
    () {
      final all = offers();
      for (final o in all) {
        if (o.isAvatar) expect(UserAvatarCatalog.byId(o.itemId), isNotNull);
        if (o.itemType == 'kit') expect(profileKit(o.itemId), isNotNull);
        if (o.units == 3)
          expect(
            o.priceCoins,
            lessThan(
              all
                      .singleWhere((s) => s.itemId == o.itemId && s.units == 1)
                      .priceCoins *
                  3,
            ),
          );
      }
    },
  );
  testWidgets(
    'purchase confirms price, cancels safely and updates balance and stock',
    (t) async {
      final fake = ShopFake();
      await mount(t, StorePage(gateway: fake));
      await reveal(t, find.text('Satın al').first);
      await t.tap(find.text('Satın al').first);
      await t.pumpAndSettle();
      expect(find.text('İşlem sonrası bakiye: 975'), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(fake.purchases, 0);
      await t.tap(find.text('Satın al').first);
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Satın al'),
        ),
      );
      await t.pumpAndSettle();
      expect(fake.purchases, 1);
      expect(fake.coins, 975);
      expect(find.text('1 kullanım · Çantanda 1'), findsOneWidget);
    },
  );
  testWidgets('owned jersey equips without another purchase', (t) async {
    final fake = ShopFake()
      ..items['kit_midnight'] = item('kit_midnight', 'kit');
    await mount(t, StorePage(gateway: fake));
    await t.tap(find.text('Formalar'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Giy'));
    await t.tap(find.text('Giy'));
    await t.pumpAndSettle();
    expect(fake.selected, 'kit_midnight');
    expect(fake.purchases, 0);
    expect(find.text('Kullanılıyor'), findsOneWidget);
  });
  testWidgets('avatar filters and empty owned collection', (t) async {
    await mount(t, StorePage(gateway: ShopFake()));
    await t.tap(find.text('Avatarlar'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Teknik direktörler'));
    await t.tap(find.text('Teknik direktörler'));
    await t.pumpAndSettle();
    await reveal(t, find.text('José Mourinho'));
    expect(find.text('Cristiano Ronaldo'), findsNothing);
    await t.scrollUntilVisible(
      find.text('Çantam'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Çantam'));
    await t.pumpAndSettle();
    expect(find.text('Burada henüz ürün yok'), findsOneWidget);
  });
  testWidgets(
    'hint appears only after acknowledgement; failed call reuses round ID',
    (t) async {
      final fake = ShopFake()
        ..items['boost_first_letter'] = item('boost_first_letter', 'boost', 3)
        ..failConsume = true;
      await mount(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: StoreBoostPanel(
              modeId: 'mystery_player',
              answer: 'Lionel Messi',
              gateway: fake,
            ),
          ),
        ),
      );
      await t.tap(find.text('Destek çantam'));
      await t.pumpAndSettle();
      await t.tap(find.text('İlk harf · 1 adet kullan (3 kalan)'));
      await t.pumpAndSettle();
      expect(find.text('İlk harf: L'), findsNothing);
      final firstRound = fake.round;
      fake.failConsume = false;
      fake.consuming = Completer<int>();
      await t.tap(find.text('İlk harf · 1 adet kullan (3 kalan)'));
      await t.pump();
      expect(find.text('İlk harf: L'), findsNothing);
      fake.consuming!.complete(2);
      await t.pumpAndSettle();
      expect(fake.round, firstRound);
      expect(find.text('İlk harf: L'), findsOneWidget);
      expect(find.text('İlk harf · 1 adet kullan (2 kalan)'), findsNothing);
    },
  );
  for (final dark in [true, false]) {
    for (final tab in ['Güçlendirmeler', 'Avatarlar', 'Formalar']) {
      testWidgets('$tab preview ${dark ? 'dark' : 'light'}', (t) async {
        final key = await mount(t, StorePage(gateway: ShopFake()), dark: dark);
        await t.tap(find.text(tab));
        await t.pumpAndSettle();
        await capture(
          t,
          key,
          '${dark ? 'dark' : 'light'}_${tab == 'Formalar'
              ? 'kits'
              : tab == 'Avatarlar'
              ? 'avatars'
              : 'boosts'}',
        );
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('narrow large text store and original jersey remain readable', (
    t,
  ) async {
    final key = await mount(t, StorePage(gateway: ShopFake()), large: true);
    await reveal(t, find.text('Satın al').first);
    await capture(t, key, 'large_text');
    expect(t.takeException(), isNull);
    await mount(
      t,
      Scaffold(
        body: Center(
          child: ProfileKitView(kit: profileKit('kit_midnight')!, size: 140),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
