from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
for rel in [
    "lib/services/match_pair_generator.dart",
    "lib/controllers/match_pair_controller.dart",
]:
    p = ROOT / rel
    bak = p.with_suffix(p.suffix + ".step04_2s.bak")
    if bak.exists():
        shutil.copy2(bak, p)
        print(f"[RESTORED] {rel}")
    else:
        print(f"[SKIP] backup yok: {rel}")
