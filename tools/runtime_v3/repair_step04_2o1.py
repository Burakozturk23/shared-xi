from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "lib/controllers/guess_the_player_controller.dart"

OLD_BACKUP = CTRL.with_suffix(CTRL.suffix + ".step04_2o.bak")
PARTIAL_BACKUP = CTRL.with_suffix(
    CTRL.suffix + ".step04_2o1.partial.bak"
)

FINAL_MARKERS = [
    "_runtimeClubPool",
    "_runtimeAnswerPlayers",
    "_runtimeClubIdsByPlayer",
    "playersInPool('grid_answer')",
    "playerClubIdsForPool('grid_answer')",
    "_clubIdsForPlayer",
    "[HybridV3] GuessThePlayer SQLite",
]

LEGACY_MARKERS = [
    "final pool = chainClubPool",
    ".where((p) => p.clubs.contains(club.id))",
    "SearchService.findExactPlayer",
]

def is_full(text: str) -> bool:
    return all(marker in text for marker in FINAL_MARKERS)

def looks_legacy(text: str) -> bool:
    return all(marker in text for marker in LEGACY_MARKERS)

def git_head_source() -> str | None:
    try:
        result = subprocess.run(
            [
                "git",
                "show",
                "HEAD:lib/controllers/guess_the_player_controller.dart",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
    except Exception:
        return None

    if result.returncode != 0:
        return None

    text = result.stdout
    return text if looks_legacy(text) else None

def main() -> None:
    if not CTRL.exists():
        raise SystemExit(f"[FAIL] Eksik: {CTRL}")

    current = CTRL.read_text(encoding="utf-8")

    if is_full(current):
        print(
            "[PASS] Guess the Player zaten tam 04.2O "
            "migration durumunda."
        )
        return

    if not PARTIAL_BACKUP.exists():
        shutil.copy2(CTRL, PARTIAL_BACKUP)
        print(
            "[SAFE] Kismi mevcut dosya saklandi: "
            f"{PARTIAL_BACKUP.name}"
        )

    baseline: str | None = None
    source_label = ""

    if OLD_BACKUP.exists():
        candidate = OLD_BACKUP.read_text(encoding="utf-8")
        if looks_legacy(candidate):
            baseline = candidate
            source_label = OLD_BACKUP.name

    if baseline is None:
        candidate = git_head_source()
        if candidate is not None:
            baseline = candidate
            source_label = (
                "git HEAD:"
                "lib/controllers/guess_the_player_controller.dart"
            )

    if baseline is None:
        raise RuntimeError(
            "Temiz legacy Guess the Player tabani bulunamadi. "
            "Ne step04_2o.bak ne de git HEAD uygun. "
            "Bu durumda guess_the_player_controller.dart dosyasini gonder."
        )

    CTRL.write_text(baseline, encoding="utf-8")
    print(f"[RESTORE] Temiz taban yuklendi: {source_label}")
    print("[READY] 04.2O yeniden kurulabilir.")

if __name__ == "__main__":
    main()
