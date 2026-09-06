import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/premium_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class PremiumService {
  PremiumService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static DatabaseReference? get _entitlementRef {
    final uid = AuthService.uid;
    if (uid == null || uid.isEmpty) return null;

    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
    ).ref('premiumEntitlements/$uid');
  }

  static Future<PremiumEntitlement> fetchStatus() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final callable = _functions.httpsCallable('getMyPremiumStatus');
    final response = await callable.call();
    final data = _map(response.data);

    if (data['ok'] != true || data['entitlement'] is! Map) {
      throw StateError('Premium durumu yüklenemedi.');
    }

    return PremiumEntitlement.fromMap(
      Map<String, dynamic>.from(data['entitlement'] as Map),
    );
  }

  static Stream<PremiumEntitlement> watchStatus() async* {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final ref = _entitlementRef;
    if (ref == null) {
      yield const PremiumEntitlement.inactive();
      return;
    }

    await fetchStatus();

    yield* ref.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        return const PremiumEntitlement.inactive();
      }

      return PremiumEntitlement.fromMap(
        Map<String, dynamic>.from(raw),
      );
    });
  }


  static Future<PremiumEntitlement> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final token = purchaseToken.trim();
    if (productId.trim().isEmpty || token.isEmpty) {
      throw ArgumentError('Google Play purchase data is incomplete.');
    }

    final callable = _functions.httpsCallable('verifyPremiumPurchase');
    final response = await callable.call(<String, dynamic>{
      'productId': productId.trim(),
      'purchaseToken': token,
    });
    final data = _map(response.data);

    if (data['ok'] != true || data['entitlement'] is! Map) {
      throw StateError('Premium satın alma doğrulanamadı.');
    }

    return PremiumEntitlement.fromMap(
      Map<String, dynamic>.from(data['entitlement'] as Map),
    );
  }

  static void _requireGoogleAccount() {
    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError(
        'Premium için Google hesabına bağlı profil gerekli.',
      );
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}
