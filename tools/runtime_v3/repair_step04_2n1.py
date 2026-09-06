from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ODD = ROOT / "lib/controllers/odd_club_controller.dart"
OLD_BACKUP = ODD.with_suffix(ODD.suffix + ".step04_2n.bak")
PARTIAL_BACKUP = ODD.with_suffix(ODD.suffix + ".step04_2n1.partial.bak")

FINAL_MARKERS = [
    "_runtimeClubIdsByPlayer",
    "_effectiveHighScoreKey",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "realCount >= 3",
    "_initializeLegacy",
    "_clubIdsForPlayer(player)",
    "[HybridV3] OddClub SQLite",
]

LEGACY_MARKERS = [
    "p.peakMarketValue >= 40000000",
    "_pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));",
    "final realIds = player.clubs.toSet().intersection(poolClubIds).toList()",
]

def is_fully_migrated(text: str) -> bool:
    return all(m in text for m in FINAL_MARKERS)

def looks_legacy(text: str) -> bool:
    return all(m in text for m in LEGACY_MARKERS)

def git_head_source() -> str | None:
    try:
        result = subprocess.run(
            [
                "git",
                "show",
                "HEAD:lib/controllers/odd_club_controller.dart",
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
    if not ODD.exists():
        raise SystemExit(f"[FAIL] Eksik: {ODD}")

    current = ODD.read_text(encoding="utf-8")

    if is_fully_migrated(current):
        print("[PASS] Odd Club zaten tam 04.2N migration durumunda.")
        return

    if not PARTIAL_BACKUP.exists():
        shutil.copy2(ODD, PARTIAL_BACKUP)
        print(
            "[SAFE] Kismi mevcut dosya saklandi: "
            f"{PARTIAL_BACKUP.name}"
        )

    baseline: str | None = None
    source_label = ""

    # Best source: backup created by the first 04.2N write, if it is truly legacy.
    if OLD_BACKUP.exists():
        candidate = OLD_BACKUP.read_text(encoding="utf-8")
        if looks_legacy(candidate):
            baseline = candidate
            source_label = OLD_BACKUP.name

    # Fallback: tracked repository version.
    if baseline is None:
        candidate = git_head_source()
        if candidate is not None:
            baseline = candidate
            source_label = "git HEAD:lib/controllers/odd_club_controller.dart"

    if baseline is None:
        raise RuntimeError(
            "Temiz legacy Odd Club tabani bulunamadi. "
            "Ne step04_2n.bak ne de git HEAD uygun. "
            "odd_club_controller.dart dosyasini gonder."
        )

    ODD.write_text(baseline, encoding="utf-8")
    print(f"[RESTORE] Temiz taban yuklendi: {source_label}")
    print("[READY] Corrected 04.2N installer yeniden calisabilir.")

if __name__ == "__main__":
    main()
