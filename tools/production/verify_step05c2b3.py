from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "pubspec.lock"
MAIN = ROOT / "lib/main.dart"

EXPECTED = {
    "firebase_core": "4.13.0",
    "firebase_auth": "6.5.7",
    "firebase_app_check": "0.4.6",
}

def parse_lock():
    values = {}
    if not LOCK.exists():
        return values

    lines = LOCK.read_text(encoding="utf-8", errors="replace").splitlines()
    current = None

    for line in lines:
        m = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if m:
            current = m.group(1)
            continue

        if current in EXPECTED:
            m = re.match(r'^\s+version:\s+"?([^"]+)"?\s*$', line)
            if m:
                values[current] = m.group(1)
                current = None

    return values

errors = []
values = parse_lock()

for name, expected in EXPECTED.items():
    actual = values.get(name)
    if actual != expected:
        errors.append(f"{name}: expected {expected}, got {actual}")

if MAIN.exists():
    main = MAIN.read_text(encoding="utf-8", errors="replace")
    for marker in [
        "FirebaseAppCheck.instance.activate",
        "AndroidDebugProvider",
        "AndroidPlayIntegrityProvider",
    ]:
        if marker not in main:
            errors.append("05C.1 marker missing: " + marker)
else:
    errors.append("lib/main.dart missing")

if errors:
    print("[FAIL] Step 05C.2B.3 dependency verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] firebase_core      = 4.13.0")
print("[PASS] firebase_auth      = 6.5.7")
print("[PASS] firebase_app_check = 0.4.6")
print("[PASS] App Check client integration preserved")
