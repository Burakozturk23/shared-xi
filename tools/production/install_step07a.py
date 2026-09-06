from __future__ import annotations

from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]

PUBSPEC = ROOT / "pubspec.yaml"
SETTINGS = ROOT / "android/settings.gradle.kts"
APP_GRADLE = ROOT / "android/app/build.gradle.kts"
MAIN = ROOT / "lib/main.dart"
SERVICE = ROOT / "lib/services/telemetry_service.dart"

VERSIONS = {
    "firebase_core": "4.13.0",
    "firebase_auth": "6.5.7",
    "firebase_app_check": "0.4.6",
    "firebase_crashlytics": "5.2.7",
    "firebase_analytics": "12.4.6",
}

CRASHLYTICS_GRADLE = "3.0.8"
GOOGLE_SERVICES = "4.5.0"

SERVICE_TEXT = r"""import 'dart:ui';

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
"""

def backup(path: Path) -> None:
    if not path.exists():
        return
    bak = path.with_suffix(path.suffix + ".step07a.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def write_lf(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def pin_pubspec(text: str) -> str:
    for package, version in VERSIONS.items():
        pattern = re.compile(
            rf"(?m)^(\s*){re.escape(package)}\s*:\s*[^\n]+$"
        )
        match = pattern.search(text)

        if match:
            indent = match.group(1)
            text = pattern.sub(
                f"{indent}{package}: {version}",
                text,
                count=1,
            )
            continue

        # Add under dependencies: when package is missing.
        dep = re.search(r"(?m)^dependencies:\s*$", text)
        if not dep:
            raise RuntimeError("pubspec.yaml dependencies: block not found")

        insert_at = dep.end()
        text = (
            text[:insert_at]
            + f"\n  {package}: {version}"
            + text[insert_at:]
        )

    return text

def patch_settings(text: str) -> str:
    # Firebase Crashlytics v3 requires google-services 4.4.1+.
    google_pattern = re.compile(
        r'id\("com\.google\.gms\.google-services"\)'
        r'\s+version(?:\s*=\s*|\s*\()\s*"[^"]+"'
        r'(?:\))?\s+apply false'
    )

    if google_pattern.search(text):
        text = google_pattern.sub(
            f'id("com.google.gms.google-services") '
            f'version "{GOOGLE_SERVICES}" apply false',
            text,
            count=1,
        )
    elif 'id("com.google.gms.google-services")' in text:
        # More permissive line replacement.
        text = re.sub(
            r'(?m)^\s*id\("com\.google\.gms\.google-services"\).*$',
            f'    id("com.google.gms.google-services") '
            f'version "{GOOGLE_SERVICES}" apply false',
            text,
            count=1,
        )
    else:
        raise RuntimeError(
            "google-services plugin declaration not found "
            "in android/settings.gradle.kts"
        )

    crash_line = (
        f'    id("com.google.firebase.crashlytics") '
        f'version "{CRASHLYTICS_GRADLE}" apply false'
    )

    if 'id("com.google.firebase.crashlytics")' not in text:
        google_line = re.search(
            r'(?m)^(\s*id\("com\.google\.gms\.google-services"\).*)$',
            text,
        )
        if not google_line:
            raise RuntimeError(
                "Could not locate google-services plugin line "
                "for Crashlytics insertion"
            )
        text = (
            text[:google_line.end()]
            + "\n"
            + crash_line
            + text[google_line.end():]
        )
    else:
        text = re.sub(
            r'(?m)^\s*id\("com\.google\.firebase\.crashlytics"\).*$',
            crash_line,
            text,
            count=1,
        )

    return text

def patch_app_gradle(text: str) -> str:
    if 'id("com.google.firebase.crashlytics")' in text:
        return text

    google_line = re.search(
        r'(?m)^(\s*)id\("com\.google\.gms\.google-services"\)\s*$',
        text,
    )

    if not google_line:
        raise RuntimeError(
            "App-level google-services plugin not found"
        )

    indent = google_line.group(1)
    insertion = (
        google_line.group(0)
        + "\n"
        + indent
        + 'id("com.google.firebase.crashlytics")'
    )

    return (
        text[:google_line.start()]
        + insertion
        + text[google_line.end():]
    )

def patch_main(text: str) -> str:
    import_line = "import 'services/telemetry_service.dart';"

    if import_line not in text:
        anchor = "import 'firebase_options.dart';"
        if anchor not in text:
            raise RuntimeError(
                "firebase_options.dart import anchor not found in main.dart"
            )
        text = text.replace(
            anchor,
            anchor + "\n" + import_line,
            1,
        )

    if "await TelemetryService.initialize();" not in text:
        run_index = text.find("runApp(")
        if run_index < 0:
            raise RuntimeError("runApp() not found in main.dart")

        line_start = text.rfind("\n", 0, run_index) + 1
        indent = re.match(r"\s*", text[line_start:run_index]).group(0)

        text = (
            text[:line_start]
            + indent
            + "await TelemetryService.initialize();\n"
            + text[line_start:]
        )

    return text

def main() -> None:
    for path in [PUBSPEC, SETTINGS, APP_GRADLE, MAIN]:
        if not path.exists():
            raise RuntimeError(
                f"Required file missing: {path.relative_to(ROOT)}"
            )

    for path in [PUBSPEC, SETTINGS, APP_GRADLE, MAIN]:
        backup(path)

    pubspec = pin_pubspec(
        PUBSPEC.read_text(
            encoding="utf-8",
            errors="replace",
        )
    )
    settings = patch_settings(
        SETTINGS.read_text(
            encoding="utf-8",
            errors="replace",
        )
    )
    app_gradle = patch_app_gradle(
        APP_GRADLE.read_text(
            encoding="utf-8",
            errors="replace",
        )
    )
    main_dart = patch_main(
        MAIN.read_text(
            encoding="utf-8",
            errors="replace",
        )
    )

    write_lf(PUBSPEC, pubspec)
    write_lf(SETTINGS, settings)
    write_lf(APP_GRADLE, app_gradle)
    write_lf(MAIN, main_dart)

    if SERVICE.exists():
        backup(SERVICE)
    write_lf(SERVICE, SERVICE_TEXT)

    print("[FIX] FlutterFire versions pinned to the stable 4.13 train.")
    print("[FIX] google-services Gradle plugin -> 4.5.0")
    print("[FIX] Crashlytics Gradle plugin -> 3.0.8")
    print("[FIX] Android app applies Crashlytics plugin.")
    print("[FIX] TelemetryService added.")
    print("[FIX] main.dart initializes telemetry before runApp.")
    print("[SAFE] Debug telemetry is OFF by default.")
    print("[SAFE] App Check enforcement is unchanged.")

if __name__ == "__main__":
    main()
