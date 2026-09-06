from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
required = [
    f'namespace = "{PACKAGE}"',
    f'applicationId = "{PACKAGE}"',
    "compileSdk = 36",
    "targetSdk = 36",
    'create("release")',
    'signingConfig = signingConfigs.getByName("release")',
]
errors = [x for x in required if x not in gradle]
if 'signingConfig = signingConfigs.getByName("debug")' in gradle:
    errors.append("debug release signing remains")
main = ROOT / "android/app/src/main/kotlin/com/burakozturk/linkball/MainActivity.kt"
if not main.exists():
    errors.append("MainActivity new path missing")
if errors:
    print("[FAIL] 06A.1")
    for e in errors:
        print(" -", e)
    raise SystemExit(1)
print("[PASS] 06A.1 identity/API36/signing prep")
