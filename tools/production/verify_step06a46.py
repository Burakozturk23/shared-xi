from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"

errors = []

google = ROOT / "android/app/google-services.json"
options = ROOT / "lib/firebase_options.dart"
gradle = ROOT / "android/app/build.gradle.kts"

try:
    data = json.loads(google.read_text(encoding="utf-8"))
    target_ids = []
    packages = []

    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        package = android.get("package_name")

        if package:
            packages.append(str(package))

        if package == PACKAGE:
            target_ids.append(
                str(info.get("mobilesdk_app_id") or "")
            )

    if PACKAGE not in packages:
        errors.append(
            "Firebase package mismatch: "
            + ", ".join(packages)
        )

    if len(target_ids) != 1 or not target_ids[0]:
        errors.append(
            "Expected exactly one production Firebase appId"
        )
    else:
        opts = options.read_text(
            encoding="utf-8",
            errors="replace",
        )
        if f"appId: '{target_ids[0]}'" not in opts:
            errors.append(
                "firebase_options Android appId mismatch"
            )

except Exception as exc:
    errors.append(
        "Firebase config parse failed: " + str(exc)
    )

if gradle.exists():
    g = gradle.read_text(
        encoding="utf-8",
        errors="replace",
    )

    for marker in [
        'applicationId = "com.burakozturk.linkball"',
        'namespace = "com.burakozturk.linkball"',
        "compileSdk = 36",
        "targetSdk = 36",
        'signingConfig = signingConfigs.getByName("release")',
    ]:
        if marker not in g:
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
    print("[FAIL] Step 06A.4.6 verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Production Firebase Android app registered")
print("[PASS] Firebase config exact package/appId match")
print("[PASS] API 36 + release signing intact")
print("[OK] STEP 06A.4.6 PASS")
