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
    "transfers": 33_993,
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


def scalar(con: sqlite3.Connection, sql: str) -> int:
    return int(con.execute(sql).fetchone()[0])


def main() -> int:
    print("===== 08D.8A V4 PRODUCTION FREEZE VERIFY =====")

    if not DB.exists():
        return fail(f"DB missing: {DB}")
    if not MANIFEST.exists():
        return fail(f"Manifest missing: {MANIFEST}")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
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
        "transfers_remaining": EXPECTED["transfers"],
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
