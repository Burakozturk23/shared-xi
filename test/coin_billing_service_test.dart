import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_xi/screens/coin_packs_page.dart';
import 'package:shared_xi/services/coin_billing_service.dart';

class FakeCoins implements CoinBillingGateway {
  @override
  String? uid = 'alice';
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  bool enabled = true;
  bool failVerification = false;
  int verified = 0, bought = 0, restored = 0;
  String? account;
  @override
  Stream<List<PurchaseDetails>> get purchases => stream.stream;
  @override
  Future<CoinCatalog> catalog() async =>
      CoinCatalog(enabled: enabled, accountId: 'bound-$uid');
  @override
  Future<List<ProductDetails>> products() async => coinProductAmounts.keys
      .map(
        (id) => ProductDetails(
          id: id,
          title: id,
          description: '',
          price: '₺49,99',
          rawPrice: 49.99,
          currencyCode: 'TRY',
        ),
      )
      .toList();
  @override
  Future<bool> buy(ProductDetails product, String accountId) async {
    bought++;
    account = accountId;
    return true;
  }

  @override
  Future<void> restore() async {
    restored++;
  }

  @override
  Future<void> verify(PurchaseDetails purchase) async {
    verified++;
    if (failVerification) throw StateError('offline');
  }
}

PurchaseDetails purchase(
  PurchaseStatus status, {
  String productId = 'linkball_coins_500',
}) => PurchaseDetails(
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'test-token',
    source: 'google_play',
  ),
  transactionDate: '1',
  status: status,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCoins gateway;
  late CoinBillingService service;
  setUp(() {
    gateway = FakeCoins();
    service = CoinBillingService(gateway);
  });
  tearDown(() async {
    service.dispose();
    await gateway.stream.close();
  });
  test(
    'pending, canceled, error and Premium events cannot grant coins',
    () async {
      await service.handle([purchase(PurchaseStatus.pending)]);
      expect(service.purchasing, true);
      await service.handle([
        purchase(PurchaseStatus.canceled),
        purchase(PurchaseStatus.error),
        purchase(
          PurchaseStatus.purchased,
          productId: 'linkball_premium_monthly',
        ),
      ]);
      expect(gateway.verified, 0);
      expect(service.purchasing, false);
    },
  );
  test(
    'purchase and restore callbacks only verify once per session/account',
    () async {
      await service.handle([
        purchase(PurchaseStatus.purchased),
        purchase(PurchaseStatus.restored),
      ]);
      expect(gateway.verified, 1);
      expect(service.message, contains('doğrulandı'));
    },
  );
  test('verification outage can be retried without claiming success', () async {
    gateway.failVerification = true;
    await service.handle([purchase(PurchaseStatus.purchased)]);
    expect(service.message, contains('henüz doğrulanamadı'));
    gateway.failVerification = false;
    await service.handle([purchase(PurchaseStatus.restored)]);
    expect(gateway.verified, 2);
    expect(service.message, contains('doğrulandı'));
  });
  test('disabled sales still recover paid purchases', () async {
    gateway.enabled = false;
    await service.refresh();
    expect(service.enabled, false);
    expect(service.products, isEmpty);
    expect(gateway.restored, 1);
    await service.handle([purchase(PurchaseStatus.restored)]);
    expect(gateway.verified, 1);
  });
  test(
    'purchase uses the catalog account and rejects stale account changes',
    () async {
      await service.refresh();
      final product = service.products.first;
      gateway.uid = 'bob';
      await service.buy(product);
      expect(gateway.bought, 0);
      gateway.uid = 'alice';
      await service.buy(product);
      expect(gateway.bought, 1);
      expect(gateway.account, 'bound-alice');
      await service.buy(product);
      expect(gateway.bought, 1);
    },
  );
  test('anonymous sessions cannot verify or restore purchases', () async {
    gateway.uid = null;
    await service.refresh();
    await service.handle([purchase(PurchaseStatus.purchased)]);
    expect(gateway.verified, 0);
    expect(gateway.restored, 0);
  });
  testWidgets(
    'three packages display Play prices and recovery on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: CoinPacksPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('500 Link Coin'), findsOneWidget);
      expect(find.text('1400 Link Coin'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('3200 Link Coin'), 180);
      expect(find.text('3200 Link Coin'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Satın almaları kontrol et'),
        180,
      );
      await tester.tap(find.text('Satın almaları kontrol et'));
      expect(gateway.restored, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
