from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
main=(ROOT/'lib/main.dart').read_text(encoding='utf-8',errors='replace')
welcome=(ROOT/'lib/screens/welcome_page.dart').read_text(encoding='utf-8',errors='replace')
errors=[]
for x in ['final authFuture = AuthService.ensureSignedIn();','await authFuture;','[Startup] Auth ready']:
    if x in main: errors.append('main.dart still has '+x)
for x in ['STEP 07A.9.2: Auth is deferred out of startup.','[Startup] RuntimeV3 ready','[Startup] Auth deferred','[Startup] Welcome navigation','_warmLegacyRepository']:
    if x not in main: errors.append('main.dart missing '+x)
for x in ["import '../services/auth_service.dart';",'final bool requiresAuth;','this.requiresAuth = false,','AuthService.ensureSignedIn()','await Future.wait(waits);']:
    if x not in welcome: errors.append('welcome_page.dart missing '+x)
if welcome.count('requiresAuth: true,')<2: errors.append('Daily + Online auth flags incomplete')
if errors:
    print('[FAIL] STEP 07A.9.2 static verification')
    [print('  -',e) for e in errors]
    raise SystemExit(1)
print('[PASS] Startup Auth dependency removed')
print('[PASS] Welcome navigation marker preserved')
print('[PASS] Runtime V3 still gates Welcome')
print('[PASS] Daily + Online authenticate on demand')
print('[PASS] Repository + Auth waits are concurrent')
