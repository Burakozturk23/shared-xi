import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'auth_service.dart';
import 'cloud_bootstrap.dart';

const coinProductAmounts = <String, int>{
  'linkball_coins_500': 500,
  'linkball_coins_1400': 1400,
  'linkball_coins_3200': 3200,
};

class CoinCatalog {
  const CoinCatalog({required this.enabled, required this.accountId});
  final bool enabled;
  final String accountId;
}

abstract class CoinBillingGateway {
  String? get uid;
  Stream<List<PurchaseDetails>> get purchases;
  Future<CoinCatalog> catalog();
  Future<List<ProductDetails>> products();
  Future<bool> buy(ProductDetails product, String accountId);
  Future<void> restore();
  Future<void> verify(PurchaseDetails purchase);
}

class PlayCoinBillingGateway implements CoinBillingGateway {
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );
  @override
  String? get uid => AuthService.isGoogleAccount ? AuthService.uid : null;
  @override
  Stream<List<PurchaseDetails>> get purchases =>
      InAppPurchase.instance.purchaseStream;
  @override
  Future<CoinCatalog> catalog() async {
    final response = await _functions
        .httpsCallable('getCoinPurchaseCatalog')
        .call();
    final data = Map<String, dynamic>.from(response.data as Map);
    final id = data['accountId'] as String? ?? '';
    if (data['ok'] != true || !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw StateError('Mağaza doğrulanamadı.');
    }
    return CoinCatalog(enabled: data['enabled'] == true, accountId: id);
  }

  @override
  Future<List<ProductDetails>> products() async {
    if (!await InAppPurchase.instance.isAvailable()) {
      throw StateError('Google Play kullanılamıyor.');
    }
    final result = await InAppPurchase.instance.queryProductDetails(
      coinProductAmounts.keys.toSet(),
    );
    if (result.error != null) throw StateError('Ürünler yüklenemedi.');
    return result.productDetails
        .where((p) => coinProductAmounts.containsKey(p.id))
        .toList()
      ..sort(
        (a, b) =>
            coinProductAmounts[a.id]!.compareTo(coinProductAmounts[b.id]!),
      );
  }

  @override
  Future<bool> buy(ProductDetails product, String accountId) =>
      InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: accountId,
        ),
        autoConsume: false,
      );
  @override
  Future<void> restore() => InAppPurchase.instance.restorePurchases();
  @override
  Future<void> verify(PurchaseDetails purchase) async {
    if (purchase.verificationData.source != 'google_play') {
      throw StateError('Google Play satın alması gerekli.');
    }
    final result = await _functions.httpsCallable('verifyCoinPurchase').call({
      'productId': purchase.productID,
      'purchaseToken': purchase.verificationData.serverVerificationData,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['ok'] != true || data['consumed'] != true) {
      throw StateError('Satın alma doğrulaması bekliyor.');
    }
    // Google Play consumption/acknowledgement is completed by the backend.
    // Do not auto-consume or acknowledge before the durable wallet grant.
  }
}

class CoinBillingService extends ChangeNotifier with WidgetsBindingObserver {
  CoinBillingService(this.gateway);
  final CoinBillingGateway gateway;
  static final instance = CoinBillingService(PlayCoinBillingGateway());
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  StreamSubscription<dynamic>? _authSubscription;
  final Set<String> _inFlight = {};
  final Set<String> _done = {};
  List<ProductDetails> products = [];
  String message = '';
  bool loading = false;
  bool enabled = false;
  bool purchasing = false;
  String? _catalogUid;
  String _accountId = '';
  int _generation = 0;
  bool _disposed = false;
  bool _refreshing = false;

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await CloudBootstrap.ensureInitialized();
      final service = instance;
      service.listen();
      WidgetsBinding.instance.addObserver(service);
      service._authSubscription ??= AuthService.authStateChanges.listen((_) {
        unawaited(service.refresh());
      });
    } catch (_) {
      instance.message =
          'Google Play bağlantısı kurulamadı. Mağazadan tekrar deneyebilirsin.';
    }
  }

  void listen() {
    _subscription ??= gateway.purchases.listen(
      (events) {
        unawaited(handle(events));
      },
      onError: (Object _) {
        message = 'Satın alma bağlantısı kesildi. Satın almaları kontrol et.';
        purchasing = false;
        _emit();
      },
    );
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final uid = gateway.uid;
    enabled = false;
    products = [];
    _accountId = '';
    _catalogUid = uid;
    purchasing = false;
    message = '';
    if (uid == null) {
      loading = false;
      _emit();
      return;
    }
    loading = true;
    _emit();
    try {
      listen();
      final catalog = await gateway.catalog();
      final details = catalog.enabled
          ? await gateway.products()
          : <ProductDetails>[];
      if (generation != _generation || gateway.uid != uid) return;
      enabled = catalog.enabled;
      _accountId = catalog.accountId;
      products = details;
      message = !enabled
          ? 'Coin paketleri yakında satışta.'
          : products.length < coinProductAmounts.length
          ? 'Bazı paketler şu anda Google Play’de kullanılamıyor.'
          : '';
    } catch (_) {
      if (generation == _generation) {
        message = 'Paketler yüklenemedi. Tekrar deneyebilirsin.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _emit();
      }
    }
    // Recovery remains available when new sales are disabled or catalog fails.
    if (gateway.uid == uid) await restore();
  }

  Future<void> buy(ProductDetails product) async {
    if (!enabled ||
        purchasing ||
        gateway.uid == null ||
        gateway.uid != _catalogUid ||
        !products.contains(product) ||
        _accountId.isEmpty) {
      return;
    }
    purchasing = true;
    unawaited(_event('purchase_started', product.id));
    message = 'Google Play açılıyor…';
    _emit();
    try {
      if (!await gateway.buy(product, _accountId)) {
        purchasing = false;
        message = 'Satın alma başlatılamadı.';
      }
    } catch (_) {
      purchasing = false;
      message = 'Satın alma başlatılamadı. Tekrar deneyebilirsin.';
    }
    _emit();
  }

  Future<void> restore() async {
    if (gateway.uid == null || _refreshing) return;
    _refreshing = true;
    try {
      await gateway.restore();
    } catch (_) {
      message =
          'Satın almalar kontrol edilemedi. Bağlantını kontrol edip tekrar dene.';
      _emit();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> handle(List<PurchaseDetails> events) async {
    for (final purchase in events) {
      if (!coinProductAmounts.containsKey(purchase.productID)) continue;
      final uid = gateway.uid;
      if (uid == null) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasing = true;
          message = 'Ödeme onayı bekleniyor. Onaylanınca coinlerin eklenecek.';
          _emit();
          continue;
        case PurchaseStatus.canceled:
          purchasing = false;
          message = 'Satın alma iptal edildi; coin eklenmedi.';
          _emit();
          continue;
        case PurchaseStatus.error:
          purchasing = false;
          message = 'Ödeme tamamlanamadı. Satın almaları kontrol edebilirsin.';
          _emit();
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          break;
      }
      final key = '$uid:${purchase.verificationData.serverVerificationData}';
      if (_done.contains(key) || !_inFlight.add(key)) continue;
      message = 'Satın alma doğrulanıyor…';
      _emit();
      try {
        await gateway.verify(purchase);
        _done.add(key);
        unawaited(
          _event(
            purchase.status == PurchaseStatus.restored
                ? 'purchase_restored'
                : 'purchase_completed',
            purchase.productID,
          ),
        );
        if (gateway.uid == uid) {
          message = 'Satın alma doğrulandı. Link Coin bakiyen güncellendi.';
        }
      } catch (_) {
        if (gateway.uid == uid) {
          message =
              'Satın alma henüz doğrulanamadı. Aynı paketi tekrar almadan önce “Satın almaları kontrol et”e dokun.';
        }
      } finally {
        _inFlight.remove(key);
        purchasing = false;
        _emit();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Pending store dialogs may have been canceled without a delivery event.
      purchasing = false;
      _emit();
      unawaited(restore());
    }
  }

  Future<void> _event(String name, String productId) async {
    if (!kReleaseMode) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: {'product_id': productId},
      );
    } catch (_) {
      // Purchase settlement never depends on telemetry.
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
