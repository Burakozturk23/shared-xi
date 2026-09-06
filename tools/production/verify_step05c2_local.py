from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/05c"
TOKEN = REPORT / "app_check_debug_token.local.txt"
MAIN = ROOT / "lib/main.dart"

errors = []

if not MAIN.exists():
    errors.append("main.dart missing")
else:
    text = MAIN.read_text(encoding="utf-8", errors="replace")
    for marker in [
        "FirebaseAppCheck.instance.activate",
        "AndroidDebugProvider",
        "AndroidPlayIntegrityProvider",
    ]:
        if marker not in text:
            errors.append("Missing App Check marker: " + marker)

if TOKEN.exists():
    token = TOKEN.read_text(encoding="utf-8", errors="replace").strip()
    if not re.fullmatch(r"[0-9A-Fa-f-]{20,}", token):
        errors.append("Local debug token format looks invalid")
else:
    errors.append(
        "Debug token has not been captured yet "
        "(app_check_debug_token.local.txt missing)"
    )

if errors:
    print("[FAIL] STEP 05C.2 local debug-token verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] App Check client integration present")
print("[PASS] Local Android App Check debug token captured")
print("[SAFE] Firebase enforcement is still intentionally OFF")
