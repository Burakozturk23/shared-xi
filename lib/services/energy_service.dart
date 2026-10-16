import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'rewarded_ads_player.dart';

/// Prices, time, entitlements and receipts are always decided by the server.
class EnergyService {
  static const protocolVersion = 1;
  static String requestId() => List.generate(16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    final user = await AuthService.ensureGuestSignedIn();
    final result = await FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'europe-west1')
        .httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call({...input, 'clientVersion': protocolVersion,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'});
    if (AuthService.uid != user.uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    return rewardMap(result.data);
  }

  Future<Map<String, dynamic>> status() => call('getEnergyStatus');

  /// Call only once game data has loaded, immediately before entering play.
  /// Story request IDs survive app termination; the server owns permanent unlocks.
  Future<void> openStory(String mode, String unitId, {bool Function()? isActive}) async {
    if (kDebugMode && Firebase.apps.isEmpty) return; // injected/offline widget tests
    final user = await AuthService.ensureGuestSignedIn();
    final prefs = await SharedPreferences.getInstance();
    final key = 'energy.story.v1.${user.uid}.$mode.$unitId';
    var id = prefs.getString(key) ?? requestId();
    if (!await prefs.setString(key, id)) throw StateError('Oyun isteği kaydedilemedi.');
    Map<String, dynamic> result;
    try {
      result = await call('startEnergySession', {'mode': mode, 'unitId': unitId, 'requestId': id});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      // Expired holds can be replaced. The server still rejects obsolete clients.
      id = requestId(); await prefs.setString(key, id);
      result = await call('startEnergySession', {'mode': mode, 'unitId': unitId, 'requestId': id});
    }
    if (result['enabled'] == false || result['unlocked'] == true) return;
    final session = rewardMap(result['session']);
    if (isActive != null && !isActive()) {
      await call('cancelEnergySession', {'sessionId': session['id']});
      return;
    }
    await call('confirmEnergySession', {'sessionId': session['id']});
  }

  Future<Map<String, dynamic>> purchase(String packageId) async {
    final user = await AuthService.ensureGuestSignedIn();
    final prefs = await SharedPreferences.getInstance();
    final key = 'energy.purchase.v1.${user.uid}.$packageId';
    final id = prefs.getString(key) ?? requestId();
    if (!await prefs.setString(key, id)) throw StateError('İşlem cihazda kaydedilemedi. Tekrar dene.');
    final result = await call('purchaseEnergy', {'packageId': packageId, 'requestId': id});
    await prefs.remove(key);
    return result;
  }

  Future<void> watch(String placement, {required bool pro, Map<String, dynamic>? context}) async {
    final player = AdMobRewardedAdsPlayer();
    if (!pro && (!player.supported || await player.testMode)) {
      throw StateError('Ödüllü reklam henüz hazır değil. Bonus hakkın kullanılmadı.');
    }
    LoadedRewardedAd? loaded;
    RewardedAdTicket? ticket;
    var shown = false;
    try {
      if (!pro) loaded = await player.load();
      final prepared = await call('prepareRewardedAd', {'placement': placement, 'requestId': requestId(), if (context != null) 'context': context});
      ticket = RewardedAdTicket.fromMap(rewardMap(prepared['ticket']), userId: '${prepared['userId']}');
      if (prepared['pro'] == true) return;
      if (loaded == null) throw StateError('Üyelik bilgisi değişti. Tekrar dene.');
      final complete = await loaded.show(ticket, onStarted: () => shown = true);
      if (!complete) {
        await call('cancelRewardedAd', {'ticketId': ticket.id});
        throw StateError('Reklam tamamlanmadı. Bonus verilmedi.');
      }
      for (var i = 0; i < 12; i++) {
        final r = await call('getRewardedAdStatus', {'ticketId': ticket.id});
        if (rewardMap(r['ticket'])['status'] == 'credited') return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      throw StateError('Bonus doğrulanıyor. Biraz sonra yenile; hakkın sunucuda saklanıyor.');
    } catch (_) {
      if (ticket != null && !shown) {
        try { await call('cancelRewardedAd', {'ticketId': ticket.id}); } catch (_) {}
      }
      rethrow;
    } finally { await loaded?.dispose(); }
  }
}
