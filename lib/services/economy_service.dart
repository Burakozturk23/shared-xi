import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/economy_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class EconomyService {
  EconomyService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
      );

  static Future<EconomyWallet> syncMyWallet() async {
    await CloudBootstrap.ensureInitialized();
    _requireUid();

    final callable = _functions.httpsCallable('syncMyWallet');
    final response = await callable.call();
    final data = _map(response.data);
    final rawWallet = data['wallet'];

    if (data['ok'] != true || rawWallet is! Map) {
      throw StateError('Coin bakiyesi eşitlenemedi.');
    }

    return EconomyWallet.fromMap(
      Map<String, dynamic>.from(rawWallet),
    );
  }

  static Future<EconomyClaimResult> claimAchievementReward(
    String achievementId,
  ) async {
    await CloudBootstrap.ensureInitialized();
    _requireUid();

    final callable = _functions.httpsCallable(
      'claimAchievementReward',
    );
    final response = await callable.call(<String, dynamic>{
      'achievementId': achievementId,
    });
    final data = _map(response.data);

    if (data['ok'] != true) {
      throw StateError('Başarım ödülü alınamadı.');
    }

    return EconomyClaimResult(
      granted: data['granted'] == true,
      alreadyClaimed: data['alreadyClaimed'] == true,
      amount: _int(data['amount']),
      coins: _int(data['coins']),
    );
  }

  static Future<EconomyPurchaseResult> purchaseOffer(
    String offerId,
  ) async {
    await CloudBootstrap.ensureInitialized();
    _requireUid();

    final normalized = offerId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        offerId,
        'offerId',
        'Mağaza teklifi kimliği boş olamaz.',
      );
    }

    final callable = _functions.httpsCallable(
      'purchaseEconomyOffer',
    );
    final response = await callable.call(<String, dynamic>{
      'offerId': normalized,
    });
    final data = _map(response.data);
    final rawItem = data['item'];

    if (data['ok'] != true || rawItem is! Map) {
      throw StateError('Coin harcaması tamamlanamadı.');
    }

    return EconomyPurchaseResult(
      purchased: data['purchased'] == true,
      alreadyOwned: data['alreadyOwned'] == true,
      priceCoins: _int(data['priceCoins']),
      coins: _int(data['coins']),
      item: EconomyInventoryItem.fromMap(
        rawItem['itemId']?.toString() ?? '',
        Map<String, dynamic>.from(rawItem),
      ),
    );
  }

  static Stream<EconomyWallet> watchWallet() {
    final uid = _requireUid();

    return _db.ref('walletBalances/$uid').onValue.map((event) {
      final value = event.snapshot.value;

      if (value is! Map) {
        return EconomyWallet.empty;
      }

      return EconomyWallet.fromMap(
        Map<String, dynamic>.from(value),
      );
    });
  }

  static Stream<Map<String, EconomyRewardClaim>> watchRewardClaims() {
    final uid = _requireUid();

    return _db.ref('rewardClaims/$uid').onValue.map((event) {
      final value = event.snapshot.value;

      if (value is! Map) {
        return const <String, EconomyRewardClaim>{};
      }

      final rows = <String, EconomyRewardClaim>{};

      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        final claimId = entry.key.toString();
        rows[claimId] = EconomyRewardClaim.fromMap(
          claimId,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }

      return Map<String, EconomyRewardClaim>.unmodifiable(rows);
    });
  }

  static Stream<List<EconomyLedgerEntry>> watchLedger({
    int limit = 50,
  }) {
    final uid = _requireUid();
    final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
    final query = _db
        .ref('economyLedger/$uid')
        .orderByChild('createdAt')
        .limitToLast(safeLimit);

    return query.onValue.map((event) {
      final value = event.snapshot.value;

      if (value is! Map) {
        return const <EconomyLedgerEntry>[];
      }

      final rows = <EconomyLedgerEntry>[];

      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        final txId = entry.key.toString();
        rows.add(
          EconomyLedgerEntry.fromMap(
            txId,
            Map<String, dynamic>.from(entry.value as Map),
          ),
        );
      }

      rows.sort(
        (a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0),
      );

      return List<EconomyLedgerEntry>.unmodifiable(rows);
    });
  }

  static Stream<Map<String, EconomyInventoryItem>> watchInventory() {
    final uid = _requireUid();

    return _db.ref('inventory/$uid').onValue.map((event) {
      final value = event.snapshot.value;

      if (value is! Map) {
        return const <String, EconomyInventoryItem>{};
      }

      final rows = <String, EconomyInventoryItem>{};

      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        final itemId = entry.key.toString();
        rows[itemId] = EconomyInventoryItem.fromMap(
          itemId,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }

      return Map<String, EconomyInventoryItem>.unmodifiable(rows);
    });
  }

  static String achievementClaimId(String achievementId) =>
      'achievement__$achievementId';

  static String _requireUid() {
    final uid = AuthService.uid;

    if (!AuthService.isGoogleAccount || uid == null) {
      throw StateError(
        'Coin bakiyesi için Google hesabına bağlı profil gerekli.',
      );
    }

    return uid;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
