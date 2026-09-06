from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[2]
errors = []
for rel in ["android/key.properties", "android/upload-keystore.jks"]:
    if not (ROOT / rel).exists():
        errors.append("Missing: " + rel)
gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
if 'signingConfig = signingConfigs.getByName("release")' not in gradle:
    errors.append("Release signing config missing")
if 'signingConfig = signingConfigs.getByName("debug")' in gradle:
    errors.append("Debug release signing remains")
for rel in ["android/key.properties", "android/upload-keystore.jks"]:
    try:
        r = subprocess.run(["git", "check-ignore", "-q", rel], cwd=ROOT)
        if r.returncode != 0:
            errors.append("Git does not ignore: " + rel)
    except FileNotFoundError:
        pass
if errors:
    print("[FAIL] 06A.3")
    for e in errors:
        print(" -", e)
    raise SystemExit(1)
print("[PASS] 06A.3 upload signing files ready and ignored")
