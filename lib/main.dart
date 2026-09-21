import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/welcome_page.dart';
import 'screens/onboarding_page.dart';
import 'app/app_preferences.dart';
import 'app/app_feedback.dart';
import 'app/route_appearance.dart';
import 'services/cloud_bootstrap.dart';
import 'services/ads_consent_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupWatch = Stopwatch()..start();
  // Small local appearance preferences are resolved before the first frame;
  // Firebase and the player database remain outside this critical path.
  final preferences = await AppPreferences.load();
  AppFeedback.preferences = preferences;

  // STEP 08D.7Q.2: do not block Welcome's first paint on Dart-side Firebase.
  // Firebase Core + App Check + telemetry start immediately after the first
  // rendered frame. AuthService joins the same concurrency-safe bootstrap if
  // the user enters an online/auth-required mode before background warmup ends.
  runApp(SharedXIApp(preferences: preferences));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AdsConsentService.refresh());
    debugPrint(
      '[Startup] Welcome first frame '
      '${startupWatch.elapsedMilliseconds}ms',
    );

    unawaited(
      CloudBootstrap.ensureInitialized(startupWatch: startupWatch).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          '[CloudBootstrap] deferred bootstrap failed: '
          '$error\n$stackTrace',
        );
      }),
    );
  });
}

class SharedXIApp extends StatefulWidget {
  const SharedXIApp({super.key, required this.preferences});
  final AppPreferences preferences;
  @override
  State<SharedXIApp> createState() => _SharedXIAppState();
}

class _SharedXIAppState extends State<SharedXIApp> {
  final _appearance = RouteAppearanceObserver();
  late bool _showOnboarding;
  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.preferences.onboardingComplete;
  }

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PreferencesScope(
      preferences: widget.preferences,
      child: ListenableBuilder(
        listenable: widget.preferences,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Linkball',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.preferences.themeMode,
          // A Theme boundary keeps pre-17C mode routes readable in either app theme.
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: _appearance.legacy,
            builder: (context, legacy, _) => Theme(
              data: legacy ? AppTheme.legacyDarkTheme : Theme.of(context),
              child: child!,
            ),
          ),
          navigatorObservers: [_appearance],
          home: _showOnboarding
              ? OnboardingPage(
                  onComplete: () => setState(() => _showOnboarding = false),
                )
              : const WelcomePage(),
        ),
      ),
    );
  }
}
