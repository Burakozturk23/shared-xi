from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/random_grid_controller.dart"
bak = p.with_suffix(p.suffix + ".step04_2f1.bak")

if bak.exists():
    shutil.copy2(bak, p)
    print("[RESTORED] random_grid_controller.dart pre-04.2F.1 state")
else:
    print("[SKIP] 04.2F.1 backup yok")
