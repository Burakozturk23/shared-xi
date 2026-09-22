import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';

abstract interface class RewardedAdsGateway {
  Future<RewardedAdStatus> status({String? ticketId});
  Future<RewardedAdTicket> prepare(String placement, String requestId);
  Future<void> cancel(String ticketId);
}

class FirebaseRewardedAdsGateway implements RewardedAdsGateway {
  String? _uid;
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> input,
  ) async {
    final user = await AuthService.ensureGuestSignedIn();
    if (_uid != null && user.uid != _uid) {
      throw StateError('Hesap değişti. Sonuç ekranını yeniden aç.');
    }
    _uid = user.uid;
    final response =
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
    if (FirebaseAuth.instance.currentUser?.uid != _uid) {
      throw StateError('Hesap değişti.');
    }
    final data = rewardMap(response.data);
    if (data['ok'] != true) throw StateError('Bonus bilgisi alınamadı.');
    return data;
  }

  @override
  Future<RewardedAdStatus> status({String? ticketId}) async =>
      RewardedAdStatus.fromMap(
        await _call('getRewardedAdStatus', {
          'ticketId': ?ticketId,
        }),
      );
  @override
  Future<RewardedAdTicket> prepare(String placement, String requestId) async {
    final data = await _call('prepareRewardedAd', {
      'placement': placement,
      'requestId': requestId,
    });
    return RewardedAdTicket.fromMap(
      rewardMap(data['ticket']),
      userId: data['userId']?.toString() ?? '',
    );
  }

  @override
  Future<void> cancel(String ticketId) async {
    await _call('cancelRewardedAd', {'ticketId': ticketId});
  }
}
