from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
FILES = [
    ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart",
    ROOT / "lib/services/database_service.dart",
]

restored = 0
for path in FILES:
    bak = path.with_suffix(path.suffix + ".step07a71.bak")
    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
        restored += 1

print("[INFO] Restored files:", restored)

if restored != len(FILES):
    raise SystemExit("[FAIL] Not all profiler source files were restored.")
