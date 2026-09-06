from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[2]
for rel in [
    "lib/controllers/daily_challenge_controller.dart",
    "lib/controllers/endless_controller.dart",
]:
    p = ROOT / rel
    bak = p.with_suffix(p.suffix + ".step04_2m.bak")
    if bak.exists():
        shutil.copy2(bak, p)
        print(f"[RESTORED] {rel}")
