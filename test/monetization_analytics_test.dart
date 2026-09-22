import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/monetization_analytics.dart';

void main() {
  test('monetization cohort events use a stable non-PII contract', () async {
    final events = <(String, Map<String, Object>)>[];
    final analytics = MonetizationAnalytics(
      enabled: true,
      writer: (name, parameters) async {
        events.add((name, parameters));
      },
    );

    await analytics.surfaceViewed('store');
    await analytics.purchaseStarted(
      flow: 'coin_pack',
      productId: 'linkball_coins_500',
    );
    await analytics.purchaseCompleted(
      flow: 'pro',
      productId: 'linkball_pro_monthly',
    );
    await analytics.purchaseCompleted(
      flow: 'coin_pack',
      productId: 'linkball_coins_500',
      restored: true,
    );
    await analytics.storeOfferStarted(
      offerId: 'avatar_champion',
      coinPrice: 600,
    );
    await analytics.storeOfferCompleted(
      offerId: 'avatar_champion',
      coinPrice: 600,
    );
    await analytics.premiumCancelled('linkball_pro_monthly');

    expect(
      events.map((event) => event.$1),
      <String>[
        'monetization_surface_view',
        'purchase_started',
        'purchase_completed',
        'purchase_restored',
        'store_offer_started',
        'store_offer_completed',
        'premium_cancelled',
      ],
    );
    expect(events[0].$2, <String, Object>{'surface': 'store'});
    expect(events[1].$2['flow'], 'coin_pack');
    expect(events[4].$2['coin_price'], 600);

    for (final event in events) {
      expect(event.$2.containsKey('uid'), isFalse);
      expect(event.$2.containsKey('purchase_token'), isFalse);
      expect(event.$2.containsKey('nickname'), isFalse);
    }
  });

  test('disabled telemetry is a no-op', () async {
    var calls = 0;
    final analytics = MonetizationAnalytics(
      enabled: false,
      writer: (_, __) async => calls++,
    );

    await analytics.surfaceViewed('store');
    await analytics.purchaseStarted(flow: 'pro', productId: 'x');

    expect(calls, 0);
  });
}
