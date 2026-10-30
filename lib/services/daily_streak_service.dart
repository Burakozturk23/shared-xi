import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/daily_streak.dart';
import 'cloud_bootstrap.dart';

class DailyStreakService {
  DailyStreakService._();

  static Future<DailyStreak> fetch() async {
    await CloudBootstrap.ensureInitialized();
    final response = await FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: 'europe-west1',
    ).httpsCallable('getDailyStreak').call();
    final data = response.data;
    if (data is! Map || data['ok'] != true) {
      throw StateError('Seri yüklenemedi.');
    }
    return DailyStreak.fromMap(Map<String, dynamic>.from(data));
  }
}
