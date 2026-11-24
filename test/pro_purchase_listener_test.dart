import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_xi/models/premium_models.dart';
import 'package:shared_xi/services/pro_purchase_listener.dart';

PurchaseDetails pro(
  PurchaseStatus status, {
  String productId = 'linkball_pro_monthly',
  String token = 'token-1',
}) => PurchaseDetails(
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: token,
    source: 'google_play',
  ),
  transactionDate: '1',
  status: status,
);

void main() {
  late StreamController<List<PurchaseDetails>> stream;
  late List<String> verified;
  late bool fail;
  String? uid;
  late ProPurchaseListener listener;

  setUp(() {
    stream = StreamController<List<PurchaseDetails>>.broadcast();
    verified = [];
    fail = false;
    uid = 'alice';
    listener = ProPurchaseListener(
      purchases: stream.stream,
      verify: (p) async {
        verified.add(p.verificationData.serverVerificationData);
        if (fail) throw StateError('offline');
        return const PremiumEntitlement.inactive();
      },
      uid: () => uid,
    )..listen();
  });

  tearDown(() => listener.dispose());

  test('a Pro purchase delivered away from the Pro page is verified once', () async {
    await listener.handle([pro(PurchaseStatus.purchased)]);
    // Every resume restores again: the same token is not re-sent this run.
    await listener.handle([pro(PurchaseStatus.restored)]);
    expect(verified, ['token-1']);
  });

  test('coin, pending and signed-out events are left alone', () async {
    await listener.handle([
      pro(PurchaseStatus.purchased, productId: 'linkball_coins_500'),
      pro(PurchaseStatus.pending, token: 'token-2'),
      pro(PurchaseStatus.canceled, token: 'token-3'),
    ]);
    uid = null;
    await listener.handle([pro(PurchaseStatus.purchased, token: 'token-4')]);
    expect(verified, isEmpty);
  });

  test('a failed verification retries on the next delivery', () async {
    fail = true;
    await listener.handle([pro(PurchaseStatus.purchased)]);
    fail = false;
    await listener.handle([pro(PurchaseStatus.restored)]);
    expect(verified, ['token-1', 'token-1']);
  });

  test('the store stream reaches the listener', () async {
    stream.add([pro(PurchaseStatus.restored, productId: 'linkball_pro_yearly', token: 'token-5')]);
    await Future<void>.delayed(Duration.zero);
    expect(verified, ['token-5']);
  });
}
