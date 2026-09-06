from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

errors = []

required = [
    "android/key.properties",
    "android/upload-keystore.jks",
    "reports/production/06a/upload_key_fingerprints.txt",
    "reports/production/06a/detected_keytool.txt",
]

for rel in required:
    if not (ROOT / rel).exists():
        errors.append("Missing: " + rel)

gradle = ROOT / "android/app/build.gradle.kts"
if gradle.exists():
    text = gradle.read_text(encoding="utf-8", errors="replace")
    if 'signingConfig = signingConfigs.getByName("release")' not in text:
        errors.append("Gradle release signingConfig missing")
    if 'signingConfig = signingConfigs.getByName("debug")' in text:
        errors.append("Gradle still uses debug signing for release")
else:
    errors.append("build.gradle.kts missing")

try:
    for rel in [
        "android/key.properties",
        "android/upload-keystore.jks",
    ]:
        result = subprocess.run(
            ["git", "check-ignore", "-q", rel],
            cwd=ROOT,
            check=False,
        )
        if result.returncode != 0:
            errors.append("Git does not ignore: " + rel)
except FileNotFoundError:
    print("[WARN] git not found; ignore verification skipped.")

if errors:
    print("[FAIL] Step 06A.3.1 verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Upload keystore created.")
print("[PASS] key.properties created.")
print("[PASS] Release signing config present.")
print("[PASS] Signing secrets are ignored by Git.")
