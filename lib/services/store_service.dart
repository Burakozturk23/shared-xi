import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
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

      final offer = StoreOffer.fromMap(Map<String, dynamic>.from(raw));

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
      inventory: {
        for (final entry in _map(data['inventory']).entries)
          if (entry.value is Map)
            entry.key: EconomyInventoryItem.fromMap(
              entry.key,
              _map(entry.value),
            ),
      },
      selectedAvatarId: data['selectedAvatarId']?.toString() ?? 'starter_ball',
      selectedKitId: data['selectedKitId']?.toString() ?? '',
      catalogVersion: _int(data['catalogVersion'], fallback: 1),
      wallet: EconomyWallet.fromMap(Map<String, dynamic>.from(rawWallet)),
      offers: List<StoreOffer>.unmodifiable(offers),
    );
  }

  static String newRequestId() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Future<EconomyPurchaseResult> purchase(StoreOffer offer) async {
    _requireGoogleAccount();
    final uid = AuthService.uid!;
    final store = await SharedPreferences.getInstance();
    final key = 'linkball.store.pending.$uid.${offer.offerId}';
    final requestId = store.getString(key) ?? newRequestId();
    // Persist before spending. An interrupted response/restart reuses the receipt ID.
    if (!await store.setString(key, requestId))
      throw StateError('İşlem kaydedilemedi.');
    if (AuthService.uid != uid) throw StateError('Hesabın değişti.');
    final result = await EconomyService.purchaseOffer(
      offer.offerId,
      expectedPriceCoins: offer.priceCoins,
      requestId: requestId,
    );
    await store.remove(key);
    return result;
  }

  static Future<int> consume({
    required String itemId,
    required String modeId,
    required String roundId,
  }) async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();
    final result = await _functions.httpsCallable('consumeStoreBoost').call({
      'itemId': itemId,
      'modeId': modeId,
      'roundId': roundId,
    });
    final data = _map(result.data);
    if (data['ok'] != true || data['consumed'] != true)
      throw StateError('Destek kullanılamadı.');
    return _int(data['quantity']);
  }

  static Future<void> equip(String itemId) async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();
    final result = await _functions.httpsCallable('equipStoreItem').call({
      'itemId': itemId,
    });
    if (_map(result.data)['ok'] != true) throw StateError('Ürün seçilemedi.');
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
