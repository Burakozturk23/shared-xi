import 'premium_models.dart';

class PremiumBillingProduct {
  final PremiumPlan plan;
  final String productId;
  final String title;
  final String description;
  final String price;
  final String currencyCode;
  final double rawPrice;

  const PremiumBillingProduct({
    required this.plan,
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.rawPrice,
  });
}

class PremiumBillingCatalog {
  final bool storeAvailable;
  final List<PremiumBillingProduct> products;
  final Set<String> missingProductIds;
  final String errorMessage;

  const PremiumBillingCatalog({
    required this.storeAvailable,
    required this.products,
    required this.missingProductIds,
    this.errorMessage = '',
  });

  const PremiumBillingCatalog.unavailable({
    this.errorMessage = '',
  })  : storeAvailable = false,
        products = const <PremiumBillingProduct>[],
        missingProductIds = const <String>{};

  PremiumBillingProduct? productFor(PremiumPlan plan) {
    for (final product in products) {
      if (product.plan == plan) return product;
    }
    return null;
  }
}

class PremiumPurchaseVerificationPayload {
  final String productId;
  final String purchaseId;
  final String transactionDate;
  final String source;
  final String serverVerificationData;
  final String localVerificationData;

  const PremiumPurchaseVerificationPayload({
    required this.productId,
    required this.purchaseId,
    required this.transactionDate,
    required this.source,
    required this.serverVerificationData,
    required this.localVerificationData,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'purchaseId': purchaseId,
      'transactionDate': transactionDate,
      'source': source,
      'serverVerificationData': serverVerificationData,
      'localVerificationData': localVerificationData,
    };
  }
}

