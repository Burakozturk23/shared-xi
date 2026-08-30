import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'services/telemetry_service.dart';
import 'theme/app_theme.dart';
import 'repositories/repository.dart';
import 'services/runtime_v3/runtime_v3_service.dart';
import 'screens/welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // STEP 05C.1: Android App Check.
  // Debug builds use the Firebase debug provider so local development remains usable.
  // Release builds use Play Integrity.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );
  }

  await TelemetryService.initialize();
  runApp(const SharedXIApp());
}

class SharedXIApp extends StatelessWidget {
  const SharedXIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Linkball',
      theme: AppTheme.darkTheme,
      home: const _BootstrapPage(),
    );
  }
}

class _BootstrapPage extends StatefulWidget {
  const _BootstrapPage();

  @override
  State<_BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<_BootstrapPage> {
  String _status = 'Veriler yükleniyor…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final startupWatch = Stopwatch()..start();

    try {
      setState(() {
        _error = null;
        _status = 'Hızlı veri motoru…';
      });

      // STEP 07A.8: keep legacy JSON outside the splash critical path.
      // Runtime V3 gets first priority. Auth runs in parallel. The large
      // legacy player JSON warms only after Welcome paints its first frame.
      // STEP 07A.9.2: Auth is deferred out of startup.
      // Daily/Online prepare Auth only when entered.

      await RuntimeV3Service.instance.initializeIfEnabled();
      debugPrint(
        '[Startup] RuntimeV3 ready '
        '${startupWatch.elapsedMilliseconds}ms '
        'status=${RuntimeV3Service.instance.status.name}',
      );

      debugPrint(
        '[Startup] Auth deferred ${startupWatch.elapsedMilliseconds}ms',
      );

      if (!mounted) return;

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomePage()));

      debugPrint(
        '[Startup] Welcome navigation '
        '${startupWatch.elapsedMilliseconds}ms',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 750),
            () => _warmLegacyRepository(startupWatch),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _warmLegacyRepository(Stopwatch startupWatch) async {
    try {
      await Repository.instance.initialize();

      debugPrint(
        '[Startup] Repository ready '
        '${startupWatch.elapsedMilliseconds}ms '
        'players=${Repository.instance.playerCount}',
      );

      await RuntimeV3Service.instance.runParityAudit(Repository.instance);
    } catch (e, st) {
      debugPrint('[Startup] Repository background warmup failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 56,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'LINKBALL',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 28),
              if (_error == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(color: AppTheme.hintColor),
                ),
              ] else ...[
                const Text(
                  'Yükleme başarısız',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dangerColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.hintColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _boot,
                  child: const Text('Tekrar dene'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
