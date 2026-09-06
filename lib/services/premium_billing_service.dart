import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium_billing_models.dart';
import '../models/premium_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';
import 'premium_service.dart';

class PremiumBillingProductIds {
  PremiumBillingProductIds._();

  // Canonical Google Play product ids for Linkball Premium.
  // Prices are NEVER hard-coded in the app; ProductDetails.price comes
  // from Google Play after these ids are created in Play Console.
  static const String monthly = 'linkball_premium_monthly';
  static const String yearly = 'linkball_premium_yearly';
  static const String lifetime = 'linkball_premium_lifetime';

  static const Set<String> all = <String>{
    monthly,
    yearly,
    lifetime,
  };

  static PremiumPlan? planFor(String productId) {
    switch (productId) {
      case monthly:
        return PremiumPlan.monthly;
      case yearly:
        return PremiumPlan.yearly;
      case lifetime:
        return PremiumPlan.lifetime;
      default:
        return null;
    }
  }

  static String? productIdFor(PremiumPlan plan) {
    switch (plan) {
      case PremiumPlan.monthly:
        return monthly;
      case PremiumPlan.yearly:
        return yearly;
      case PremiumPlan.lifetime:
        return lifetime;
      case PremiumPlan.none:
        return null;
    }
  }
}

class PremiumBillingService {
  PremiumBillingService._();

  static final InAppPurchase _iap = InAppPurchase.instance;

  static final Map<String, ProductDetails> _detailsById =
      <String, ProductDetails>{};

  static Stream<List<PurchaseDetails>> get purchaseUpdates =>
      _iap.purchaseStream;

  static Future<PremiumBillingCatalog> queryCatalog() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final available = await _iap.isAvailable();
    if (!available) {
      return const PremiumBillingCatalog.unavailable(
        errorMessage: 'Google Play satın alma servisi kullanılamıyor.',
      );
    }

    final response = await _iap.queryProductDetails(
      PremiumBillingProductIds.all,
    );

    _detailsById
      ..clear()
      ..addEntries(
        response.productDetails.map(
          (details) => MapEntry<String, ProductDetails>(
            details.id,
            details,
          ),
        ),
      );

    final products = <PremiumBillingProduct>[];

    for (final details in response.productDetails) {
      final plan = PremiumBillingProductIds.planFor(details.id);
      if (plan == null) continue;

      products.add(
        PremiumBillingProduct(
          plan: plan,
          productId: details.id,
          title: details.title,
          description: details.description,
          price: details.price,
          currencyCode: details.currencyCode,
          rawPrice: details.rawPrice,
        ),
      );
    }

    products.sort(
      (a, b) => _planOrder(a.plan).compareTo(_planOrder(b.plan)),
    );

    return PremiumBillingCatalog(
      storeAvailable: true,
      products: products,
      missingProductIds: response.notFoundIDs.toSet(),
      errorMessage: response.error?.message ?? '',
    );
  }

  static Future<bool> purchasePlan(PremiumPlan plan) async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final productId = PremiumBillingProductIds.productIdFor(plan);
    if (productId == null) {
      throw ArgumentError.value(plan, 'plan', 'Premium plan is not purchasable.');
    }

    var details = _detailsById[productId];

    if (details == null) {
      final catalog = await queryCatalog();
      if (!catalog.storeAvailable) {
        throw StateError(
          catalog.errorMessage.isEmpty
              ? 'Google Play satın alma servisi kullanılamıyor.'
              : catalog.errorMessage,
        );
      }
      details = _detailsById[productId];
    }

    if (details == null) {
      throw StateError(
        'Premium ürünü Google Play üzerinde bulunamadı: $productId',
      );
    }

    final purchaseParam = PurchaseParam(productDetails: details);

    // Subscriptions and the lifetime permanent upgrade are both
    // non-consumable from Linkball's point of view.
    //
    // IMPORTANT: a successful store callback does NOT grant Premium.
    // The purchase must first be verified by the trusted backend.
    return _iap.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  static Future<void> restorePurchases() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();
    await _iap.restorePurchases();
  }

  static bool requiresServerVerification(PurchaseDetails purchase) {
    return purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;
  }

  static PremiumPurchaseVerificationPayload verificationPayload(
    PurchaseDetails purchase,
  ) {
    if (!PremiumBillingProductIds.all.contains(purchase.productID)) {
      throw StateError(
        'Unknown Premium product id: ${purchase.productID}',
      );
    }

    final verification = purchase.verificationData;
    final serverData = verification.serverVerificationData.trim();

    if (serverData.isEmpty) {
      throw StateError(
        'Google Play server verification data is empty.',
      );
    }

    return PremiumPurchaseVerificationPayload(
      productId: purchase.productID,
      purchaseId: purchase.purchaseID ?? '',
      transactionDate: purchase.transactionDate ?? '',
      source: verification.source,
      serverVerificationData: serverData,
      localVerificationData: verification.localVerificationData,
    );
  }


  static Future<PremiumEntitlement> verifyAndComplete(
    PurchaseDetails purchase,
  ) async {
    if (!requiresServerVerification(purchase)) {
      throw StateError(
        'Satın alma henüz sunucu doğrulamasına hazır değil.',
      );
    }

    final payload = verificationPayload(purchase);
    final entitlement = await PremiumService.verifyGooglePlayPurchase(
      productId: payload.productId,
      purchaseToken: payload.serverVerificationData,
    );

    await completeAfterServerVerification(purchase);
    return entitlement;
  }

  static Future<void> completeAfterServerVerification(
    PurchaseDetails purchase,
  ) async {
    if (!purchase.pendingCompletePurchase) return;
    await _iap.completePurchase(purchase);
  }

  static int _planOrder(PremiumPlan plan) {
    switch (plan) {
      case PremiumPlan.monthly:
        return 0;
      case PremiumPlan.yearly:
        return 1;
      case PremiumPlan.lifetime:
        return 2;
      case PremiumPlan.none:
        return 99;
    }
  }

  static void _requireGoogleAccount() {
    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError(
        'Premium satın alma için Google hesabına bağlı profil gerekli.',
      );
    }
  }
}
