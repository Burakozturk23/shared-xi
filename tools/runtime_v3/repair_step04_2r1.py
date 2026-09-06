from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "lib/controllers/mystery_player_controller.dart"

OLD_BACKUP = CTRL.with_suffix(CTRL.suffix + ".step04_2r.bak")
PARTIAL_BACKUP = CTRL.with_suffix(
    CTRL.suffix + ".step04_2r1.partial.bak"
)

FINAL_MARKERS = [
    "_runtimePlayers",
    "_runtimeClubIdsByPlayer",
    "_runtimeFactsByPlayer",
    "_runtimeClubNameById",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "playerFactsForPool('normal_v3')",
    "_startRoundRuntime",
    "_runtimeStatsHint",
    "[HybridV3] MysteryPlayer SQLite",
]

LEGACY_MARKERS = [
    "void _startRound({required bool keepSession}) {",
    "String _valueBucket(double value) {",
    "List<String> _leagueNamesFor(Player p) {",
    "String? _starTeammateName(Player target) {",
    "List<MysteryHint> _buildHints(Player p) {",
    "void skip() {",
]

def is_full(text: str) -> bool:
    return all(marker in text for marker in FINAL_MARKERS)

def looks_clean_legacy(text: str) -> bool:
    # Clean enough for the 04.2R installer:
    # required legacy shape exists, and none of 04.2R's final runtime markers
    # are already embedded.
    return (
        all(marker in text for marker in LEGACY_MARKERS)
        and not any(marker in text for marker in FINAL_MARKERS)
    )

def git_head_source() -> str | None:
    try:
        result = subprocess.run(
            [
                "git",
                "show",
                "HEAD:lib/controllers/mystery_player_controller.dart",
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
    return text if looks_clean_legacy(text) else None

def main() -> None:
    if not CTRL.exists():
        raise SystemExit(f"[FAIL] Eksik: {CTRL}")

    current = CTRL.read_text(encoding="utf-8")

    if is_full(current):
        print(
            "[PASS] Mystery Player zaten tam 04.2R migration "
            "durumunda."
        )
        return

    # Never discard the partial file.
    if not PARTIAL_BACKUP.exists():
        shutil.copy2(CTRL, PARTIAL_BACKUP)
        print(
            "[SAFE] Kismi mevcut dosya saklandi: "
            f"{PARTIAL_BACKUP.name}"
        )

    baseline: str | None = None
    source_label = ""

    # Prefer the backup created by the original 04.2R installer.
    if OLD_BACKUP.exists():
        candidate = OLD_BACKUP.read_text(encoding="utf-8")
        if looks_clean_legacy(candidate):
            baseline = candidate
            source_label = OLD_BACKUP.name

    # Fallback to repository HEAD.
    if baseline is None:
        candidate = git_head_source()
        if candidate is not None:
            baseline = candidate
            source_label = (
                "git HEAD:"
                "lib/controllers/mystery_player_controller.dart"
            )

    if baseline is None:
        raise RuntimeError(
            "Temiz 04.2R oncesi Mystery Player tabani bulunamadi. "
            "Ne step04_2r.bak ne de git HEAD uygun. "
            "Bu durumda mystery_player_controller.dart dosyasini gonder."
        )

    CTRL.write_text(baseline, encoding="utf-8")
    print(f"[RESTORE] Temiz taban yuklendi: {source_label}")
    print("[READY] 04.2R temiz taban uzerinde yeniden kurulabilir.")

if __name__ == "__main__":
    main()
