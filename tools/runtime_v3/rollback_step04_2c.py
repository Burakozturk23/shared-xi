from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/grid_controller.dart"
bak = p.with_suffix(p.suffix + ".step04_2c.bak")

if bak.exists():
    shutil.copy2(bak, p)
    print("[RESTORED] lib/controllers/grid_controller.dart")
else:
    print("[SKIP] backup bulunamadi")
