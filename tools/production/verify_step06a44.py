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
    matches = []
    packages = []

    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        pkg = android.get("package_name")
        if pkg:
            packages.append(str(pkg))
        if pkg == PACKAGE:
            matches.append(str(info.get("mobilesdk_app_id") or ""))

    if PACKAGE not in packages:
        errors.append("Firebase package mismatch: " + ", ".join(packages))

    if matches:
        opts = options.read_text(encoding="utf-8", errors="replace")
        if f"appId: '{matches[0]}'" not in opts:
            errors.append("firebase_options Android appId mismatch")
except Exception as exc:
    errors.append("Firebase config parse failed: " + str(exc))

if gradle.exists():
    g = gradle.read_text(encoding="utf-8", errors="replace")
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
    print("[FAIL] 06A.4.4 verification")
    for e in errors:
        print(" -", e)
    raise SystemExit(1)

print("[PASS] Firebase package exact match")
print("[PASS] Firebase Android appId exact match")
print("[PASS] API 36 + production release signing intact")
print("[OK] STEP 06A.4.4 PASS")
