import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/avatar_browser.dart';
import 'package:shared_xi/models/avatar_store_catalog.dart';
import 'package:shared_xi/models/store_models.dart';
import 'package:shared_xi/models/user_avatar_catalog.dart';
import 'package:shared_xi/screens/avatar_collection_page.dart';
import 'package:shared_xi/screens/store_page.dart';
import 'package:shared_xi/services/avatar_service.dart';
import 'package:shared_xi/services/store_service.dart';
import 'store_collection_test.dart' as fixture;

const initial = AvatarOwnershipState(selectedAvatarId: 'starter_ball',
  ownedAvatarIds: {'starter_ball', 'captain_shield', 'keeper_glove', 'playmaker_star'});

Future<void> search(WidgetTester t, String value) async {
  if (find.byTooltip('Filtrelere dön').evaluate().isNotEmpty) {
    await t.tap(find.byTooltip('Filtrelere dön'));
    await t.pumpAndSettle();
  }
  await fixture.reveal(t, find.byKey(const ValueKey('avatar-search')));
  await t.enterText(find.byKey(const ValueKey('avatar-search')), value);
  await t.pumpAndSettle();
  t.testTextInput.hide();
  await t.pumpAndSettle();
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Turkish search composes with category and ownership and supports both roles', () {
    final owned = {'persona_omer'};
    expect(const AvatarBrowserFilter(query: 'OMER', category: 'friends',
      ownership: AvatarOwnershipFilter.owned).apply(UserAvatarCatalog.all, owned).single.id, 'persona_omer');
    expect(const AvatarBrowserFilter(query: 'omer', ownership: AvatarOwnershipFilter.locked)
      .apply(UserAvatarCatalog.all, owned), isEmpty);
    final coaches = const AvatarBrowserFilter(query: 'guardiola', category: 'coaches')
      .apply(UserAvatarCatalog.all, {});
    // Retired player portraits belong to Efsaneler in the source catalog.
    final players = const AvatarBrowserFilter(query: 'guardiola', category: 'legends')
      .apply(UserAvatarCatalog.all, {});
    expect(coaches, hasLength(1));
    expect(players, hasLength(1));
    expect(coaches.single.id, isNot(players.single.id));
    expect(const AvatarBrowserFilter(query: 'SENOL GUNES').apply(UserAvatarCatalog.all, {}), hasLength(2));
    for (final a in UserAvatarCatalog.all) {
      expect(avatarCategories.containsKey(avatarCategory(a)), isTrue, reason: a.id);
    }
  });

  test('old catalog remains complete without inventing a price or purchasable offer', () async {
    final all = fixture.offers();
    final server = all.where((o) => o.itemId == 'persona_cristiano_ronaldo').toList();
    final expanded = avatarStoreOffers(server);
    expect(expanded.map((o) => o.itemId).toSet(),
      UserAvatarCatalog.all.where((a) => !a.isStarter).map((a) => a.id).toSet());
    final preview = expanded.singleWhere((o) => o.itemId == 'persona_ege');
    expect(preview.isPreview, isTrue);
    expect(preview.priceCoins, 0);
    expect(preview.offerId, isEmpty);
    await expectLater(StoreService.purchase(preview), throwsStateError);
    final current = avatarStoreOffers(all).singleWhere((o) => o.itemId == 'persona_ege');
    expect(current.isPreview, isFalse);
    expect(current.priceCoins, greaterThan(0));
    expect(identical(current, all.singleWhere((o) => o.itemId == 'persona_ege')), isTrue);
  });

  testWidgets('old server shows Ege preview; refresh enables only the real offer', (t) async {
    final fake = fixture.ShopFake()..catalogOverride = <StoreOffer>[];
    await fixture.mount(t, StorePage(gateway: fake, initialAvatarId: 'persona_ege'));
    await fixture.reveal(t, find.text('Satışa hazırlanıyor'));
    expect(find.byKey(const ValueKey('store-persona_ege')), findsOneWidget);
    expect(find.text('0 Link Coin'), findsNothing);
    expect(find.text('Satın al'), findsNothing);
    expect(fake.purchases, 0);
    fake.catalogOverride = null;
    await t.tap(find.byTooltip('Yenile'));
    await t.pumpAndSettle();
    await fixture.reveal(t, find.text('Satın al'));
    await t.tap(find.text('Satın al'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(fake.purchases, 0);
  });

  testWidgets('collection filters, selects owned once and refreshes ownership after shop', (t) async {
    var selections = 0;
    String? visited;
    final pending = Completer<void>();
    await fixture.mount(t, AvatarCollectionPage(initialState: initial,
      onSelect: (_) { selections++; return pending.future; },
      onVisitStore: (id) async { visited = id; },
      onReload: () async => AvatarOwnershipState(selectedAvatarId: 'persona_ege',
        ownedAvatarIds: {...initial.ownedAvatarIds, 'persona_ege'})));
    await search(t, 'Kaptan');
    await fixture.reveal(t, find.byKey(const ValueKey('collection-captain_shield')));
    await t.tap(find.byKey(const ValueKey('collection-captain_shield')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('collection-captain_shield')));
    expect(selections, 1);
    pending.complete();
    await t.pumpAndSettle();
    await search(t, 'ege');
    await fixture.reveal(t, find.byKey(const ValueKey('collection-persona_ege')));
    await t.tap(find.byKey(const ValueKey('collection-persona_ege')));
    await t.pumpAndSettle();
    expect(visited, 'persona_ege');
    expect(find.text('✓ Kullanılıyor'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('empty search resets all filters and sort without losing ownership', (t) async {
    await fixture.mount(t, AvatarCollectionPage(initialState: initial,
      onSelect: (_) async {}, onVisitStore: (_) async {}, onReload: () async => initial));
    await search(t, 'zzzzzz');
    await fixture.reveal(t, find.text('Avatar bulunamadı'));
    await fixture.reveal(t, find.widgetWithText(OutlinedButton, 'Filtreleri temizle'));
    await t.tap(find.widgetWithText(OutlinedButton, 'Filtreleri temizle'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filtrelere dön'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sahip olduklarım'));
    await t.pumpAndSettle();
    expect(find.text('4 avatar'), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const ValueKey('avatar-search'))).controller!.text, isEmpty);
  });

  for (final large in [false, true]) {
    for (final dark in [true, false]) {
      testWidgets('avatar browsers render ${large ? 'large' : 'normal'} ${dark ? 'dark' : 'light'}', (t) async {
        final key = await fixture.mount(t, AvatarCollectionPage(initialState: initial,
          onSelect: (_) async {}, onVisitStore: (_) async {}, onReload: () async => initial),
          large: large, dark: dark);
        await search(t, 'omer');
        await fixture.reveal(t, find.byKey(const ValueKey('collection-persona_omer')));
        await fixture.capture(t, key, 'collection_${large}_${dark}');
        expect(t.takeException(), isNull);
        final storeKey = await fixture.mount(t, StorePage(gateway: fixture.ShopFake(), initialAvatarId: 'persona_ege'),
          large: large, dark: dark);
        await fixture.reveal(t, find.byKey(const ValueKey('store-persona_ege')));
        await fixture.capture(t, storeKey, 'avatar_store_${large}_${dark}');
        expect(t.takeException(), isNull);
      });
    }
  }
}
