from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ODD = ROOT / "lib/controllers/odd_club_controller.dart"
PARTIAL_BACKUP = ODD.with_suffix(ODD.suffix + ".step04_2n1.partial.bak")

if PARTIAL_BACKUP.exists():
    shutil.copy2(PARTIAL_BACKUP, ODD)
    print("[RESTORED] 04.2N.1 oncesi kismi Odd Club dosyasi geri yuklendi.")
else:
    print("[SKIP] 04.2N.1 partial backup bulunamadi.")
