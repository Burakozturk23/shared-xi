from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STREAK = ROOT / "lib/controllers/streak_controller.dart"

PLAYER_IMPORT = "import '../models/player.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2k2.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not STREAK.exists():
        raise SystemExit(f"[FAIL] Eksik: {STREAK}")

    original = STREAK.read_text(encoding="utf-8")
    text = original

    # 04.2K introduced explicit Player type usage in Runtime V3 Streak.
    # Some repository revisions did not import player.dart directly.
    if PLAYER_IMPORT not in text:
        anchors = [
            "import '../models/match_entity.dart';",
            "import '../models/streak_state.dart';",
            "import '../models/club.dart';",
        ]

        inserted = False
        for anchor in anchors:
            if anchor in text:
                text = text.replace(
                    anchor,
                    anchor + "\n" + PLAYER_IMPORT,
                    1,
                )
                inserted = True
                break

        if not inserted:
            # Final safe fallback: insert before first non-dart package/local import
            lines = text.splitlines()
            insert_at = None
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    insert_at = i + 1
            if insert_at is None:
                raise RuntimeError(
                    "Player import icin import bolumu bulunamadi."
                )
            lines.insert(insert_at, PLAYER_IMPORT)
            text = "\n".join(lines) + ("\n" if original.endswith("\n") else "")

    # Only validate what is actually necessary for this repair.
    if PLAYER_IMPORT not in text:
        raise RuntimeError("Player import eklenemedi.")

    # Confirm this is the 04.2K Streak file, without requiring exact generic syntax.
    runtime_markers = [
        "_nextRoundRuntime",
        "[HybridV3] Streak SQLite",
    ]
    missing_runtime = [m for m in runtime_markers if m not in text]
    if missing_runtime:
        raise RuntimeError(
            f"04.2K Streak runtime marker eksik: {missing_runtime}"
        )

    if text == original:
        print("[PASS] Player import zaten mevcut.")
        print("[INFO] flutter analyze gercek derleme kontrolunu yapacak.")
        return

    backup(STREAK)
    STREAK.write_text(text, encoding="utf-8")

    print("[FIX] streak_controller.dart -> ../models/player.dart import eklendi.")
    print("[OK] Step 04.2K.2 hotfix applied.")

if __name__ == "__main__":
    main()
