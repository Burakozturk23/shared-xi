from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RANDOM = ROOT / "lib/controllers/random_grid_controller.dart"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2f1.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not RANDOM.exists():
        raise SystemExit(f"[FAIL] Eksik: {RANDOM}")

    original = RANDOM.read_text(encoding="utf-8")
    text = original

    # 1) SearchService.suggestions expects List<Player>, while 04.2F used an Iterable.
    # Restrict the replacement to the suggestions call.
    suggestions_pattern = re.compile(
        r"(suggestions\s*=\s*SearchService\.suggestions\(\s*"
        r"players:\s*)source(\s*,)",
        re.S,
    )
    text, suggestions_count = suggestions_pattern.subn(
        r"\1source.toList()\2",
        text,
        count=1,
    )

    # 2) 04.2F legacy-wrapper extraction accidentally started at the named
    # parameter "{" instead of the method-body "{", leaving the signature tail
    # inside _placeAtAnchorLegacy.
    malformed_patterns = [
        (
            "  }) {required Club rowClub, required Club colClub}) {",
            "  }) {",
        ),
        (
            "  }) { required Club rowClub, required Club colClub}) {",
            "  }) {",
        ),
    ]
    malformed_count = 0
    for old, new in malformed_patterns:
        if old in text:
            text = text.replace(old, new, 1)
            malformed_count += 1
            break

    # Tolerant regex fallback for local whitespace differences.
    if malformed_count == 0:
        regex = re.compile(
            r"(\s*\}\)\s*\{)\s*required\s+Club\s+rowClub\s*,\s*"
            r"required\s+Club\s+colClub\s*\}\)\s*\{",
            re.S,
        )
        text, malformed_count = regex.subn(r"\1", text, count=1)

    # Idempotency: if already fixed, both counts may be zero. Validate final state.
    if "players: source," in text:
        raise RuntimeError(
            "Iterable -> List fix uygulanamadi: `players: source,` hala mevcut."
        )

    bad_fragments = [
        "{required Club rowClub, required Club colClub}) {",
        "{ required Club rowClub, required Club colClub}) {",
    ]
    if any(fragment in text for fragment in bad_fragments):
        raise RuntimeError(
            "placeAtAnchor legacy signature bozuklugu hala mevcut."
        )

    required_markers = [
        "players: source.toList()",
        "void _placeAtAnchorLegacy(",
        "_generatePairRuntime",
        "_pairAnswerIds",
        "playerPool: 'grid_answer'",
        "_primePairCache(newRows, newCols)",
        "_cachedPairContains(row, col, player.id)",
    ]
    missing = [m for m in required_markers if m not in text]
    if missing:
        raise RuntimeError(f"04.2F markers eksik: {missing}")

    # A few structural sanity checks around the repaired legacy method.
    legacy_start = text.find("  void _placeAtAnchorLegacy(")
    submit_start = text.find(
        "  /// Köşegen dışı", legacy_start
    )
    if legacy_start < 0 or submit_start < 0:
        raise RuntimeError("Legacy placeAtAnchor method boundary bulunamadi")

    legacy_block = text[legacy_start:submit_start]
    if legacy_block.count("required Club rowClub") != 1:
        raise RuntimeError(
            "Legacy method icinde rowClub parametresi birden fazla/eksik."
        )
    if legacy_block.count("required Club colClub") != 1:
        raise RuntimeError(
            "Legacy method icinde colClub parametresi birden fazla/eksik."
        )

    if text == original:
        print("[PASS] 04.2F.1 duzeltmeleri zaten uygulanmis.")
        return

    backup(RANDOM)
    RANDOM.write_text(text, encoding="utf-8")

    print("[FIX] Iterable<Player> -> List<Player> duzeltildi.")
    print("[FIX] _placeAtAnchorLegacy method imzasi duzeltildi.")
    print("[OK] random_grid_controller.dart repaired.")

if __name__ == "__main__":
    main()
