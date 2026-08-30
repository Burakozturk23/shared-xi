import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production telemetry bootstrap.
///
/// Normal debug builds keep telemetry collection disabled.
/// For a one-off local verification use:
///   --dart-define=LINKBALL_TELEMETRY_DEBUG=true
///
/// To send the dedicated non-fatal/Analytics smoke marker as well:
///   --dart-define=LINKBALL_TELEMETRY_SMOKE=true
class TelemetryService {
  TelemetryService._();

  static const bool _debugTelemetry = bool.fromEnvironment(
    'LINKBALL_TELEMETRY_DEBUG',
    defaultValue: false,
  );

  static const bool _smokeTest = bool.fromEnvironment(
    'LINKBALL_TELEMETRY_SMOKE',
    defaultValue: false,
  );

  static bool get _supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!_supportedPlatform) {
      return;
    }

    final enabled = kReleaseMode || _debugTelemetry;

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);

    if (!enabled) {
      debugPrint(
        '[Telemetry] disabled for debug build '
        '(use LINKBALL_TELEMETRY_DEBUG=true to verify locally)',
      );
      return;
    }

    FlutterError.onError = (details) {
      if (!kReleaseMode) {
        FlutterError.presentError(details);
      }
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: true,
      );
      return true;
    };

    await FirebaseAnalytics.instance.logAppOpen();

    debugPrint(
      '[Telemetry] Crashlytics + Analytics enabled '
      '(release=$kReleaseMode)',
    );

    if (_smokeTest) {
      await FirebaseCrashlytics.instance.recordError(
        StateError('Linkball STEP 07A telemetry smoke test'),
        StackTrace.current,
        reason: 'STEP 07A non-fatal verification',
        fatal: false,
      );

      await FirebaseAnalytics.instance.logEvent(
        name: 'telemetry_smoke',
        parameters: <String, Object>{
          'step': '07a',
          'runtime': 'flutter',
        },
      );

      debugPrint(
        '[Telemetry] STEP 07A smoke event submitted',
      );
    }
  }
}
