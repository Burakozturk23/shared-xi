from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[2]
FILES = [
    'lib/repositories/repository.dart',
    'lib/main.dart',
    'lib/screens/welcome_page.dart',
    'lib/services/runtime_v3/runtime_v3_flags.dart',
    'lib/services/runtime_v3/runtime_v3_platform_io.dart',
]
restored = 0
for rel in FILES:
    path = ROOT / rel
    bak = path.with_suffix(path.suffix + '.step07a8.bak')
    if bak.exists():
        shutil.copy2(bak, path)
        print('[RESTORED]', rel)
        restored += 1
print('[INFO] Restored:', restored, '/', len(FILES))
if restored != len(FILES):
    raise SystemExit('[FAIL] Some STEP 07A.8 backups were missing.')
