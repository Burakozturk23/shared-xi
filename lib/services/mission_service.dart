import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/mission_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class MissionService {
  MissionService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static Future<MissionProfile> fetch() async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final callable = _functions.httpsCallable('getMyMissions');
    final response = await callable.call();
    final data = _map(response.data);
    final rawProfile = data['profile'];

    if (data['ok'] != true || rawProfile is! Map) {
      throw StateError('Görevler yüklenemedi.');
    }

    return MissionProfile.fromMap(Map<String, dynamic>.from(rawProfile));
  }

  static Future<MissionClaimResult> claim(String missionId) async {
    await CloudBootstrap.ensureInitialized();
    _requireGoogleAccount();

    final callable = _functions.httpsCallable('claimMissionReward');
    final response = await callable.call(<String, dynamic>{
      'missionId': missionId,
    });
    final data = _map(response.data);
    final rawProfile = data['profile'];

    if (data['ok'] != true || rawProfile is! Map) {
      throw StateError('Görev ödülü alınamadı.');
    }

    return MissionClaimResult(
      granted: data['granted'] == true,
      alreadyClaimed: data['alreadyClaimed'] == true,
      amount: _int(data['amount']),
      walletCoins: _int(data['walletCoins']),
      missionId: data['missionId']?.toString() ?? missionId,
      periodKey: data['periodKey']?.toString() ?? '',
      profile: MissionProfile.fromMap(Map<String, dynamic>.from(rawProfile)),
    );
  }

  static Stream<MissionProfile> watch() async* {
    await CloudBootstrap.ensureInitialized();
    final uid = _requireGoogleAccount();

    yield await fetch();

    yield* _db.ref('missionProfiles/$uid').onValue.map((event) {
      final raw = event.snapshot.value;

      if (raw is! Map) {
        throw StateError('Görev bilgileri okunamadı.');
      }

      return MissionProfile.fromMap(Map<String, dynamic>.from(raw));
    });
  }

  static String _requireGoogleAccount() {
    final uid = AuthService.uid;

    if (!AuthService.isGoogleAccount || uid == null) {
      throw StateError(
        'Görev ilerlemesini ve ödülleri korumak için Google hesabı gerekli.',
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
