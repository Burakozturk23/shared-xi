import 'economy_models.dart';

class StoreOffer {
  final String offerId;
  final String title;
  final String subtitle;
  final String badge;
  final int priceCoins;
  final String itemId;
  final String itemType;
  final bool oneTime;
  final int sortOrder;
  final int version;

  const StoreOffer({
    required this.offerId,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.priceCoins,
    required this.itemId,
    required this.itemType,
    required this.oneTime,
    required this.sortOrder,
    this.version = 1,
  });

  bool get isAvatar => itemType == 'avatar';

  factory StoreOffer.fromMap(Map<String, dynamic> data) {
    return StoreOffer(
      offerId: data['offerId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      subtitle: data['subtitle']?.toString() ?? '',
      badge: data['badge']?.toString() ?? '',
      priceCoins: _storeInt(data['priceCoins']),
      itemId: data['itemId']?.toString() ?? '',
      itemType: data['itemType']?.toString() ?? '',
      oneTime: data['oneTime'] == true,
      sortOrder: _storeInt(data['sortOrder']),
      version: _storeInt(data['version'], fallback: 1),
    );
  }
}

class StoreCatalogSnapshot {
  final int catalogVersion;
  final EconomyWallet wallet;
  final List<StoreOffer> offers;

  const StoreCatalogSnapshot({
    required this.catalogVersion,
    required this.wallet,
    required this.offers,
  });
}

int _storeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
