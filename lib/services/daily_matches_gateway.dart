import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'rewarded_ads_player.dart';
import 'story_support_service.dart';

abstract interface class DailyMatchesGateway {
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]);
  Future<void> watch(String placement, {String? key});
}

class FirebaseDailyMatchesGateway implements DailyMatchesGateway {
  final RewardedAdsPlayer player;
  FirebaseDailyMatchesGateway({RewardedAdsPlayer? player})
    : player = player ?? AdMobRewardedAdsPlayer();
  String? _uid;
  final _support = StorySupportService(useCallable: 'playDailyMatch', loadCallable: 'getDailyMatches',
    watchPlacement: 'daily_match_hint');
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> input,
  ) async {
    final user = await AuthService.ensureGuestSignedIn().timeout(const Duration(seconds: 20));
    if (_uid != null && _uid != user.uid)
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    _uid = user.uid;
    final result =
        await FirebaseFunctions.instanceFor(
              app: Firebase.app(),
              region: 'europe-west1',
            )
            .httpsCallable(
              name,
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 20),
              ),
            )
            .call({
              ...input,
              'platform': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android',
            });
    if (AuthService.uid != _uid)
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    return rewardMap(result.data);
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (action == 'status' || input['boostId'] != null) {
      final user = await AuthService.ensureGuestSignedIn().timeout(const Duration(seconds: 20));
      if (_uid != null && _uid != user.uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
      _uid = user.uid;
      if (action == 'status') return _support.load('daily_match', 'daily_match');
      return _support.use({...input, 'mode': 'daily_match', 'targetId': 'daily_match'});
    }
    return _call(action == 'start' ? 'startDailyMatch' : 'playDailyMatch', input);
  }

  @override
  Future<void> watch(String placement, {String? key}) async {
    if (placement == 'daily_match_hint') {
      await _support.watch({'key': key, 'boostId': 'boost_basic'}); return;
    }
    final status = await _call('getRewardedAdStatus', {});
    if (status['enabled'] != true)
      throw StateError(
        'Reklam bonusları şu anda kapalı. Reklamsız devam edebilirsin.',
      );
    final pro = status['pro'] == true;
    if ((status['remaining'] as num? ?? 0) <= 0)
      throw StateError('Günlük 2 bonus hakkını kullandın. Yarın yenilenir.');
    if (!pro &&
        (!player.supported ||
            await player.testMode ||
            status['testingOnly'] == true)) {
      throw StateError(
        'Ödüllü reklam bağlantısı henüz hazır değil. Oyununa reklamsız devam edebilirsin.',
      );
    }
    LoadedRewardedAd? loaded;
    RewardedAdTicket? ticket;
    var shown = false;
    try {
      // Load before reserving a ticket: no-fill or consent refusal consumes no bonus.
      if (!pro) loaded = await player.load();
      final random = Random.secure();
      final requestId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final prepared = await _call('prepareRewardedAd', {
        'placement': placement,
        'requestId': requestId,
        'context': {if (key != null) 'key': key},
      });
      ticket = RewardedAdTicket.fromMap(
        rewardMap(prepared['ticket']),
        userId: prepared['userId']?.toString() ?? '',
      );
      if (prepared['pro'] == true) return;
      final completed = await loaded!.show(
        ticket,
        onStarted: () => shown = true,
      );
      if (!completed) {
        await _call('cancelRewardedAd', {'ticketId': ticket.id});
        throw StateError('Reklam tamamlanmadı. Bonus hakkın kullanılmadı.');
      }
      for (var i = 0; i < 12; i++) {
        final result = await _call('getRewardedAdStatus', {
          'ticketId': ticket.id,
        });
        final t = rewardMap(result['ticket']);
        if (t['status'] == 'credited') return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      throw StateError(
        'Reklam doğrulanıyor. Biraz sonra yenile; bonusun sunucuda saklanıyor.',
      );
    } catch (_) {
      if (ticket != null && !shown && !pro) {
        try {
          await _call('cancelRewardedAd', {'ticketId': ticket.id});
        } catch (_) {}
      }
      rethrow;
    } finally {
      await loaded?.dispose();
    }
  }
}
