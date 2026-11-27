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
  LocalDailyFootballerStore({this.userId, this.currentUser});
  final String? userId;
  final String? Function()? currentUser;
  String get scopedKey => userId == null ? key : '$key.user.$userId';
  void _check() {
    if (currentUser != null && userId != currentUser!()) throw StateError('Hesap değişti. Ekranı yeniden aç.');
  }
  static const key = 'linkball.dailyFootballer.round.v1';
  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance(); _check();
    final scoped = prefs.getString(scopedKey);
    if (scoped != null || userId == null) return scoped;
    final owner = prefs.getString('$key.migratedOwner'); final old = prefs.getString(key);
    if (old == null || owner != null && owner != userId) return null;
    if (!await prefs.setString('$key.migratedOwner', userId!)) throw StateError('Kayıt taşınamadı.');
    _check();
    if (!await prefs.setString(scopedKey, old)) throw StateError('Kayıt taşınamadı.');
    _check(); return old;
  }
  @override
  Future<void> write(String value) async {
    final prefs = await SharedPreferences.getInstance(); _check();
    if (!await prefs.setString(scopedKey, value)) {
      throw StateError('İlerlemen kaydedilemedi. Tekrar dene.');
    }
    _check();
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
