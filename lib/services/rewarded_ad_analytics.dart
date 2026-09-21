import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class RewardedAdAnalytics {
  static Future<void> coinEarned(
    String placement,
    int amount, {
    required bool pro,
  }) async {
    if (!kReleaseMode &&
        !const bool.fromEnvironment('LINKBALL_TELEMETRY_DEBUG')) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'coin_earned',
        parameters: {
          'source': pro ? 'pro_daily_bonus' : 'rewarded_coin',
          'amount': amount,
          'mode': placement,
        },
      );
    } catch (_) {}
  }

  static Future<void> log(
    String name,
    String placement, {
    int? reward,
    String? reason,
  }) async {
    if (!kReleaseMode &&
        !const bool.fromEnvironment('LINKBALL_TELEMETRY_DEBUG')) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: {
          'placement': placement,
          'reward': ?reward,
          'reason': ?reason,
        },
      );
    } catch (_) {
      // Telemetry never blocks watching, navigation or reward delivery.
    }
  }
}
