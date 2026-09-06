from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
errors = []
gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
for marker in [
    f'namespace = "{PACKAGE}"',
    f'applicationId = "{PACKAGE}"',
    "compileSdk = 36",
    "targetSdk = 36",
    'signingConfig = signingConfigs.getByName("release")',
]:
    if marker not in gradle:
        errors.append("Gradle missing: " + marker)
if 'signingConfig = signingConfigs.getByName("debug")' in gradle:
    errors.append("Release still debug-signed")

data = json.loads((ROOT / "android/app/google-services.json").read_text(encoding="utf-8"))
packages = []
for c in data.get("client") or []:
    info = c.get("client_info") or {}
    packages.append((info.get("android_client_info") or {}).get("package_name"))
if PACKAGE not in packages:
    errors.append("Firebase package mismatch")

for rel in ["android/key.properties", "android/upload-keystore.jks", "lib/firebase_options.dart"]:
    if not (ROOT / rel).exists():
        errors.append("Missing: " + rel)

if errors:
    print("[FAIL] 06A production preflight")
    for e in errors:
        print(" -", e)
    raise SystemExit(1)

print("[PASS] R01 candidate: applicationId", PACKAGE)
print("[PASS] R02 candidate: API 36")
print("[PASS] R03 candidate: real release signing configured")
print("[PASS] Firebase Android config matches production package")
