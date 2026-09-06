enum PremiumPlan {
  none,
  monthly,
  yearly,
  lifetime,
}

class PremiumBenefits {
  final bool adFree;
  final bool premiumCosmetics;
  final int dailyRewardMultiplier;
  final bool streakProtection;

  const PremiumBenefits({
    required this.adFree,
    required this.premiumCosmetics,
    required this.dailyRewardMultiplier,
    required this.streakProtection,
  });

  const PremiumBenefits.inactive()
      : adFree = false,
        premiumCosmetics = false,
        dailyRewardMultiplier = 1,
        streakProtection = false;

  factory PremiumBenefits.fromMap(Map<String, dynamic> data) {
    final multiplier = _premiumInt(
      data['dailyRewardMultiplier'],
      fallback: 1,
    );

    return PremiumBenefits(
      adFree: data['adFree'] == true,
      premiumCosmetics: data['premiumCosmetics'] == true,
      dailyRewardMultiplier: multiplier < 1 ? 1 : multiplier,
      streakProtection: data['streakProtection'] == true,
    );
  }
}

class PremiumEntitlement {
  final bool active;
  final PremiumPlan plan;
  final String provider;
  final String productId;
  final int startedAt;
  final int expiresAt;
  final bool autoRenewing;
  final PremiumBenefits benefits;
  final int updatedAt;
  final int version;

  const PremiumEntitlement({
    required this.active,
    required this.plan,
    required this.provider,
    required this.productId,
    required this.startedAt,
    required this.expiresAt,
    required this.autoRenewing,
    required this.benefits,
    required this.updatedAt,
    this.version = 1,
  });

  const PremiumEntitlement.inactive()
      : active = false,
        plan = PremiumPlan.none,
        provider = '',
        productId = '',
        startedAt = 0,
        expiresAt = 0,
        autoRenewing = false,
        benefits = const PremiumBenefits.inactive(),
        updatedAt = 0,
        version = 1;

  bool get isLifetime => active && plan == PremiumPlan.lifetime;

  factory PremiumEntitlement.fromMap(Map<String, dynamic> data) {
    final active = data['active'] == true;

    return PremiumEntitlement(
      active: active,
      plan: active
          ? _premiumPlan(data['plan']?.toString())
          : PremiumPlan.none,
      provider: active ? data['provider']?.toString() ?? '' : '',
      productId: active ? data['productId']?.toString() ?? '' : '',
      startedAt: active ? _premiumInt(data['startedAt']) : 0,
      expiresAt: active ? _premiumInt(data['expiresAt']) : 0,
      autoRenewing: active && data['autoRenewing'] == true,
      benefits: data['benefits'] is Map
          ? PremiumBenefits.fromMap(
              Map<String, dynamic>.from(data['benefits'] as Map),
            )
          : const PremiumBenefits.inactive(),
      updatedAt: _premiumInt(data['updatedAt']),
      version: _premiumInt(data['version'], fallback: 1),
    );
  }
}

PremiumPlan _premiumPlan(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'monthly':
      return PremiumPlan.monthly;
    case 'yearly':
      return PremiumPlan.yearly;
    case 'lifetime':
      return PremiumPlan.lifetime;
    default:
      return PremiumPlan.none;
  }
}

int _premiumInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
