import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/premium_models.dart';
import 'package:shared_xi/services/premium_billing_service.dart';

void main() {
  Map<String, dynamic> activeSubscription({
    required String state,
    required bool autoRenewing,
  }) =>
      <String, dynamic>{
        'active': true,
        'plan': 'monthly',
        'provider': 'google_play',
        'productId': PremiumBillingProductIds.monthly,
        'startedAt': 1,
        'expiresAt': 9999999999999,
        'autoRenewing': autoRenewing,
        'subscriptionState': state,
        'benefits': <String, dynamic>{
          'adFree': true,
          'premiumCosmetics': true,
          'dailyRewardMultiplier': 1,
          'streakProtection': false,
        },
        'updatedAt': 2,
        'version': 2,
      };

  test('Linkball Pro launch SKUs are monthly and yearly only', () {
    expect(
      PremiumBillingProductIds.all,
      <String>{
        'linkball_pro_monthly',
        'linkball_pro_yearly',
      },
    );
    expect(
      PremiumBillingProductIds.productIdFor(PremiumPlan.lifetime),
      isNull,
    );
  });

  test('cancelled subscription stays active until expiry but will not renew', () {
    final entitlement = PremiumEntitlement.fromMap(
      activeSubscription(
        state: 'SUBSCRIPTION_STATE_CANCELED',
        autoRenewing: false,
      ),
    );

    expect(entitlement.active, isTrue);
    expect(entitlement.cancellationPending, isTrue);
    expect(entitlement.inGracePeriod, isFalse);
  });

  test('grace-period subscription is surfaced distinctly', () {
    final entitlement = PremiumEntitlement.fromMap(
      activeSubscription(
        state: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        autoRenewing: true,
      ),
    );

    expect(entitlement.active, isTrue);
    expect(entitlement.inGracePeriod, isTrue);
    expect(entitlement.cancellationPending, isFalse);
  });

  test('Pro progression benefits remain noncompetitive', () {
    final entitlement = PremiumEntitlement.fromMap(
      activeSubscription(
        state: 'SUBSCRIPTION_STATE_ACTIVE',
        autoRenewing: true,
      ),
    );

    expect(entitlement.benefits.adFree, isTrue);
    expect(entitlement.benefits.premiumCosmetics, isTrue);
    expect(entitlement.benefits.dailyRewardMultiplier, 1);
    expect(entitlement.benefits.streakProtection, isFalse);
  });
}
