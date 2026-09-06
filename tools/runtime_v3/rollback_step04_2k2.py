from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/streak_controller.dart"
bak = p.with_suffix(p.suffix + ".step04_2k2.bak")

if bak.exists():
    shutil.copy2(bak, p)
    print("[RESTORED] streak_controller.dart pre-04.2K.2")
else:
    print("[SKIP] 04.2K.2 backup yok")
