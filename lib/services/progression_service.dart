import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/progression_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class ProgressionService {
  ProgressionService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static Future<ProgressionProfile> fetch() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final callable = _functions.httpsCallable('getMyProgression');
    final response = await callable.call();
    final data = _map(response.data);
    final rawProfile = data['profile'];

    if (data['ok'] != true || rawProfile is! Map) {
      throw StateError('İlerleme bilgileri yüklenemedi.');
    }

    return ProgressionProfile.fromMap(Map<String, dynamic>.from(rawProfile));
  }

  static Future<DailyRewardClaimResult> claimDailyReward() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final callable = _functions.httpsCallable('claimDailyReward');
    final response = await callable.call();
    final data = _map(response.data);
    final rawProfile = data['profile'];

    if (data['ok'] != true || rawProfile is! Map) {
      throw StateError('Günlük ödül alınamadı.');
    }

    return DailyRewardClaimResult(
      granted: data['granted'] == true,
      alreadyClaimed: data['alreadyClaimed'] == true,
      amount: _int(data['amount']),
      xp: _int(data['xp']),
      dayIndex: _int(data['dayIndex'], fallback: 1),
      multiplier: _int(data['multiplier'], fallback: 1),
      streakProtected: data['streakProtected'] == true,
      walletCoins: _int(data['walletCoins']),
      profile: ProgressionProfile.fromMap(
        Map<String, dynamic>.from(rawProfile),
      ),
    );
  }

  static Stream<ProgressionProfile> watch() async* {
    await CloudBootstrap.ensureInitialized();
    final uid = _requireGoogleAccount();

    yield await fetch();

    yield* _db.ref('progressionProfiles/$uid').onValue.map((event) {
      final raw = event.snapshot.value;

      if (raw is! Map) {
        throw StateError('İlerleme bilgileri okunamadı.');
      }

      return ProgressionProfile.fromMap(Map<String, dynamic>.from(raw));
    });
  }

  static String _requireGoogleAccount() {
    final uid = AuthService.uid;

    if (!AuthService.isGoogleAccount || uid == null) {
      throw StateError(
        'İlerlemeyi ve ödülleri korumak için Google hesabı gerekli.',
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

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
