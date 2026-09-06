from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
FILES = [
    ROOT / "lib/main.dart",
    ROOT / "lib/screens/welcome_page.dart",
]

restored = 0
for path in FILES:
    bak = path.with_suffix(path.suffix + ".step07a91.bak")
    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
        restored += 1

print("[INFO] Restored:", restored, "/", len(FILES))
if restored != len(FILES):
    raise SystemExit("[FAIL] STEP 07A.9.1 rollback incomplete.")
