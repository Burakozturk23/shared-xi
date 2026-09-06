import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/economy_models.dart';
import '../models/store_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';
import 'economy_service.dart';

class StoreService {
  StoreService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static Future<StoreCatalogSnapshot> fetchCatalog() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final callable = _functions.httpsCallable('getStoreCatalog');
    final response = await callable.call();
    final data = _map(response.data);

    if (data['ok'] != true) {
      throw StateError('Mağaza kataloğu yüklenemedi.');
    }

    final rawWallet = data['wallet'];
    final rawOffers = data['offers'];

    if (rawWallet is! Map || rawOffers is! List) {
      throw StateError('Mağaza kataloğu geçersiz veri döndürdü.');
    }

    final offers = <StoreOffer>[];

    for (final raw in rawOffers) {
      if (raw is! Map) continue;

      final offer = StoreOffer.fromMap(
        Map<String, dynamic>.from(raw),
      );

      if (offer.offerId.isEmpty ||
          offer.itemId.isEmpty ||
          offer.priceCoins <= 0) {
        continue;
      }

      offers.add(offer);
    }

    offers.sort((a, b) {
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return a.offerId.compareTo(b.offerId);
    });

    return StoreCatalogSnapshot(
      catalogVersion: _int(data['catalogVersion'], fallback: 1),
      wallet: EconomyWallet.fromMap(
        Map<String, dynamic>.from(rawWallet),
      ),
      offers: List<StoreOffer>.unmodifiable(offers),
    );
  }

  static Future<EconomyPurchaseResult> purchase(
    StoreOffer offer,
  ) {
    _requireGoogleAccount();
    return EconomyService.purchaseOffer(offer.offerId);
  }

  static void _requireGoogleAccount() {
    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError(
        'Mağazayı kullanmak için Google hesabına bağlı profil gerekli.',
      );
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
