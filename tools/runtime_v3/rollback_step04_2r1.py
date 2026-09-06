from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "lib/controllers/mystery_player_controller.dart"
PARTIAL_BACKUP = CTRL.with_suffix(
    CTRL.suffix + ".step04_2r1.partial.bak"
)

if PARTIAL_BACKUP.exists():
    shutil.copy2(PARTIAL_BACKUP, CTRL)
    print(
        "[RESTORED] 04.2R.1 oncesi kismi Mystery Player "
        "dosyasi geri yuklendi."
    )
else:
    print("[SKIP] 04.2R.1 partial backup bulunamadi.")
