import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/achievement_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class AchievementService {
  AchievementService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
      );

  static Future<int> syncMyAchievements() async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError(
        'Rozet ilerlemesini korumak için Google hesabı gerekli.',
      );
    }

    final callable = _functions.httpsCallable('syncMyAchievements');
    final response = await callable.call();
    final data = _map(response.data);

    if (data['ok'] != true) {
      throw StateError('Rozet ilerlemesi eşitlenemedi.');
    }

    return _int(data['unlockedCount']);
  }

  static Stream<Map<String, AchievementProgress>> watchProgress() {
    final uid = _requireUid();

    return _db.ref('achievementProgress/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <String, AchievementProgress>{};

      final rows = <String, AchievementProgress>{};
      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        final id = entry.key.toString();
        rows[id] = AchievementProgress.fromMap(
          id,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }

      return Map<String, AchievementProgress>.unmodifiable(rows);
    });
  }

  static Stream<Map<String, UserAchievement>> watchUnlocked() {
    final uid = _requireUid();

    return _db.ref('userAchievements/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <String, UserAchievement>{};

      final rows = <String, UserAchievement>{};
      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        final id = entry.key.toString();
        rows[id] = UserAchievement.fromMap(
          id,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }

      return Map<String, UserAchievement>.unmodifiable(rows);
    });
  }

  static Future<Map<String, AchievementProgress>> fetchProgress() async {
    final uid = _requireUid();
    final snap = await _db.ref('achievementProgress/$uid').get();

    if (!snap.exists || snap.value is! Map) {
      return const <String, AchievementProgress>{};
    }

    final rows = <String, AchievementProgress>{};
    final value = snap.value as Map;

    for (final entry in value.entries) {
      if (entry.value is! Map) continue;

      final id = entry.key.toString();
      rows[id] = AchievementProgress.fromMap(
        id,
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    return Map<String, AchievementProgress>.unmodifiable(rows);
  }

  static String _requireUid() {
    final uid = AuthService.uid;

    if (!AuthService.isGoogleAccount || uid == null) {
      throw StateError(
        'Rozet ilerlemesi için Google hesabına bağlı profil gerekli.',
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
