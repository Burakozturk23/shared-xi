import '../models/store_models.dart';
import '../models/economy_models.dart';
import 'auth_service.dart';
import 'store_service.dart';
import 'monetization_analytics.dart';

class StoreGateway {
  const StoreGateway();
  bool get connected => AuthService.isGoogleAccount;
  Future<StoreCatalogSnapshot> load() => StoreService.fetchCatalog();
  Future<EconomyPurchaseResult> purchase(StoreOffer offer) =>
      StoreService.purchase(offer);
  Future<void> equip(String itemId) => StoreService.equip(itemId);
  Future<int> consume(String itemId, String modeId, String roundId) =>
      StoreService.consume(itemId: itemId, modeId: modeId, roundId: roundId);
  Future<void> view() => MonetizationAnalytics.instance.surfaceViewed('store');
  Future<void> started(StoreOffer o) => MonetizationAnalytics.instance
      .storeOfferStarted(offerId: o.offerId, coinPrice: o.priceCoins);
  Future<void> completed(StoreOffer o) => MonetizationAnalytics.instance
      .storeOfferCompleted(offerId: o.offerId, coinPrice: o.priceCoins);
}
