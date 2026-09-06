from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
main = (ROOT / "lib/main.dart").read_text(encoding="utf-8", errors="replace")
welcome = (ROOT / "lib/screens/welcome_page.dart").read_text(encoding="utf-8", errors="replace")

errors = []

for forbidden in [
    "final authFuture = AuthService.ensureSignedIn();",
    "await authFuture;",
    "[Startup] Auth ready",
    "setState(() => _status = 'Oturum…');",
]:
    if forbidden in main:
        errors.append("main.dart still has startup Auth dependency: " + forbidden)

for marker in [
    "STEP 07A.9.1: Auth is deferred out of startup.",
    "[Startup] Auth deferred",
    "[Startup] RuntimeV3 ready",
    "[Startup] Welcome navigation",
]:
    if marker not in main:
        errors.append("main.dart missing: " + marker)

for marker in [
    "import '../services/auth_service.dart';",
    "final bool requiresAuth;",
    "this.requiresAuth = false,",
    "AuthService.ensureSignedIn()",
    "await Future.wait(waits);",
]:
    if marker not in welcome:
        errors.append("welcome_page.dart missing: " + marker)

if welcome.count("requiresAuth: true,") < 2:
    errors.append("Daily + Online auth flags incomplete")

if errors:
    print("[FAIL] STEP 07A.9.1 static verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Splash no longer waits for Firebase Auth")
print("[PASS] Runtime V3 still gates Welcome")
print("[PASS] Daily + Online authenticate on demand")
print("[PASS] Repository + Auth waits are concurrent")
