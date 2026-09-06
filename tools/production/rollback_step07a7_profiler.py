from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

paths = [
    ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart",
    ROOT / "lib/services/database_service.dart",
]

restored = 0
for path in paths:
    bak = path.with_suffix(path.suffix + ".step07a7.bak")
    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
        restored += 1

print(f"[INFO] Restored files: {restored}")
