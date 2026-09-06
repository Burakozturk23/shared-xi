import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/welcome_page.dart';
import 'services/cloud_bootstrap.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupWatch = Stopwatch()..start();

  // STEP 08D.7Q.2: do not block Welcome's first paint on Dart-side Firebase.
  // Firebase Core + App Check + telemetry start immediately after the first
  // rendered frame. AuthService joins the same concurrency-safe bootstrap if
  // the user enters an online/auth-required mode before background warmup ends.
  runApp(const SharedXIApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint(
      '[Startup] Welcome first frame '
      '${startupWatch.elapsedMilliseconds}ms',
    );

    unawaited(
      CloudBootstrap.ensureInitialized(startupWatch: startupWatch).catchError(
        (Object error, StackTrace stackTrace) {
          debugPrint(
            '[CloudBootstrap] deferred bootstrap failed: '
            '$error\n$stackTrace',
          );
        },
      ),
    );
  });
}

class SharedXIApp extends StatelessWidget {
  const SharedXIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Linkball',
      theme: AppTheme.darkTheme,
      home: const WelcomePage(),
    );
  }
}
