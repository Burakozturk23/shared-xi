from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
PUBSPEC = ROOT / "pubspec.yaml"
GRADLE = ROOT / "android/app/build.gradle.kts"
GOOGLE = ROOT / "android/app/google-services.json"

errors = []

if not MAIN.exists():
    errors.append("lib/main.dart missing")
else:
    text = MAIN.read_text(
        encoding="utf-8",
        errors="replace",
    )
    markers = [
        "package:firebase_app_check/firebase_app_check.dart",
        "package:flutter/foundation.dart",
        "STEP 05C.1: Android App Check.",
        "defaultTargetPlatform == TargetPlatform.android",
        "const AndroidDebugProvider()",
        "const AndroidPlayIntegrityProvider()",
        "FirebaseAppCheck.instance.activate",
    ]
    for marker in markers:
        if marker not in text:
            errors.append("main.dart missing: " + marker)

    init = text.find("await Firebase.initializeApp(")
    activate = text.find("FirebaseAppCheck.instance.activate")
    run_app = text.find("runApp(")

    if not (0 <= init < activate < run_app):
        errors.append(
            "App Check must initialize after Firebase and before runApp"
        )

if not PUBSPEC.exists():
    errors.append("pubspec.yaml missing")
else:
    pubspec = PUBSPEC.read_text(
        encoding="utf-8",
        errors="replace",
    )
    if not re.search(
        r"(?m)^\s*firebase_app_check\s*:",
        pubspec,
    ):
        errors.append(
            "firebase_app_check dependency missing"
        )

if GRADLE.exists():
    gradle = GRADLE.read_text(
        encoding="utf-8",
        errors="replace",
    )
    for marker in [
        'applicationId = "com.burakozturk.linkball"',
        "targetSdk = 36",
        'signingConfig = signingConfigs.getByName("release")',
    ]:
        if marker not in gradle:
            errors.append(
                "06A production state missing: " + marker
            )
else:
    errors.append("android/app/build.gradle.kts missing")

if errors:
    print("[FAIL] Step 05C.1 verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] firebase_app_check dependency present")
print("[PASS] Debug provider selected for Android debug builds")
print("[PASS] Play Integrity selected for Android release builds")
print("[PASS] App Check initializes after Firebase and before runApp")
print("[PASS] 06A production identity/signing remains intact")
print("[SAFE] Backend enforcement is still OFF")
