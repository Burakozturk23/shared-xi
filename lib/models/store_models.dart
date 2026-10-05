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
  final String category;
  final int units;

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
    this.category = 'classic',
    this.units = 1,
  });

  bool get isAvatar => itemType == 'avatar';

  factory StoreOffer.fromMap(Map<String, dynamic> data) {
    return StoreOffer(
      offerId: data['offerId']?.toString() ?? '',
      category: data['category']?.toString() ?? 'classic',
      units: _storeInt(data['units'], fallback: 1),
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
  final Map<String, EconomyInventoryItem> inventory;
  final String selectedAvatarId, selectedKitId;

  const StoreCatalogSnapshot({
    required this.catalogVersion,
    required this.wallet,
    required this.offers,
    this.inventory = const {},
    this.selectedAvatarId = 'starter_ball',
    this.selectedKitId = '',
  });
}

int _storeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
