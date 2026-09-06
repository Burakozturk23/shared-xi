from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / ".github/workflows/linkball-ci.yml"

errors = []

if not WF.exists():
    errors.append("workflow file missing")
else:
    text = WF.read_text(encoding="utf-8", errors="replace")

    required = [
        "actions/checkout@v4",
        "actions/setup-java@v4",
        "subosito/flutter-action@v2",
        "flutter pub get",
        "flutter analyze --no-fatal-warnings --no-fatal-infos lib test",
        "flutter test --reporter expanded",
        "flutter build apk --debug",
        "actions/setup-node@v4",
        "working-directory: functions",
        "npm ci",
        "npm run lint",
        "permissions:",
        "contents: read",
    ]

    for marker in required:
        if marker not in text:
            errors.append("workflow missing: " + marker)

    # Guard against accidentally putting real local secrets into workflow.
    suspicious = [
        "storePassword=",
        "keyPassword=",
        "AIza",
        "BEGIN PRIVATE KEY",
        "firebase_token",
    ]
    for marker in suspicious:
        if marker.lower() in text.lower():
            errors.append("possible secret literal in workflow: " + marker)

if errors:
    print("[FAIL] STEP 07B.2 workflow verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] CI runs flutter pub get")
print("[PASS] CI runs flutter analyze")
print("[PASS] CI runs flutter test")
print("[PASS] CI compiles Android debug APK")
print("[PASS] CI runs Functions npm ci + lint")
print("[PASS] Workflow has read-only repository permission")
print("[PASS] No obvious secret literals detected")
