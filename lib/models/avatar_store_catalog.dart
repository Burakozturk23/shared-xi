import 'avatar_browser.dart';
import 'store_models.dart';
import 'user_avatar_catalog.dart';

/// Show all bundled artwork even while an older server catalog is live.
/// Only a real server offer supplies a price or enables purchasing.
List<StoreOffer> avatarStoreOffers(List<StoreOffer> serverOffers) {
  final byId = <String, StoreOffer>{
    for (final offer in serverOffers)
      if (offer.isAvatar && UserAvatarCatalog.contains(offer.itemId)) offer.itemId: offer,
  };
  final ordered = [
    ...UserAvatarCatalog.all.where((a) => a.visualKey.startsWith('persona_')),
    ...UserAvatarCatalog.all.where((a) => !a.visualKey.startsWith('persona_')),
  ];
  return [for (final avatar in ordered)
    if (!avatar.isStarter) byId[avatar.id] ?? StoreOffer(
      offerId: '', title: avatar.title, subtitle: avatar.subtitle,
      badge: '', priceCoins: 0, itemId: avatar.id, itemType: 'avatar',
      oneTime: true, sortOrder: 10000, category: avatarCategory(avatar), isPreview: true,
    ),
  ];
}
