from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
PUBSPEC = ROOT / "pubspec.yaml"
FINGERPRINTS = ROOT / "reports/production/06a/upload_key_fingerprints.txt"
REPORT = ROOT / "reports/production/05c"
REPORT.mkdir(parents=True, exist_ok=True)

PACKAGE = "com.burakozturk.linkball"

errors = []

if not MAIN.exists():
    errors.append("lib/main.dart missing")
else:
    text = MAIN.read_text(encoding="utf-8", errors="replace")
    for marker in [
        "firebase_app_check",
        "FirebaseAppCheck.instance.activate",
        "AndroidDebugProvider",
        "AndroidPlayIntegrityProvider",
    ]:
        if marker not in text:
            errors.append("05C.1 marker missing: " + marker)

if not PUBSPEC.exists():
    errors.append("pubspec.yaml missing")
else:
    pubspec = PUBSPEC.read_text(encoding="utf-8", errors="replace")
    if not re.search(r"(?m)^\s*firebase_app_check\s*:", pubspec):
        errors.append("firebase_app_check dependency missing")

sha256_lines = []
if FINGERPRINTS.exists():
    for line in FINGERPRINTS.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        if "SHA256:" in line.upper():
            sha256_lines.append(line.strip())
else:
    errors.append(
        "reports/production/06a/upload_key_fingerprints.txt missing"
    )

if errors:
    print("[FAIL] STEP 05C.2 local preflight")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

summary = [
    "LINKBALL STEP 05C.2 — CONSOLE PREP",
    "",
    f"Android package: {PACKAGE}",
    "Firebase project: sharedix",
    "",
    "UPLOAD certificate SHA-256:",
]
summary.extend("  " + line for line in sha256_lines)
summary.extend([
    "",
    "IMPORTANT:",
    "This is the local UPLOAD certificate.",
    "For Google Play production / internal testing, also use the",
    "Google Play APP SIGNING certificate SHA-256 from Play Console.",
    "",
    "Do not enable App Check enforcement yet.",
])

text = "\n".join(summary) + "\n"
(REPORT / "05c2_console_prep.txt").write_text(
    text,
    encoding="utf-8",
    newline="\n",
)

print(text)
print("[PASS] 05C.2 local preflight ready.")
