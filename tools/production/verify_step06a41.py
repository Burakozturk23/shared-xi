from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"

GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"
GRADLE = ROOT / "android/app/build.gradle.kts"

errors = []

if not GOOGLE.exists():
    errors.append("google-services.json missing")
else:
    try:
        data = json.loads(GOOGLE.read_text(encoding="utf-8"))
        matching_app_ids = []
        packages = []

        for client in data.get("client") or []:
            info = client.get("client_info") or {}
            android = info.get("android_client_info") or {}
            package = android.get("package_name")
            if package:
                packages.append(str(package))
            if package == PACKAGE:
                matching_app_ids.append(
                    str(info.get("mobilesdk_app_id") or "")
                )

        if PACKAGE not in packages:
            errors.append(
                "google-services package mismatch: "
                + ", ".join(packages)
            )

        if matching_app_ids:
            options = OPTIONS.read_text(
                encoding="utf-8",
                errors="replace",
            )
            if f"appId: '{matching_app_ids[0]}'" not in options:
                errors.append(
                    "firebase_options.dart Android appId mismatch"
                )
    except Exception as exc:
        errors.append("google-services parse failed: " + str(exc))

if GRADLE.exists():
    gradle = GRADLE.read_text(encoding="utf-8", errors="replace")
    for marker in [
        'applicationId = "com.burakozturk.linkball"',
        'namespace = "com.burakozturk.linkball"',
        "compileSdk = 36",
        "targetSdk = 36",
        'signingConfig = signingConfigs.getByName("release")',
    ]:
        if marker not in gradle:
            errors.append("Gradle missing: " + marker)
else:
    errors.append("build.gradle.kts missing")

for rel in [
    "android/key.properties",
    "android/upload-keystore.jks",
]:
    if not (ROOT / rel).exists():
        errors.append("Signing missing: " + rel)

if errors:
    print("[FAIL] Step 06A.4.1 verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Firebase package matches com.burakozturk.linkball")
print("[PASS] firebase_options.dart matches Firebase Android appId")
print("[PASS] Android identity/API36/release signing still intact")
print("[OK] STEP 06A.4.1 PASS")
