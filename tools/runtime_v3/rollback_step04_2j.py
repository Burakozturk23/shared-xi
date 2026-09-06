from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
for rel in [
    "lib/controllers/higher_lower_controller.dart",
    "lib/models/higher_lower_state.dart",
    "lib/screens/higher_lower_page.dart",
    "lib/screens/higher_lower_mode_selection_page.dart",
]:
    p = ROOT / rel
    bak = p.with_suffix(p.suffix + ".step04_2j.bak")
    if bak.exists():
        shutil.copy2(bak, p)
        print(f"[RESTORED] {rel}")
    else:
        print(f"[SKIP] backup yok: {rel}")
