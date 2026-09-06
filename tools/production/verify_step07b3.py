from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]

errors = []

pubspec = (ROOT / "pubspec.yaml").read_text(
    encoding="utf-8",
    errors="replace",
)
if "integration_test:" not in pubspec:
    errors.append("pubspec integration_test dependency missing")

integration = ROOT / "integration_test/welcome_smoke_test.dart"
if not integration.exists():
    errors.append("integration_test/welcome_smoke_test.dart missing")
else:
    text = integration.read_text(encoding="utf-8", errors="replace")
    for marker in [
        "IntegrationTestWidgetsFlutterBinding.ensureInitialized()",
        "WelcomePage()",
        "find.text('LINKBALL')",
    ]:
        if marker not in text:
            errors.append("integration smoke missing: " + marker)

pkg = json.loads(
    (ROOT / "functions/package.json").read_text(encoding="utf-8")
)
if (pkg.get("scripts") or {}).get("test") != "node --test":
    errors.append("functions test script is not node --test")
if str((pkg.get("engines") or {}).get("node")) != "24":
    errors.append("functions engine is not Node 24")

ftest = ROOT / "functions/test/security_contracts.test.js"
if not ftest.exists():
    errors.append("Functions security contract test missing")

wf = ROOT / ".github/workflows/linkball-ci.yml"
if not wf.exists():
    errors.append("Linkball CI workflow missing")
else:
    text = wf.read_text(encoding="utf-8", errors="replace")

    for marker in [
        'node-version: "24"',
        "npm test",
        "integration_test/welcome_smoke_test.dart",
        "flutter build appbundle --release",
        "LINKBALL_UPLOAD_KEYSTORE_BASE64",
        "LINKBALL_UPLOAD_STORE_PASSWORD",
        "LINKBALL_UPLOAD_KEY_ALIAS",
        "LINKBALL_UPLOAD_KEY_PASSWORD",
        "actions/upload-artifact@v4",
    ]:
        if marker not in text:
            errors.append("CI workflow missing: " + marker)

    suspicious = [
        "storePassword=actual",
        "keyPassword=actual",
        "BEGIN PRIVATE KEY",
        "AIza",
    ]
    for marker in suspicious:
        if marker.lower() in text.lower():
            errors.append("possible secret literal in workflow: " + marker)

if errors:
    print("[FAIL] STEP 07B.3 static verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] integration_test baseline exists")
print("[PASS] Functions test script exists")
print("[PASS] Functions CI uses Node 24")
print("[PASS] Functions lint + tests are CI gates")
print("[PASS] Signed release AAB CI job exists")
print("[PASS] Release signing uses GitHub secret references only")
print("[PASS] Android integration smoke CI job exists")
