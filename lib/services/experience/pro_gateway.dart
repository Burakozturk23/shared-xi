import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../models/premium_models.dart';
import '../../models/premium_billing_models.dart';
import '../auth_service.dart';
import '../premium_service.dart';
import '../premium_billing_service.dart';
import '../profile_service.dart';
import '../monetization_analytics.dart';

class ProGateway {
  const ProGateway();
  bool get connected => AuthService.isGoogleAccount;
  Future<PremiumEntitlement> status() => PremiumService.fetchStatus();
  Future<PremiumBillingCatalog> catalog() =>
      PremiumBillingService.queryCatalog();
  Stream<List<PurchaseDetails>> get purchases =>
      PremiumBillingService.purchaseUpdates;
  Future<bool> buy(PremiumPlan plan) =>
      PremiumBillingService.purchasePlan(plan);
  Future<void> restore() => PremiumBillingService.restorePurchases();
  Future<PremiumEntitlement> verify(PurchaseDetails p) =>
      PremiumBillingService.verifyAndComplete(p);
  Future<void> prepareProfile() => ProfileService.ensureCanonicalProfile();
  void record(String event, {String productId = '', bool restored = false}) {
    final analytics = MonetizationAnalytics.instance;
    final future = switch (event) {
      'view' => analytics.surfaceViewed('linkball_pro'),
      'cancel' => analytics.premiumCancelled(productId),
      'start' => analytics.purchaseStarted(flow: 'pro', productId: productId),
      _ => analytics.purchaseCompleted(
        flow: 'pro',
        productId: productId,
        restored: restored,
      ),
    };
    unawaited(future.catchError((Object _) {}));
  }
}
