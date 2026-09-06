from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEST = ROOT / "test/widget_test.dart"
WF = ROOT / ".github/workflows/linkball-ci.yml"

errors = []

if not TEST.exists():
    errors.append("test/widget_test.dart missing")
else:
    test = TEST.read_text(encoding="utf-8", errors="replace")

    for required in [
        "STEP 07B.2.2",
        "WelcomePage renders Linkball home navigation",
        "const MaterialApp(",
        "home: WelcomePage()",
        "find.text('LINKBALL')",
        "find.text('Ortak oyuncu evreni')",
        "find.text('HEMEN OYNA')",
        "find.byIcon(Icons.sports_soccer)",
    ]:
        if required not in test:
            errors.append("widget test missing: " + required)

    for forbidden in [
        "SHARED XI",
        "SharedXIApp launches and shows welcome screen",
        "pumpWidget(const SharedXIApp())",
    ]:
        if forbidden in test:
            errors.append("legacy/side-effect test remains: " + forbidden)

if not WF.exists():
    errors.append(".github/workflows/linkball-ci.yml missing")
else:
    wf = WF.read_text(encoding="utf-8", errors="replace")
    for required in [
        "flutter pub get",
        "flutter analyze --no-fatal-warnings --no-fatal-infos lib test",
        "flutter test --reporter expanded",
        "flutter build apk --debug",
        "working-directory: functions",
        "npm ci",
        "npm run lint",
        "contents: read",
    ]:
        if required not in wf:
            errors.append("CI workflow missing: " + required)

    for suspicious in [
        "storePassword=",
        "keyPassword=",
        "BEGIN PRIVATE KEY",
        "AIza",
    ]:
        if suspicious.lower() in wf.lower():
            errors.append("possible secret literal in workflow: " + suspicious)

if errors:
    print("[FAIL] STEP 07B.2.2 static verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Stale Shared XI assertion removed")
print("[PASS] WelcomePage test uses current LINKBALL contract")
print("[PASS] Widget test avoids RuntimeV3/Firebase startup side effects")
print("[PASS] CI analyze/test/debug-build gates installed")
print("[PASS] Functions lint gate installed")
print("[PASS] No obvious CI secret literals")
