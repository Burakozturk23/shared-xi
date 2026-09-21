import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/rewarded_ad_models.dart';
import 'ads_consent_service.dart';

abstract interface class LoadedRewardedAd {
  Future<bool> show(
    RewardedAdTicket? ticket, {
    required void Function() onStarted,
  });
  Future<void> dispose();
}

abstract interface class RewardedAdsPlayer {
  bool get supported;
  Future<bool> get testMode;
  Future<LoadedRewardedAd> load();
}

class AdMobRewardedAdsPlayer implements RewardedAdsPlayer {
  static Future<Map<String, dynamic>>? _config;
  static Future<void>? _initialization;
  static Future<Map<String, dynamic>> get config => _config ??= rootBundle
      .loadString('assets/config/admob.json')
      .then((text) => rewardMap(jsonDecode(text)));
  @override
  bool get supported => AdsConsentService.supported;
  Future<String> get _unit async {
    final c = await config;
    final key = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iosRewardedUnitId'
        : 'androidRewardedUnitId';
    final value = c[key]?.toString() ?? '';
    if (!RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(value)) {
      throw StateError('Reklam ayarları henüz hazır değil.');
    }
    return value;
  }

  @override
  Future<bool> get testMode async =>
      (await _unit).startsWith('ca-app-pub-3940256099942544/');
  static Future<void> _initialize() async {
    final c = await config;
    final ids = (c['testDeviceIds'] as List? ?? const [])
        .map((v) => v.toString())
        .toList();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: kReleaseMode ? null : ids),
    );
    await MobileAds.instance.initialize();
  }

  @override
  Future<LoadedRewardedAd> load() async {
    if (!await AdsConsentService.ensureCanRequestAds()) {
      throw StateError(
        'Gizlilik tercihlerine göre şu anda reklam yüklenemiyor.',
      );
    }
    _initialization ??= _initialize().catchError((Object e) {
      _initialization = null;
      throw e;
    });
    await _initialization;
    final done = Completer<LoadedRewardedAd>();
    final unit = await _unit;
    final timer = Timer(const Duration(seconds: 25), () {
      if (!done.isCompleted) {
        done.completeError(
          StateError('Reklam yüklenemedi. Daha sonra tekrar dene.'),
        );
      }
    });
    unawaited(
      RewardedAd.load(
        adUnitId: unit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (done.isCompleted) {
              ad.dispose();
            } else {
              done.complete(_AdMobLoadedAd(ad, unit));
            }
          },
          onAdFailedToLoad: (_) {
            if (!done.isCompleted) {
              done.completeError(
                StateError('Şu anda reklam yok. Oyuna devam edebilirsin.'),
              );
            }
          },
        ),
      ).catchError((Object e) {
        if (!done.isCompleted) done.completeError(e);
      }),
    );
    try {
      return await done.future;
    } finally {
      timer.cancel();
    }
  }
}

class _AdMobLoadedAd implements LoadedRewardedAd {
  _AdMobLoadedAd(this.ad, this.unit);
  final RewardedAd ad;
  final String unit;
  bool _disposed = false;
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await ad.dispose();
  }

  @override
  Future<bool> show(
    RewardedAdTicket? ticket, {
    required void Function() onStarted,
  }) async {
    if (ticket != null) {
      if (ticket.unitId != unit) {
        throw StateError('Reklam ayarları güncellendi. Uygulamayı yeniden aç.');
      }
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(
          userId: ticket.userId,
          customData: ticket.id,
        ),
      );
    }
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onStarted(),
      onAdDismissedFullScreenContent: (_) {
        if (!done.isCompleted) done.complete(earned);
        unawaited(dispose());
      },
      onAdFailedToShowFullScreenContent: (_, _) {
        if (!done.isCompleted) {
          done.completeError(
            StateError('Reklam açılamadı. Tekrar deneyebilirsin.'),
          );
        }
        unawaited(dispose());
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        earned = true;
      },
    );
    return done.future;
  }
}
