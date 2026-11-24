import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';
import 'premium_billing_service.dart';

/// App-wide verification of Linkball Pro purchases.
///
/// The Pro page handles a purchase only while it is open. A payment that
/// completes after the player left the page (a slow or pending payment, or the
/// app being closed) would otherwise never reach the server: Google Play
/// refunds a subscription that is not acknowledged within three days. This
/// listener verifies every Pro purchase or restore the store delivers.
/// Redelivery comes from the store restores CoinBillingService already runs on
/// sign-in and on every resume (one Play restore lists every product).
class ProPurchaseListener {
  ProPurchaseListener({
    required this._purchases,
    required this._verify,
    required this._uid,
  });

  static ProPurchaseListener? _instance;

  final Stream<List<PurchaseDetails>> _purchases;
  final Future<PremiumEntitlement> Function(PurchaseDetails) _verify;
  final String? Function() _uid;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Set<String> _done = {};

  /// Starts the Android listener once; call before the first store restore.
  static void initialize() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _instance ??= ProPurchaseListener(
      purchases: PremiumBillingService.purchaseUpdates,
      verify: (purchase) async {
        await CloudBootstrap.ensureInitialized();
        return PremiumBillingService.verifyAndComplete(purchase);
      },
      uid: () => AuthService.isGoogleAccount ? AuthService.uid : null,
    )..listen();
  }

  void listen() {
    _subscription ??= _purchases.listen(
      (events) => unawaited(handle(events)),
      onError: (Object _) {},
    );
  }

  Future<void> handle(List<PurchaseDetails> events) async {
    for (final purchase in events) {
      if (!PremiumBillingProductIds.all.contains(purchase.productID)) continue;
      if (!PremiumBillingService.requiresServerVerification(purchase)) continue;
      final uid = _uid();
      if (uid == null) continue;
      // Once per token and account each app run: restores repeat on every resume.
      final key = '$uid:${purchase.verificationData.serverVerificationData}';
      if (!_done.add(key)) continue;
      try {
        await _verify(purchase);
      } catch (_) {
        // Not verified yet (offline, store still pending): the next restore retries.
        _done.remove(key);
      }
    }
  }

  void dispose() => _subscription?.cancel();
}
