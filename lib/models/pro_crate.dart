/// The month's Pro Kasası as the server reports it (getProCrate / claimProCrate).
class ProCrateTier {
  const ProCrateTier({
    required this.price,
    required this.count,
    required this.chance,
    required this.each,
  });
  final int price, count;

  /// Chance of this tier and of one avatar inside it (0–1).
  final double chance, each;

  factory ProCrateTier.fromMap(Map<String, dynamic> m) => ProCrateTier(
    price: _int(m['price']),
    count: _int(m['count']),
    chance: _double(m['chance']),
    each: _double(m['each']),
  );
}

/// What a draw may give: the avatar tiers, or the fallback once every avatar is owned.
class DrawOdds {
  const DrawOdds({this.count = 0, this.tiers = const [], this.fallback = ''});
  final int count;
  final List<ProCrateTier> tiers;

  /// 'kit' or 'coins' when no avatar is left, else ''.
  final String fallback;

  static DrawOdds from(Object? raw) {
    if (raw is! Map) return const DrawOdds();
    return DrawOdds(
      count: _int(raw['count']),
      tiers: raw['tiers'] is List
          ? [
              for (final t in (raw['tiers'] as List).whereType<Map>())
                ProCrateTier.fromMap(Map<String, dynamic>.from(t)),
            ]
          : const [],
      fallback: raw['fallback']?.toString() ?? '',
    );
  }

  ProCrateTier? tier(int price) {
    for (final t in tiers) {
      if (t.price == price) return t;
    }
    return null;
  }
}

/// What a draw gave: an avatar, a kit, or coins.
class DrawResult {
  const DrawResult({
    required this.kind,
    this.itemId = '',
    this.title = '',
    this.coins = 0,
  });
  final String kind, itemId, title;
  final int coins;

  static DrawResult? from(Object? raw) {
    if (raw is! Map || (raw['kind']?.toString() ?? '').isEmpty) return null;
    return DrawResult(
      kind: raw['kind'].toString(),
      itemId: raw['itemId']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      coins: _int(raw['coins']),
    );
  }
}

class ProCrateStatus {
  const ProCrateStatus({
    required this.enabled,
    required this.pro,
    required this.month,
    required this.endsOn,
    required this.daysLeft,
    required this.remind,
    required this.opened,
    required this.canOpen,
    required this.openableAtMs,
    required this.contents,
    required this.avatarTier,
    required this.odds,
    this.supports = const {},
    this.overflowCoins = 0,
    this.avatar,
  });
  final bool enabled, pro, remind, opened, canOpen;
  final String month, endsOn;
  final int daysLeft, openableAtMs, avatarTier, overflowCoins;

  /// Support items and counts the Kasa holds (12 Temel, 4 Güçlü…).
  final Map<String, int> contents;
  final DrawOdds odds;

  /// After opening: supports actually added and the avatar drawn.
  final Map<String, int> supports;
  final DrawResult? avatar;

  factory ProCrateStatus.fromMap(Map<String, dynamic> m) {
    final raw = m['contents'] is Map
        ? Map<String, dynamic>.from(m['contents'] as Map)
        : <String, dynamic>{};
    final receipt = m['receipt'] is Map
        ? Map<String, dynamic>.from(m['receipt'] as Map)
        : const <String, dynamic>{};
    return ProCrateStatus(
      enabled: m['enabled'] == true,
      pro: m['pro'] == true,
      month: m['month']?.toString() ?? '',
      endsOn: m['endsOn']?.toString() ?? '',
      daysLeft: _int(m['daysLeft']),
      remind: m['remind'] == true,
      opened: m['opened'] == true,
      canOpen: m['canOpen'] == true,
      openableAtMs: _int(m['openableAt']),
      avatarTier: _int(raw['avatarTier'], fallback: 450),
      contents: {
        for (final e in raw.entries)
          if (e.key != 'avatarTier') e.key: _int(e.value),
      },
      odds: DrawOdds.from(m['odds']),
      supports: receipt['supports'] is Map
          ? {
              for (final e in (receipt['supports'] as Map).entries)
                e.key.toString(): _int(e.value),
            }
          : const {},
      overflowCoins: _int(receipt['overflowCoins']),
      avatar: DrawResult.from(receipt['avatar']),
    );
  }
}

int _int(Object? v, {int fallback = 0}) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback;

double _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
