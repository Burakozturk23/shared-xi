import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../models/premium_models.dart';
import '../../models/pro_crate.dart';
import '../cloud_bootstrap.dart';
import '../store_service.dart';
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

  Future<ProCrateStatus> _crate(String name) async {
    await CloudBootstrap.ensureInitialized();
    if (!connected) throw StateError('Google hesabını bağla.');
    final response = await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable(name).call(<String, dynamic>{});
    return ProCrateStatus.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// The month's Pro Kasası (contents, odds, whether it can be opened).
  Future<ProCrateStatus> crate() => _crate('getProCrate');

  /// Opens the month's Kasa once; a retry returns the same contents.
  Future<ProCrateStatus> openCrate() => _crate('claimProCrate');
  Future<void> equip(String itemId) => StoreService.equip(itemId);
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
