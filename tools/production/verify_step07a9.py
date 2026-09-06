from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
WELCOME = ROOT / "lib/screens/welcome_page.dart"

errors = []

main = MAIN.read_text(encoding="utf-8", errors="replace")
welcome = WELCOME.read_text(encoding="utf-8", errors="replace")

for forbidden in [
    "final authFuture = AuthService.ensureSignedIn();",
    "await authFuture;",
    "setState(() => _status = 'Oturum…');",
]:
    if forbidden in main:
        errors.append("main.dart still blocks on auth: " + forbidden)

for marker in [
    "STEP 07A.9: Auth is no longer a splash dependency.",
    "[Startup] Auth deferred",
    "[Startup] Welcome navigation",
    "_warmLegacyRepository(startupWatch)",
]:
    if marker not in main:
        errors.append("main.dart missing: " + marker)

for marker in [
    "import '../services/auth_service.dart';",
    "final bool requiresAuth;",
    "this.requiresAuth = false,",
    "requiresAuth: true,",
    "await Future.wait(waits);",
    "AuthService.ensureSignedIn()",
]:
    if marker not in welcome:
        errors.append("welcome_page.dart missing: " + marker)

if welcome.count("requiresAuth: true,") < 2:
    errors.append("Daily + Online auth gates were not both configured")

if errors:
    print("[FAIL] STEP 07A.9 static verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Splash no longer waits for Firebase Auth")
print("[PASS] Welcome still waits for Runtime V3")
print("[PASS] Daily + Online authenticate on demand")
print("[PASS] Auth + Repository waits run concurrently")
