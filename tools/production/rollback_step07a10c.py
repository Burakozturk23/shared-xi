from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
FILES = [
    ROOT / "lib/services/database_service.dart",
    ROOT / "pubspec.yaml",
]

restored = 0
for path in FILES:
    bak = path.with_suffix(path.suffix + ".step07a10c.bak")
    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
        restored += 1

print("[INFO] Restored:", restored, "/", len(FILES))
if restored != len(FILES):
    raise SystemExit("[FAIL] STEP 07A.10C rollback incomplete.")
