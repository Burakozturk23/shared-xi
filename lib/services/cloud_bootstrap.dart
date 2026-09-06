import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'telemetry_service.dart';

/// Concurrency-safe Firebase bootstrap for the V4 lazy-startup path.
///
/// STEP 08D.7Q.2 policy:
/// - Welcome must be allowed to paint before Dart waits on Firebase Core.
/// - The first post-frame callback starts this bootstrap in the background.
/// - Auth-required flows call [ensureInitialized] and join the same Future.
/// - Firebase Core is the only hard requirement. App Check / telemetry failures
///   are logged but do not make local/offline gameplay unusable.
class CloudBootstrap {
  CloudBootstrap._();

  static Future<void>? _initializeFuture;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;
  static bool get isInitializing => _initializeFuture != null && !_initialized;

  static Future<void> ensureInitialized({Stopwatch? startupWatch}) async {
    if (_initialized) return;

    final inFlight = _initializeFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initialize(startupWatch);
    _initializeFuture = future;

    try {
      await future;
      _initialized = true;
    } catch (_) {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
      rethrow;
    }
  }

  static Future<void> _initialize(Stopwatch? startupWatch) async {
    final totalWatch = Stopwatch()..start();

    final firebaseWatch = Stopwatch()..start();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseWatch.stop();

    debugPrint(
      '[CloudBootstrap] Firebase core ready '
      '${firebaseWatch.elapsedMilliseconds}ms '
      'bootstrap=${totalWatch.elapsedMilliseconds}ms '
      '${_startupSuffix(startupWatch)}',
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final appCheckWatch = Stopwatch()..start();
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kReleaseMode
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
        );
        appCheckWatch.stop();
        debugPrint(
          '[CloudBootstrap] AppCheck ready '
          '${appCheckWatch.elapsedMilliseconds}ms '
          'bootstrap=${totalWatch.elapsedMilliseconds}ms '
          '${_startupSuffix(startupWatch)}',
        );
      } catch (error, stackTrace) {
        appCheckWatch.stop();
        debugPrint(
          '[CloudBootstrap] AppCheck failed after '
          '${appCheckWatch.elapsedMilliseconds}ms: $error\n$stackTrace',
        );
      }
    }

    final telemetryWatch = Stopwatch()..start();
    try {
      await TelemetryService.initialize();
      telemetryWatch.stop();
      debugPrint(
        '[CloudBootstrap] Telemetry ready '
        '${telemetryWatch.elapsedMilliseconds}ms '
        'bootstrap=${totalWatch.elapsedMilliseconds}ms '
        '${_startupSuffix(startupWatch)}',
      );
    } catch (error, stackTrace) {
      telemetryWatch.stop();
      debugPrint(
        '[CloudBootstrap] Telemetry failed after '
        '${telemetryWatch.elapsedMilliseconds}ms: $error\n$stackTrace',
      );
    }
  }

  static String _startupSuffix(Stopwatch? startupWatch) {
    if (startupWatch == null) return '';
    return 'startup=${startupWatch.elapsedMilliseconds}ms';
  }
}
