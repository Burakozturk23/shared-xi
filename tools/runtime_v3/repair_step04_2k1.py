from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STREAK = ROOT / "lib/controllers/streak_controller.dart"

PLAYER_IMPORT = "import '../models/player.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2k1.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not STREAK.exists():
        raise SystemExit(f"[FAIL] Eksik: {STREAK}")

    original = STREAK.read_text(encoding="utf-8")
    text = original

    # This hotfix is intentionally tiny: 04.2K introduced explicit Player
    # generic/list usage in Streak. Some repo revisions did not previously
    # import the Player model directly.
    if PLAYER_IMPORT not in text:
        anchors = [
            "import '../models/match_entity.dart';",
            "import '../models/streak_state.dart';",
            "import '../models/club.dart';",
        ]

        inserted = False
        for anchor in anchors:
            if anchor in text:
                text = text.replace(anchor, anchor + "\n" + PLAYER_IMPORT, 1)
                inserted = True
                break

        if not inserted:
            raise RuntimeError(
                "Player import icin guvenli import anchor bulunamadi."
            )

    # Verify the actual 04.2K Player usages are present.
    required = [
        PLAYER_IMPORT,
        "final found = <Player>[];",
        "List<Player>",
    ]
    missing = [m for m in required if m not in text]
    if missing:
        raise RuntimeError(f"Beklenen Streak marker eksik: {missing}")

    if text == original:
        print("[PASS] Player import zaten mevcut.")
        return

    backup(STREAK)
    STREAK.write_text(text, encoding="utf-8")

    print("[FIX] streak_controller.dart -> Player import eklendi.")
    print("[OK] Step 04.2K.1 hotfix applied.")

if __name__ == "__main__":
    main()
