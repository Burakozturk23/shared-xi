#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "assets" / "runtime" / "linkball_game_data_v4.sqlite"
MANIFEST = ROOT / "assets" / "runtime" / "linkball_game_data_v4_manifest.json"

EXPECTED = {
    "players": 30_135,
    "clubs": 4_311,
    "transfers": 33_994,  # reviewed v4-2026-09-28.1 adds one event
    "players_with_clubs": 30_135,
    "search_players": 30_135,
    "coaches": 5_275,
    "pruned_clubs": 3_091,
    "pruned_transfer_rows": 13_250,
}
EXPECTED_COMPILER_STEP = "08D.8A"
EXPECTED_PRUNE_STEP = "08D.7O"
EXPECTED_PRUNE_POLICY = "transfer_only_development_v1"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def fail(message: str) -> int:
    print(f"[FAIL] {message}")
    return 1


def scalar(
    con: sqlite3.Connection,
    sql: str,
    params: tuple[object, ...] = (),
) -> int:
    return int(con.execute(sql, params).fetchone()[0])


def main() -> int:
    print("===== 08D.8A V4 PRODUCTION FREEZE VERIFY =====")

    if not DB.exists():
        return fail(f"DB missing: {DB}")
    if not MANIFEST.exists():
        return fail(f"Manifest missing: {MANIFEST}")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    expansions = manifest.get("expansions", [])
    additions = sum(e.get("newPlayers", 0) for e in expansions)
    reviews = manifest.get("reviewedAdditions", [])
    reviewed_players = sum(r["newPlayers"] for r in reviews)
    reviewed_links = sum(r["newLinks"] for r in reviews)
    expansion_links = sum(e.get("newLinks", 0) for e in expansions)
    if not isinstance(additions, int) or additions < 0:
        return fail("Invalid reviewed expansion counts")
    if not isinstance(expansion_links, int) or expansion_links < 0:
        return fail("Invalid reviewed expansion link counts")
    for key in ("players", "players_with_clubs", "search_players"):
        EXPECTED[key] = 30_135 + additions + reviewed_players
    con = sqlite3.connect(str(DB))
    try:
        con.execute("PRAGMA foreign_keys=ON")

        quick = con.execute("PRAGMA quick_check").fetchone()[0]
        fk = con.execute("PRAGMA foreign_key_check").fetchall()
        if quick != "ok":
            return fail(f"quick_check={quick!r}")
        if fk:
            return fail(f"foreign_key_check has {len(fk)} rows: {fk[:5]!r}")

        actual = {
            "players": scalar(con, "SELECT COUNT(*) FROM players"),
            "clubs": scalar(con, "SELECT COUNT(*) FROM clubs"),
            "transfers": scalar(con, "SELECT COUNT(*) FROM transfers"),
            "players_with_clubs": scalar(
                con, "SELECT COUNT(DISTINCT player_id) FROM player_clubs"
            ),
            "search_players": scalar(
                con, "SELECT COUNT(DISTINCT player_id) FROM player_search_terms"
            ),
            "roster_expansion_players": scalar(
                con, "SELECT COUNT(*) FROM players WHERE source='worldcup26-roster'"
            ),
            "roster_expansion_links": scalar(
                con, "SELECT COUNT(*) FROM player_clubs WHERE source='roster:worldcup26:2026-09-29.2'"
            ),
            "coaches": scalar(con, "SELECT COUNT(*) FROM coaches"),
            "shadow_players": scalar(
                con, "SELECT COUNT(*) FROM players WHERE id IN (34601, 111961)"
            ),
        }

        for key in (
            "players", "clubs", "transfers", "players_with_clubs",
            "search_players", "coaches"
        ):
            if actual[key] != EXPECTED[key]:
                return fail(
                    f"{key}: {actual[key]:,} != frozen {EXPECTED[key]:,}"
                )
        if actual["shadow_players"] != 0:
            return fail(f"shadow players leaked: {actual['shadow_players']}")
        if actual["roster_expansion_players"] != additions:
            return fail(
                "roster expansion players: "
                f"{actual['roster_expansion_players']:,} != recorded {additions:,}"
            )
        if actual["roster_expansion_links"] != expansion_links:
            return fail(
                "roster expansion links: "
                f"{actual['roster_expansion_links']:,} != recorded {expansion_links:,}"
            )

        if scalar(con, "SELECT COUNT(*) FROM players WHERE source='v4'") != 30_135:
            return fail("Original player universe changed")
        if scalar(con, "SELECT COUNT(*) FROM players WHERE source='reviewed-player'") != reviewed_players:
            return fail("Reviewed player count mismatch")
        reviewed_sources = {
            "v4-2026-09-30.1": "reviewed:notable:2026-09-30",
            "v4-2026-10-01.1": "reviewed:legend-portraits:2026-10-01",
            "v4-2026-10-01.2": "reviewed:season-portraits:2026-10-01",
            "v4-2026-10-04.1": "reviewed:portrait-audit:2026-10-04",
        }
        actual_reviewed_links = 0
        for review in reviews:
            source = reviewed_sources.get(review["id"])
            if source is None:
                return fail(f"Unknown reviewed link source for {review['id']}")
            actual_reviewed_links += int(
                con.execute(
                    "SELECT COUNT(*) FROM player_clubs WHERE source=?",
                    (source,),
                ).fetchone()[0]
            )
        if actual_reviewed_links != reviewed_links:
            return fail(
                f"Reviewed link count mismatch: {actual_reviewed_links} != {reviewed_links}"
            )

        metadata = dict(con.execute("SELECT key, value FROM metadata"))
        if metadata.get("compiler_step") != EXPECTED_COMPILER_STEP:
            return fail(
                "metadata compiler_step="
                f"{metadata.get('compiler_step')!r}, expected {EXPECTED_COMPILER_STEP!r}"
            )
        if metadata.get("club_prune_step") != EXPECTED_PRUNE_STEP:
            return fail("metadata club_prune_step mismatch")
        if metadata.get("club_prune_policy") != EXPECTED_PRUNE_POLICY:
            return fail("metadata club_prune_policy mismatch")
        if int(metadata.get("club_count", "-1")) != EXPECTED["clubs"]:
            return fail("metadata club_count is not final/pruned count")
        if int(metadata.get("transfer_rows", "-1")) != EXPECTED["transfers"]:
            return fail("metadata transfer_rows is not final/pruned count")
        if int(metadata.get("pruned_transfer_only_development_clubs", "-1")) != EXPECTED["pruned_clubs"]:
            return fail("metadata pruned club count mismatch")
        if int(metadata.get("pruned_transfer_rows", "-1")) != EXPECTED["pruned_transfer_rows"]:
            return fail("metadata pruned transfer row count mismatch")

    finally:
        con.close()

    if manifest.get("schemaVersion") != "4" or manifest.get("dataVersion") != "v4":
        return fail("manifest schemaVersion/dataVersion mismatch")
    if manifest.get("compilerStep") != EXPECTED_COMPILER_STEP:
        return fail(
            f"manifest compilerStep={manifest.get('compilerStep')!r}, "
            f"expected {EXPECTED_COMPILER_STEP!r}"
        )

    counts = manifest.get("counts") or {}
    for key in ("players", "clubs", "players_with_clubs", "search_players", "coaches"):
        if counts.get(key) != EXPECTED[key]:
            return fail(f"manifest counts.{key} mismatch: {counts.get(key)!r}")

    pruning = manifest.get("pruning") or {}
    expected_pruning = {
        "step": EXPECTED_PRUNE_STEP,
        "policy": EXPECTED_PRUNE_POLICY,
        "clubs_removed": EXPECTED["pruned_clubs"],
        "transfer_rows_removed": EXPECTED["pruned_transfer_rows"],
        "clubs_remaining": EXPECTED["clubs"],
        "transfers_remaining": 33_993,  # historical pruning result, before reviewed patches
    }
    for key, expected in expected_pruning.items():
        if pruning.get(key) != expected:
            return fail(
                f"manifest pruning.{key}={pruning.get(key)!r}, expected {expected!r}"
            )

    db_info = manifest.get("database") or {}
    actual_bytes = DB.stat().st_size
    actual_sha = sha256_file(DB)
    if db_info.get("bytes") != actual_bytes:
        return fail(
            f"manifest DB bytes={db_info.get('bytes')!r}, actual={actual_bytes}"
        )
    if db_info.get("sha256") != actual_sha:
        return fail("manifest DB sha256 does not match asset")

    print(f"Players             : {EXPECTED['players']:,}")
    print(f"Clubs               : {EXPECTED['clubs']:,}")
    print(f"Transfers           : {EXPECTED['transfers']:,}")
    print(f"Players with clubs  : {EXPECTED['players_with_clubs']:,}")
    print(f"Search players      : {EXPECTED['search_players']:,}")
    print(f"Coaches             : {EXPECTED['coaches']:,}")
    print(f"Pruned clubs        : {EXPECTED['pruned_clubs']:,}")
    print(f"Pruned transfer rows: {EXPECTED['pruned_transfer_rows']:,}")
    print("Quick check         : ok")
    print("Foreign keys        : ok")
    print(f"SHA-256             : {actual_sha}")
    print("[PASS] 08D.8A V4 production compiler freeze verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
