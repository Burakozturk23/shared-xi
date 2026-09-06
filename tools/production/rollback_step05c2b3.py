from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

for rel in ["pubspec.yaml", "pubspec.lock"]:
    p = ROOT / rel
    b = p.with_suffix(p.suffix + ".step05c2b3.bak")
    if b.exists():
        shutil.copy2(b, p)
        print("[RESTORED]", rel)

print("[INFO] Run flutter pub get after rollback.")
