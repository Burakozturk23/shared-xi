import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

typedef MonetizationAnalyticsWriter = Future<void> Function(
  String name,
  Map<String, Object> parameters,
);

/// Stable, non-blocking telemetry contract for launch monetization cohorts.
///
/// Reward settlement, purchases, navigation and entitlement checks never depend
/// on analytics success. The service intentionally records only product/surface
/// identifiers and aggregate funnel state; it does not send purchase tokens,
/// UIDs, nicknames or other account identifiers.
class MonetizationAnalytics {
  MonetizationAnalytics({
    MonetizationAnalyticsWriter? writer,
    bool? enabled,
  })  : _writer = writer ?? _firebaseWriter,
        _enabled = enabled ??
            (kReleaseMode ||
                const bool.fromEnvironment('LINKBALL_TELEMETRY_DEBUG'));

  static final MonetizationAnalytics instance = MonetizationAnalytics();

  final MonetizationAnalyticsWriter _writer;
  final bool _enabled;

  Future<void> surfaceViewed(String surface) => _log(
        'monetization_surface_view',
        <String, Object>{'surface': _clean(surface)},
      );

  Future<void> purchaseStarted({
    required String flow,
    required String productId,
  }) =>
      _log(
        'purchase_started',
        <String, Object>{
          'flow': _clean(flow),
          'product_id': _clean(productId),
        },
      );

  Future<void> purchaseCompleted({
    required String flow,
    required String productId,
    bool restored = false,
  }) =>
      _log(
        restored ? 'purchase_restored' : 'purchase_completed',
        <String, Object>{
          'flow': _clean(flow),
          'product_id': _clean(productId),
        },
      );

  Future<void> storeOfferStarted({
    required String offerId,
    required int coinPrice,
  }) =>
      _log(
        'store_offer_started',
        <String, Object>{
          'offer_id': _clean(offerId),
          'coin_price': coinPrice,
        },
      );

  Future<void> storeOfferCompleted({
    required String offerId,
    required int coinPrice,
  }) =>
      _log(
        'store_offer_completed',
        <String, Object>{
          'offer_id': _clean(offerId),
          'coin_price': coinPrice,
        },
      );

  Future<void> premiumCancelled(String productId) => _log(
        'premium_cancelled',
        <String, Object>{
          'flow': 'pro',
          'product_id': _clean(productId),
        },
      );

  Future<void> _log(String name, Map<String, Object> parameters) async {
    if (!_enabled) return;
    try {
      await _writer(name, parameters);
    } catch (_) {
      // Telemetry must never block monetization settlement or gameplay.
    }
  }

  static String _clean(String value) {
    final cleaned = value.trim();
    return cleaned.length <= 100 ? cleaned : cleaned.substring(0, 100);
  }

  static Future<void> _firebaseWriter(
    String name,
    Map<String, Object> parameters,
  ) =>
      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
}
