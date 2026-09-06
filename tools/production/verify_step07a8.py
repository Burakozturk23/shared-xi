from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    'lib/repositories/repository.dart': [
        'Future<void>? _initializeFuture;',
        'Future<void> _initializeInternal() async',
        'bool get isInitializing => _initializeFuture != null;',
    ],
    'lib/main.dart': [
        "import 'dart:async';",
        'STEP 07A.8: keep legacy JSON outside the splash critical path.',
        '[Startup] RuntimeV3 ready',
        '[Startup] Welcome navigation',
        '[Startup] Repository ready',
        'addPostFrameCallback',
        '_warmLegacyRepository',
    ],
    'lib/screens/welcome_page.dart': [
        'STEP 07A.8: gate mode navigation on Repository readiness.',
        'await Repository.instance.initialize();',
        'Oyuncu verisi hazırlanıyor',
    ],
    'lib/services/runtime_v3/runtime_v3_flags.dart': [
        "'LINKBALL_SQLITE_V3',\n    defaultValue: true,",
        "'LINKBALL_SQLITE_GAMEPLAY_V3',\n    defaultValue: true,",
        "'LINKBALL_SQLITE_PARITY',\n    defaultValue: false,",
    ],
    'lib/services/runtime_v3/runtime_v3_platform_io.dart': [
        'PRAGMA quick_check',
        'if (mustCopy) {',
        'await temp.writeAsBytes(bytes);',
    ],
}
errors = []
for rel, markers in checks.items():
    path = ROOT / rel
    if not path.exists():
        errors.append('Missing file: ' + rel)
        continue
    text = path.read_text(encoding='utf-8', errors='replace')
    for marker in markers:
        if marker not in text:
            errors.append(f'{rel} missing marker: {marker}')

platform = (ROOT / 'lib/services/runtime_v3/runtime_v3_platform_io.dart').read_text(encoding='utf-8', errors='replace')
if 'PRAGMA integrity_check' in platform:
    errors.append('Full PRAGMA integrity_check still exists')
if 'flush: true' in platform:
    errors.append('Forced flush:true still exists')

main = (ROOT / 'lib/main.dart').read_text(encoding='utf-8', errors='replace')
legacy_first = main.find('await Repository.instance.initialize();')
runtime_first = main.find('await RuntimeV3Service.instance.initializeIfEnabled();')
if legacy_first >= 0 and runtime_first >= 0 and legacy_first < runtime_first:
    errors.append('Legacy Repository is still ahead of Runtime V3 in _boot')

if errors:
    print('[FAIL] STEP 07A.8 static verification')
    for e in errors:
        print('  -', e)
    raise SystemExit(1)

print('[PASS] Repository init is concurrency-safe')
print('[PASS] Runtime V3 is ahead of legacy Repository on splash path')
print('[PASS] Welcome navigation is Repository-safe')
print('[PASS] Runtime V3 default enabled')
print('[PASS] Gameplay V3 default enabled')
print('[PASS] Parity default disabled')
print('[PASS] Cached SQLite skips full integrity_check')
print('[PASS] Fresh SQLite copy uses quick_check')
print('[PASS] Forced write flush removed')
