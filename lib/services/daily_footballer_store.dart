import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_footballer.dart';
import 'rewarded_ads_player.dart';

abstract interface class DailyFootballerStore {
  Future<String?> read();
  Future<void> write(String value);
}

class LocalDailyFootballerStore implements DailyFootballerStore {
  static const key = 'linkball.dailyFootballer.round.v1';
  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('İlerlemen kaydedilemedi. Tekrar dene.');
    }
  }
}

Future<DailyFootballerCatalog> loadDailyFootballers() async => DailyFootballerCatalog.fromJson(
  jsonDecode(await rootBundle.loadString('assets/data/daily_footballer_catalog.json')) as Map<String, dynamic>);

/// Local practice benefit only: no coins, rank, season XP or server entitlement.
/// The SDK's earned callback must fire before a hint/attempt can be saved.
Future<bool> watchDailyFootballerAd({RewardedAdsPlayer? player}) async {
  final ads = player ?? AdMobRewardedAdsPlayer();
  if (!ads.supported || (kReleaseMode && await ads.testMode)) {
    throw StateError('Ödüllü reklam şu anda kullanılamıyor. Daha sonra tekrar dene.');
  }
  final loaded = await ads.load();
  try { return await loaded.show(null, onStarted: () {}); }
  finally { await loaded.dispose(); }
}
