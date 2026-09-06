from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

PUBSPEC = ROOT / "pubspec.yaml"
LOCK = ROOT / "pubspec.lock"
SETTINGS = ROOT / "android/settings.gradle.kts"
APP_GRADLE = ROOT / "android/app/build.gradle.kts"
MAIN = ROOT / "lib/main.dart"
SERVICE = ROOT / "lib/services/telemetry_service.dart"

EXPECTED = {
    "firebase_core": "4.13.0",
    "firebase_auth": "6.5.7",
    "firebase_app_check": "0.4.6",
    "firebase_crashlytics": "5.2.7",
    "firebase_analytics": "12.4.6",
}

errors = []

def locked_versions():
    values = {}
    if not LOCK.exists():
        return values

    lines = LOCK.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines()

    current = None

    for line in lines:
        match = re.match(
            r"^  ([A-Za-z0-9_]+):\s*$",
            line,
        )
        if match:
            current = match.group(1)
            continue

        if current in EXPECTED:
            match = re.match(
                r'^\s+version:\s+"?([^"]+)"?\s*$',
                line,
            )
            if match:
                values[current] = match.group(1)
                current = None

    return values

values = locked_versions()

for package, expected in EXPECTED.items():
    actual = values.get(package)
    if actual != expected:
        errors.append(
            f"{package}: expected lock {expected}, got {actual}"
        )

settings = SETTINGS.read_text(
    encoding="utf-8",
    errors="replace",
)

for marker in [
    'id("com.google.gms.google-services") version "4.5.0" apply false',
    'id("com.google.firebase.crashlytics") version "3.0.8" apply false',
]:
    if marker not in settings:
        errors.append("settings.gradle.kts missing: " + marker)

app_gradle = APP_GRADLE.read_text(
    encoding="utf-8",
    errors="replace",
)

for marker in [
    'id("com.google.gms.google-services")',
    'id("com.google.firebase.crashlytics")',
    'applicationId = "com.burakozturk.linkball"',
    "targetSdk = 36",
    'signingConfig = signingConfigs.getByName("release")',
]:
    if marker not in app_gradle:
        errors.append("build.gradle.kts missing: " + marker)

if not SERVICE.exists():
    errors.append("telemetry_service.dart missing")
else:
    service = SERVICE.read_text(
        encoding="utf-8",
        errors="replace",
    )
    for marker in [
        "FirebaseCrashlytics.instance",
        "FirebaseAnalytics.instance",
        "setCrashlyticsCollectionEnabled",
        "setAnalyticsCollectionEnabled",
        "PlatformDispatcher.instance.onError",
        "recordFlutterFatalError",
        "LINKBALL_TELEMETRY_DEBUG",
        "LINKBALL_TELEMETRY_SMOKE",
        "telemetry_smoke",
    ]:
        if marker not in service:
            errors.append("TelemetryService missing: " + marker)

main = MAIN.read_text(
    encoding="utf-8",
    errors="replace",
)

if "await TelemetryService.initialize();" not in main:
    errors.append("main.dart telemetry initialize missing")

telemetry_index = main.find("await TelemetryService.initialize();")
run_app_index = main.find("runApp(")

if not (
    telemetry_index >= 0
    and run_app_index >= 0
    and telemetry_index < run_app_index
):
    errors.append("Telemetry must initialize before runApp")

if errors:
    print("[FAIL] STEP 07A verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] FlutterFire release train pinned")
print("[PASS] Crashlytics Gradle plugin configured")
print("[PASS] Google Services Gradle plugin is 4.5.0")
print("[PASS] Crashlytics global Flutter + async error handlers configured")
print("[PASS] Analytics collection configured")
print("[PASS] Debug collection remains opt-in")
print("[PASS] 06A applicationId/API36/release signing intact")
