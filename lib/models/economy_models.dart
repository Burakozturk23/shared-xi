class EconomyWallet {
  final int coins;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final int? updatedAtMs;
  final int version;

  const EconomyWallet({
    required this.coins,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    this.updatedAtMs,
    this.version = 1,
  });

  static const EconomyWallet empty = EconomyWallet(
    coins: 0,
    lifetimeEarned: 0,
    lifetimeSpent: 0,
  );

  factory EconomyWallet.fromMap(Map<String, dynamic> data) {
    return EconomyWallet(
      coins: _economyInt(data['coins']),
      lifetimeEarned: _economyInt(data['lifetimeEarned']),
      lifetimeSpent: _economyInt(data['lifetimeSpent']),
      updatedAtMs: _economyNullableInt(data['updatedAt']),
      version: _economyInt(data['version'], fallback: 1),
    );
  }
}

class EconomyRewardClaim {
  final String claimId;
  final String txId;
  final String sourceType;
  final String sourceId;
  final int amount;
  final int? claimedAtMs;
  final int version;

  const EconomyRewardClaim({
    required this.claimId,
    required this.txId,
    required this.sourceType,
    required this.sourceId,
    required this.amount,
    this.claimedAtMs,
    this.version = 1,
  });

  factory EconomyRewardClaim.fromMap(
    String claimId,
    Map<String, dynamic> data,
  ) {
    return EconomyRewardClaim(
      claimId: claimId,
      txId: data['txId']?.toString() ?? claimId,
      sourceType: data['sourceType']?.toString() ?? '',
      sourceId: data['sourceId']?.toString() ?? '',
      amount: _economyInt(data['amount']),
      claimedAtMs: _economyNullableInt(data['claimedAt']),
      version: _economyInt(data['version'], fallback: 1),
    );
  }
}

class EconomyLedgerEntry {
  final String txId;
  final String type;
  final String currency;
  final int amount;
  final int balanceAfter;
  final String sourceType;
  final String sourceId;
  final String? itemId;
  final int? createdAtMs;
  final int version;

  const EconomyLedgerEntry({
    required this.txId,
    required this.type,
    required this.currency,
    required this.amount,
    required this.balanceAfter,
    required this.sourceType,
    required this.sourceId,
    this.itemId,
    this.createdAtMs,
    this.version = 1,
  });

  factory EconomyLedgerEntry.fromMap(
    String txId,
    Map<String, dynamic> data,
  ) {
    final rawItemId = data['itemId']?.toString().trim();

    return EconomyLedgerEntry(
      txId: data['txId']?.toString() ?? txId,
      type: data['type']?.toString() ?? '',
      currency: data['currency']?.toString() ?? '',
      amount: _economyInt(data['amount']),
      balanceAfter: _economyInt(data['balanceAfter']),
      sourceType: data['sourceType']?.toString() ?? '',
      sourceId: data['sourceId']?.toString() ?? '',
      itemId: rawItemId == null || rawItemId.isEmpty ? null : rawItemId,
      createdAtMs: _economyNullableInt(data['createdAt']),
      version: _economyInt(data['version'], fallback: 1),
    );
  }
}

class EconomyInventoryItem {
  final String itemId;
  final String itemType;
  final String sourceType;
  final String sourceId;
  final int? acquiredAtMs;
  final int version;

  const EconomyInventoryItem({
    required this.itemId,
    required this.itemType,
    required this.sourceType,
    required this.sourceId,
    this.acquiredAtMs,
    this.version = 1,
  });

  factory EconomyInventoryItem.fromMap(
    String itemId,
    Map<String, dynamic> data,
  ) {
    return EconomyInventoryItem(
      itemId: data['itemId']?.toString() ?? itemId,
      itemType: data['itemType']?.toString() ?? '',
      sourceType: data['sourceType']?.toString() ?? '',
      sourceId: data['sourceId']?.toString() ?? '',
      acquiredAtMs: _economyNullableInt(data['acquiredAt']),
      version: _economyInt(data['version'], fallback: 1),
    );
  }
}

class EconomyClaimResult {
  final bool granted;
  final bool alreadyClaimed;
  final int amount;
  final int coins;

  const EconomyClaimResult({
    required this.granted,
    required this.alreadyClaimed,
    required this.amount,
    required this.coins,
  });
}

class EconomyPurchaseResult {
  final bool purchased;
  final bool alreadyOwned;
  final int priceCoins;
  final int coins;
  final EconomyInventoryItem item;

  const EconomyPurchaseResult({
    required this.purchased,
    required this.alreadyOwned,
    required this.priceCoins,
    required this.coins,
    required this.item,
  });
}

int _economyInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _economyNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
