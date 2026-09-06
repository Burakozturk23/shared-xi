#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import unicodedata
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]

V3_DB = ROOT / "tools" / "data_platform_v4" / "input" / "linkball_runtime_v3.sqlite"

RAW_PLAYERS = ROOT / "assets" / "data" / "players_min.json"
RAW_CLUBS = ROOT / "assets" / "data" / "clubs_min.json"
RAW_COACHES = ROOT / "assets" / "data" / "coaches_min.json"

SELECTION_DIR = (
    ROOT
    / "reports"
    / "data_platform_v4"
    / "selection"
)

PLAYER_MANIFEST = (
    SELECTION_DIR
    / "player_universe_v4.json"
)

PLAYER_REMAP = (
    SELECTION_DIR
    / "player_id_remap_v4.json"
)

FALLBACK_PLAYER_CLUBS = (
    SELECTION_DIR
    / "fallback_player_clubs_v4.json"
)

CLUB_RESOLUTION = (
    SELECTION_DIR
    / "club_id_resolution_v4.json"
)

OUT_DB = (
    ROOT
    / "assets"
    / "runtime"
    / "linkball_game_data_v4.sqlite"
)

OUT_MANIFEST = (
    ROOT
    / "assets"
    / "runtime"
    / "linkball_game_data_v4_manifest.json"
)

REPORT_DIR = (
    ROOT
    / "reports"
    / "data_platform_v4"
    / "compile"
)

TM_OFFSET = 1_000_000_000
FALLBACK_OFFSET = 2_000_000_000

EXPECTED_PLAYERS = 30_135

COMPILER_STEP = "08D.8A"
PRUNE_STEP = "08D.7O"
PRUNE_POLICY = "transfer_only_development_v1"

# Frozen production contracts. If the source package intentionally changes,
# update these only together with a reviewed manifest diff.
EXPECTED_CLUBS_AFTER_PRUNE = 4_311
EXPECTED_TRANSFERS_AFTER_PRUNE = 33_993
EXPECTED_PRUNED_CLUBS = 3_091
EXPECTED_PRUNED_TRANSFER_ROWS = 13_250

BAD_NAME_PREDICATE = """
(
  TRIM(c.name) = ''
  OR LOWER(TRIM(c.name)) LIKE 'club %'
  OR LOWER(c.name) LIKE '% u16%'
  OR LOWER(c.name) LIKE '% u17%'
  OR LOWER(c.name) LIKE '% u18%'
  OR LOWER(c.name) LIKE '% u19%'
  OR LOWER(c.name) LIKE '% u20%'
  OR LOWER(c.name) LIKE '% u21%'
  OR LOWER(c.name) LIKE '% u23%'
  OR LOWER(c.name) LIKE '%under 16%'
  OR LOWER(c.name) LIKE '%under 17%'
  OR LOWER(c.name) LIKE '%under 18%'
  OR LOWER(c.name) LIKE '%under 19%'
  OR LOWER(c.name) LIKE '%under 20%'
  OR LOWER(c.name) LIKE '%under 21%'
  OR LOWER(c.name) LIKE '%under 23%'
  OR LOWER(c.name) LIKE '%youth%'
  OR LOWER(c.name) LIKE '%academy%'
  OR LOWER(c.name) LIKE '%juvenil%'
  OR LOWER(c.name) LIKE '%primavera%'
  OR LOWER(c.name) LIKE '%next gen%'
  OR LOWER(c.name) LIKE '%reserve%'
  OR LOWER(c.name) LIKE '%reserves%'
  OR LOWER(c.name) LIKE '% b team%'
  OR LOWER(c.name) LIKE '% b-team%'
  OR LOWER(TRIM(c.name)) LIKE '% ii'
  OR LOWER(COALESCE(c.entity_type, '')) IN (
    'youth', 'academy', 'reserve', 'reserves', 'development'
  )
)
"""


# ============================================================
# Generic helpers
# ============================================================

def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def as_int(value: Any, default: int | None = None) -> int | None:
    if value is None:
        return default

    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def as_float(
    value: Any,
    default: float | None = None,
) -> float | None:
    if value is None:
        return default

    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def as_text(value: Any, default: str = "") -> str:
    if value is None:
        return default

    return str(value).strip()


def sha256(path: Path) -> str:
    h = hashlib.sha256()

    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)

            if not chunk:
                break

            h.update(chunk)

    return h.hexdigest()


def norm(text: Any) -> str:
    s = as_text(text).lower()

    s = (
        s.replace("Ä±", "i")
        .replace("Ä°", "i")
    )

    s = unicodedata.normalize(
        "NFKD",
        s,
    )

    s = "".join(
        ch
        for ch in s
        if not unicodedata.combining(ch)
    )

    s = re.sub(
        r"[^a-z0-9\s]",
        " ",
        s,
    )

    s = re.sub(
        r"\s+",
        " ",
        s,
    ).strip()

    return s


def compact(text: Any) -> str:
    return norm(text).replace(" ", "")


def qident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def table_names(con: sqlite3.Connection) -> set[str]:
    return {
        str(r[0])
        for r in con.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    }


def row_count(con: sqlite3.Connection, table: str) -> int:
    if table not in table_names(con):
        return 0
    return int(
        con.execute(
            f"SELECT COUNT(*) FROM {qident(table)}"
        ).fetchone()[0]
    )


def _prune_candidate_setup(con: sqlite3.Connection) -> None:
    con.execute("DROP TABLE IF EXISTS temp._v4_prune_clubs")
    con.execute(
        "CREATE TEMP TABLE _v4_prune_clubs("
        "id INTEGER PRIMARY KEY)"
    )
    con.execute(
        f"""
        INSERT INTO _v4_prune_clubs(id)
        SELECT c.id
        FROM clubs c
        WHERE {BAD_NAME_PREDICATE}
          AND EXISTS (
            SELECT 1
            FROM transfers t
            WHERE t.from_club_id = c.id
               OR t.to_club_id = c.id
          )
        """
    )


def _protect_structural_club_references(
    con: sqlite3.Connection,
) -> list[tuple[str, str, int]]:
    """Remove from the candidate set any club referenced outside transfers.

    This deliberately scans every shipped table for club-id-shaped columns.
    It keeps the prune fail-safe if a later schema adds another structural
    relation table.
    """
    protected: list[tuple[str, str, int]] = []
    club_columns = {"club_id", "from_club_id", "to_club_id"}

    for table in sorted(table_names(con)):
        if table in {"clubs", "transfers"}:
            continue

        columns = [
            str(r[1])
            for r in con.execute(
                f"PRAGMA table_info({qident(table)})"
            )
        ]

        for col in columns:
            if col.lower() not in club_columns:
                continue

            before = int(
                con.execute(
                    "SELECT COUNT(*) FROM _v4_prune_clubs"
                ).fetchone()[0]
            )

            con.execute(
                f"""
                DELETE FROM _v4_prune_clubs
                WHERE id IN (
                  SELECT DISTINCT {qident(col)}
                  FROM {qident(table)}
                  WHERE {qident(col)} IS NOT NULL
                )
                """
            )

            after = int(
                con.execute(
                    "SELECT COUNT(*) FROM _v4_prune_clubs"
                ).fetchone()[0]
            )
            removed = before - after

            if removed:
                protected.append((table, col, removed))

    return protected


def prune_transfer_only_development_clubs(
    con: sqlite3.Connection,
) -> dict[str, Any]:
    """Apply the reviewed 08D.7O prune inside the production compiler."""
    before_clubs = row_count(con, "clubs")
    before_transfers = row_count(con, "transfers")

    _prune_candidate_setup(con)
    initial_candidates = int(
        con.execute(
            "SELECT COUNT(*) FROM _v4_prune_clubs"
        ).fetchone()[0]
    )

    protected = _protect_structural_club_references(con)
    final_candidates = int(
        con.execute(
            "SELECT COUNT(*) FROM _v4_prune_clubs"
        ).fetchone()[0]
    )

    transfer_rows = int(
        con.execute(
            """
            SELECT COUNT(*)
            FROM transfers t
            WHERE EXISTS (
                SELECT 1 FROM _v4_prune_clubs p
                WHERE p.id = t.from_club_id
            )
               OR EXISTS (
                SELECT 1 FROM _v4_prune_clubs p
                WHERE p.id = t.to_club_id
            )
            """
        ).fetchone()[0]
    )

    if final_candidates == 0:
        raise RuntimeError(
            "Production prune unexpectedly found zero candidates."
        )

    if final_candidates > before_clubs // 2:
        raise RuntimeError(
            "Safety stop: prune candidate set exceeds 50% of clubs."
        )

    projected_clubs = before_clubs - final_candidates
    if projected_clubs < 3_000:
        raise RuntimeError(
            "Safety stop: projected club count is unexpectedly low "
            f"({projected_clubs:,})."
        )

    print(
        f"[V4] prune candidates     : "
        f"{initial_candidates:,} initial / "
        f"{final_candidates:,} safe"
    )
    print(
        f"[V4] prune transfer rows  : "
        f"{transfer_rows:,}"
    )

    for table, col, count in protected:
        print(
            f"[V4] prune protected via : "
            f"{table}.{col} ({count:,})"
        )

    # Candidate preview uses a TEMP table and DML, which can open an implicit
    # transaction. Commit the preview before starting the atomic apply pass.
    con.commit()
    con.execute("BEGIN IMMEDIATE")
    try:
        _prune_candidate_setup(con)
        _protect_structural_club_references(con)

        repeat_candidates = int(
            con.execute(
                "SELECT COUNT(*) FROM _v4_prune_clubs"
            ).fetchone()[0]
        )
        if repeat_candidates != final_candidates:
            raise RuntimeError(
                "Prune candidate set changed between preview/apply: "
                f"{final_candidates:,} -> {repeat_candidates:,}"
            )

        con.execute(
            """
            DELETE FROM transfers
            WHERE EXISTS (
                SELECT 1 FROM _v4_prune_clubs p
                WHERE p.id = transfers.from_club_id
            )
               OR EXISTS (
                SELECT 1 FROM _v4_prune_clubs p
                WHERE p.id = transfers.to_club_id
            )
            """
        )
        con.execute(
            "DELETE FROM clubs "
            "WHERE id IN (SELECT id FROM _v4_prune_clubs)"
        )

        after_clubs = row_count(con, "clubs")
        after_transfers = row_count(con, "transfers")

        metadata_rows = {
            "compiler_step": COMPILER_STEP,
            "club_prune_step": PRUNE_STEP,
            "club_prune_policy": PRUNE_POLICY,
            # Keep the generic metadata keys truthful after compiler-native
            # pruning; the old standalone prune left these pre-prune values.
            "club_count": str(after_clubs),
            "transfer_rows": str(after_transfers),
            "club_count_before_prune": str(before_clubs),
            "club_count_after_prune": str(after_clubs),
            "transfer_count_before_prune": str(before_transfers),
            "transfer_count_after_prune": str(after_transfers),
            "pruned_transfer_only_development_clubs": str(
                before_clubs - after_clubs
            ),
            "pruned_transfer_rows": str(
                before_transfers - after_transfers
            ),
        }
        con.executemany(
            "INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)",
            metadata_rows.items(),
        )

        con.commit()
    except Exception:
        con.rollback()
        raise

    report = {
        "step": PRUNE_STEP,
        "policy": PRUNE_POLICY,
        "clubs_removed": before_clubs - after_clubs,
        "transfer_rows_removed": before_transfers - after_transfers,
        "clubs_remaining": after_clubs,
        "transfers_remaining": after_transfers,
    }

    if report["clubs_removed"] != EXPECTED_PRUNED_CLUBS:
        raise RuntimeError(
            "Frozen prune contract changed: clubs_removed "
            f"{report['clubs_removed']:,} != "
            f"{EXPECTED_PRUNED_CLUBS:,}"
        )

    if (
        report["transfer_rows_removed"]
        != EXPECTED_PRUNED_TRANSFER_ROWS
    ):
        raise RuntimeError(
            "Frozen prune contract changed: transfer_rows_removed "
            f"{report['transfer_rows_removed']:,} != "
            f"{EXPECTED_PRUNED_TRANSFER_ROWS:,}"
        )

    if report["clubs_remaining"] != EXPECTED_CLUBS_AFTER_PRUNE:
        raise RuntimeError(
            "Frozen club count changed: "
            f"{report['clubs_remaining']:,} != "
            f"{EXPECTED_CLUBS_AFTER_PRUNE:,}"
        )

    if (
        report["transfers_remaining"]
        != EXPECTED_TRANSFERS_AFTER_PRUNE
    ):
        raise RuntimeError(
            "Frozen transfer count changed: "
            f"{report['transfers_remaining']:,} != "
            f"{EXPECTED_TRANSFERS_AFTER_PRUNE:,}"
        )

    return report


# ============================================================
# Public club namespace
# ============================================================

def exposed_club_id(
    internal_id: int,
    canonical_key: str,
) -> int:
    key = as_text(canonical_key)

    if key.startswith("existing:"):
        source = as_int(
            key[len("existing:"):]
        )

        if source is not None:
            return source

    if key.startswith("tm:"):
        source = as_int(
            key[len("tm:"):]
        )

        if source is not None:
            return TM_OFFSET + source

    return FALLBACK_OFFSET + internal_id


# ============================================================
# Inputs
# ============================================================

print(f"===== {COMPILER_STEP} V4 PRODUCTION COMPILER FREEZE =====")
print()

required = [
    V3_DB,
    RAW_PLAYERS,
    PLAYER_MANIFEST,
    PLAYER_REMAP,
    FALLBACK_PLAYER_CLUBS,
    CLUB_RESOLUTION,
]

for path in required:
    if not path.exists():
        raise SystemExit(
            f"[FAIL] Missing input: {path}"
        )


manifest = load_json(PLAYER_MANIFEST)

final_ids = {
    int(x)
    for x in manifest["playerIds"]
}

if len(final_ids) != EXPECTED_PLAYERS:
    raise SystemExit(
        "[FAIL] Expected "
        f"{EXPECTED_PLAYERS:,} players, "
        f"got {len(final_ids):,}"
    )


player_remap_raw = load_json(
    PLAYER_REMAP
)

player_remap = {
    int(old): int(new)
    for old, new
    in player_remap_raw.items()
}


fallback_raw = load_json(
    FALLBACK_PLAYER_CLUBS
)

fallback_players = {
    int(pid): row
    for pid, row
    in fallback_raw["players"].items()
}


club_resolution_raw = load_json(
    CLUB_RESOLUTION
)

club_resolution = {
    int(raw_id): row
    for raw_id, row
    in club_resolution_raw["clubs"].items()
}


raw_players_data = load_json(
    RAW_PLAYERS
)

raw_players = {
    int(row["id"]): row
    for row in raw_players_data
    if isinstance(row, dict)
    and isinstance(row.get("id"), int)
}


missing_raw = final_ids - set(raw_players)

if missing_raw:
    raise SystemExit(
        "[FAIL] Final players missing from RAW: "
        f"{len(missing_raw):,}"
    )


print(
    f"[V4] player universe       : "
    f"{len(final_ids):,}"
)

print(
    f"[V4] player remaps         : "
    f"{len(player_remap):,}"
)

print(
    f"[V4] fallback players      : "
    f"{len(fallback_players):,}"
)


# ============================================================
# Optional RAW club metadata
# ============================================================

raw_clubs: dict[int, dict[str, Any]] = {}

if RAW_CLUBS.exists():
    try:
        value = load_json(RAW_CLUBS)

        if isinstance(value, list):
            for row in value:
                if not isinstance(row, dict):
                    continue

                cid = as_int(row.get("id"))

                if cid is not None:
                    raw_clubs[cid] = row

    except Exception as e:
        print(
            "[WARN] clubs_min.json ignored:",
            e,
        )


# ============================================================
# Optional coach payloads
# ============================================================

raw_coaches: list[dict[str, Any]] = []

if RAW_COACHES.exists():
    try:
        value = load_json(RAW_COACHES)

        if isinstance(value, list):
            raw_coaches = [
                row
                for row in value
                if isinstance(row, dict)
            ]

    except Exception as e:
        print(
            "[WARN] coaches_min.json ignored:",
            e,
        )


# ============================================================
# Open source DB
# ============================================================

src = sqlite3.connect(V3_DB)
src.row_factory = sqlite3.Row

src.execute("""
    CREATE TEMP TABLE final_v4_ids (
        id INTEGER PRIMARY KEY
    )
""")

src.executemany(
    "INSERT INTO final_v4_ids(id) VALUES (?)",
    [(pid,) for pid in sorted(final_ids)],
)


# ============================================================
# Source V3 players
# ============================================================

v3_players = {
    int(row["id"]): dict(row)
    for row in src.execute("""
        SELECT p.*
        FROM players p
        JOIN final_v4_ids f
          ON f.id = p.id
    """)
}

if len(v3_players) != EXPECTED_PLAYERS:
    raise SystemExit(
        "[FAIL] Source V3 player coverage "
        f"{len(v3_players):,}/"
        f"{EXPECTED_PLAYERS:,}"
    )


# ============================================================
# Source V3 club namespace
# ============================================================

v3_clubs_internal: dict[int, dict[str, Any]] = {}
v3_clubs_public: dict[int, dict[str, Any]] = {}
club_key_to_internal: dict[str, int] = {}

for row in src.execute("""
    SELECT *
    FROM clubs
"""):
    item = dict(row)

    internal_id = int(item["id"])
    canonical_key = as_text(
        item["canonical_key"]
    )

    public_id = exposed_club_id(
        internal_id,
        canonical_key,
    )

    item["public_id"] = public_id

    v3_clubs_internal[
        internal_id
    ] = item

    club_key_to_internal[
        canonical_key
    ] = internal_id

    v3_clubs_public[
        public_id
    ] = item


def public_club_id(
    internal_id: Any,
) -> int:
    iid = int(internal_id)

    row = v3_clubs_internal.get(iid)

    if row is None:
        raise RuntimeError(
            "Unknown V3 club internal ID: "
            f"{iid}"
        )

    return int(row["public_id"])


# ============================================================
# Read normalized V3 relations
# ============================================================

v3_player_club_rows = []

for row in src.execute("""
    SELECT
        pc.player_id,
        pc.club_id,
        pc.trust
    FROM player_clubs pc
    JOIN final_v4_ids f
      ON f.id = pc.player_id
"""):
    v3_player_club_rows.append(
        (
            int(row["player_id"]),
            public_club_id(
                row["club_id"]
            ),
            int(row["trust"]),
            "v3",
        )
    )


v3_relation_players = {
    row[0]
    for row in v3_player_club_rows
}

expected_fallback = (
    final_ids
    - v3_relation_players
)

if expected_fallback != set(
    fallback_players
):
    raise SystemExit(
        "[FAIL] Fallback-player contract changed. "
        f"expected={len(expected_fallback):,} "
        f"manifest={len(fallback_players):,}"
    )


fallback_player_club_rows = []

for pid in sorted(
    fallback_players
):
    item = fallback_players[pid]

    club_ids = item.get(
        "clubIds",
        [],
    )

    if not club_ids:
        raise SystemExit(
            "[FAIL] Fallback player has "
            f"no normalized clubs: {pid}"
        )

    for club_id in club_ids:
        fallback_player_club_rows.append(
            (
                pid,
                int(club_id),
                1,
                "raw_fallback",
            )
        )


all_player_club_rows = (
    v3_player_club_rows
    + fallback_player_club_rows
)


# ============================================================
# Career spells
# ============================================================

career_rows = []

for row in src.execute("""
    SELECT cs.*
    FROM career_spells cs
    JOIN final_v4_ids f
      ON f.id = cs.player_id
    ORDER BY
        cs.player_id,
        cs.sequence
"""):
    career_rows.append(
        (
            int(row["player_id"]),
            int(row["sequence"]),
            public_club_id(
                row["club_id"]
            ),
            row["start_date"],
            row["end_date"],
            row["confidence"],
            row["appearances"],
        )
    )


# ============================================================
# Profiles
# ============================================================

profile_rows = []

for row in src.execute("""
    SELECT pr.*
    FROM profiles pr
    JOIN final_v4_ids f
      ON f.id = pr.player_id
"""):
    profile_rows.append(
        (
            int(row["player_id"]),
            row["birth_year"],
            row["citizenship"],
            row["position_group"],
            row["detailed_position"],
            row["foot"],
            row["height_cm"],
            row["international_caps"],
            row["international_goals"],
            row["source_last_season"],
            row["identity_confidence"],
        )
    )


# ============================================================
# Player stats
# ============================================================

player_stat_rows = []

for row in src.execute("""
    SELECT ps.*
    FROM player_stats ps
    JOIN final_v4_ids f
      ON f.id = ps.player_id
"""):
    player_stat_rows.append(
        (
            int(row["player_id"]),
            row["appearances"],
            row["goals"],
            row["assists"],
            row["minutes"],
            row["ucl_appearances"],
            row["big5_appearances"],
            row["top_competition_appearances"],
            row["coverage_first_year"],
            row["coverage_last_year"],
            row["coverage_class"],
        )
    )


# ============================================================
# Club stats
# ============================================================

player_club_stat_rows = []

for row in src.execute("""
    SELECT pcs.*
    FROM player_club_stats pcs
    JOIN final_v4_ids f
      ON f.id = pcs.player_id
"""):
    player_club_stat_rows.append(
        (
            int(row["player_id"]),
            public_club_id(
                row["club_id"]
            ),
            row["appearances"],
            row["goals"],
            row["assists"],
            row["minutes"],
        )
    )


# ============================================================
# Competitions
# ============================================================

competition_rows = [
    tuple(row)
    for row in src.execute("""
        SELECT
            id,
            name,
            type,
            sub_type,
            country,
            confederation,
            is_big5,
            is_top
        FROM competitions
    """)
]


# ============================================================
# Competition stats
# ============================================================

player_comp_rows = []

for row in src.execute("""
    SELECT pcs.*
    FROM player_competition_stats pcs
    JOIN final_v4_ids f
      ON f.id = pcs.player_id
"""):
    player_comp_rows.append(
        (
            int(row["player_id"]),
            row["competition_id"],
            row["appearances"],
            row["goals"],
            row["assists"],
            row["minutes"],
        )
    )


# ============================================================
# Transfers
#
# Include:
#  - final canonical players
#  - old shadow IDs that explicitly remap into final
# ============================================================

transfer_player_ids = (
    final_ids
    | set(player_remap)
)

src.execute("""
    CREATE TEMP TABLE transfer_v4_ids (
        id INTEGER PRIMARY KEY
    )
""")

src.executemany(
    "INSERT INTO transfer_v4_ids(id) VALUES (?)",
    [
        (pid,)
        for pid
        in sorted(transfer_player_ids)
    ],
)


transfer_rows = []

for row in src.execute("""
    SELECT t.*
    FROM transfers t
    JOIN transfer_v4_ids f
      ON f.id = t.player_id
"""):
    source_player_id = int(
        row["player_id"]
    )

    player_id = player_remap.get(
        source_player_id,
        source_player_id,
    )

    if player_id not in final_ids:
        continue

    transfer_rows.append(
        (
            row["event_id"],
            player_id,
            row["transfer_date"],
            row["transfer_year"],
            public_club_id(
                row["from_club_id"]
            ),
            public_club_id(
                row["to_club_id"]
            ),
            row["trust"],
            source_player_id,
        )
    )


# ============================================================
# Collect every required public club ID
# ============================================================

needed_club_ids: set[int] = set()

for row in all_player_club_rows:
    needed_club_ids.add(
        int(row[1])
    )

for row in career_rows:
    needed_club_ids.add(
        int(row[2])
    )

for row in player_club_stat_rows:
    needed_club_ids.add(
        int(row[1])
    )

for row in transfer_rows:
    needed_club_ids.add(
        int(row[4])
    )
    needed_club_ids.add(
        int(row[5])
    )


# ============================================================
# Club records
# ============================================================

club_output_rows = []

missing_club_master = []

for club_id in sorted(
    needed_club_ids
):
    src_row = v3_clubs_public.get(
        club_id
    )

    if src_row is None:
        # A fallback club should still map to
        # one of the V3 canonical keys frozen
        # in club_id_resolution_v4.json.
        matching_resolution = None

        for item in club_resolution.values():
            if (
                int(
                    item["canonicalClubId"]
                )
                == club_id
            ):
                matching_resolution = item
                break

        if matching_resolution is not None:
            key = as_text(
                matching_resolution[
                    "canonicalKey"
                ]
            )

            internal = (
                club_key_to_internal.get(
                    key
                )
            )

            if internal is not None:
                src_row = (
                    v3_clubs_internal[
                        internal
                    ]
                )

    if src_row is None:
        missing_club_master.append(
            club_id
        )
        continue

    canonical_key = as_text(
        src_row["canonical_key"]
    )

    name = as_text(
        src_row["name"],
        f"Club {club_id}",
    )

    country = as_text(
        src_row["country"]
    )

    competition = as_text(
        src_row["competition"]
    )

    entity_type = as_text(
        src_row["entity_type"]
    )

    popularity_seed = (
        as_int(
            src_row["popularity_seed"],
            0,
        )
        or 0
    )

    gameplay_eligible = (
        as_int(
            src_row["gameplay_eligible"],
            0,
        )
        or 0
    )

    gameplay_pool = (
        as_int(
            src_row["gameplay_pool"],
            0,
        )
        or 0
    )

    # Optional enrichment for existing:<id>.
    badge_key = ""
    color = None

    if canonical_key.startswith(
        "existing:"
    ):
        raw_id = as_int(
            canonical_key[
                len("existing:"):
            ]
        )

        raw_meta = (
            raw_clubs.get(
                raw_id,
                {},
            )
            if raw_id is not None
            else {}
        )

        badge_key = as_text(
            raw_meta.get("badgeKey")
        )

        color = as_int(
            raw_meta.get("color")
        )

    club_output_rows.append(
        (
            club_id,
            canonical_key,
            name,
            country,
            competition,
            entity_type,
            popularity_seed,
            gameplay_eligible,
            gameplay_pool,
            badge_key,
            color,
        )
    )


if missing_club_master:
    raise SystemExit(
        "[FAIL] Missing V4 club master rows: "
        f"{len(missing_club_master):,} "
        f"{missing_club_master[:30]}"
    )


# ============================================================
# Build output DB
# ============================================================

if OUT_DB.exists():
    OUT_DB.unlink()

OUT_DB.parent.mkdir(
    parents=True,
    exist_ok=True,
)

db = sqlite3.connect(OUT_DB)

db.execute(
    "PRAGMA journal_mode=OFF"
)

db.execute(
    "PRAGMA synchronous=OFF"
)

db.execute(
    "PRAGMA temp_store=MEMORY"
)

db.execute(
    "PRAGMA foreign_keys=ON"
)

db.executescript("""
CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
) WITHOUT ROWID;


CREATE TABLE players (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    country TEXT,
    position TEXT,

    selection_score REAL,
    selection_rank INTEGER,

    answer_eligible INTEGER NOT NULL DEFAULT 0,
    playable INTEGER NOT NULL DEFAULT 0,
    casual INTEGER NOT NULL DEFAULT 0,
    normal INTEGER NOT NULL DEFAULT 0,
    hard INTEGER NOT NULL DEFAULT 0,
    visual_priority INTEGER NOT NULL DEFAULT 0,

    market_value REAL,
    peak_market_value REAL,
    career_goals INTEGER,
    avatar_key TEXT,

    source TEXT NOT NULL DEFAULT 'v4'
);


CREATE TABLE player_countries (
    player_id INTEGER NOT NULL,
    ord INTEGER NOT NULL,
    country TEXT NOT NULL,

    PRIMARY KEY(player_id, ord),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE
) WITHOUT ROWID;


CREATE TABLE player_aliases (
    player_id INTEGER NOT NULL,
    ord INTEGER NOT NULL,
    alias TEXT NOT NULL,
    normalized_alias TEXT NOT NULL,

    PRIMARY KEY(player_id, ord),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE
) WITHOUT ROWID;


CREATE TABLE player_search_terms (
    player_id INTEGER NOT NULL,
    term TEXT NOT NULL,
    compact_term TEXT NOT NULL,
    kind TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 0,

    PRIMARY KEY(player_id, term, kind),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE
) WITHOUT ROWID;


CREATE TABLE clubs (
    id INTEGER PRIMARY KEY,
    canonical_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    country TEXT,
    competition TEXT,
    entity_type TEXT,

    popularity_seed INTEGER NOT NULL DEFAULT 0,
    gameplay_eligible INTEGER NOT NULL DEFAULT 0,
    gameplay_pool INTEGER NOT NULL DEFAULT 0,

    badge_key TEXT,
    color INTEGER
);


CREATE TABLE player_clubs (
    player_id INTEGER NOT NULL,
    club_id INTEGER NOT NULL,
    trust INTEGER NOT NULL DEFAULT 1,
    source TEXT NOT NULL,

    PRIMARY KEY(player_id, club_id),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE,

    FOREIGN KEY(club_id)
        REFERENCES clubs(id)
) WITHOUT ROWID;


CREATE TABLE profiles (
    player_id INTEGER PRIMARY KEY,

    birth_year INTEGER,
    citizenship TEXT,
    position_group TEXT,
    detailed_position TEXT,
    foot TEXT,
    height_cm INTEGER,
    international_caps INTEGER,
    international_goals INTEGER,
    source_last_season INTEGER,
    identity_confidence TEXT,

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE
);


CREATE TABLE player_stats (
    player_id INTEGER PRIMARY KEY,

    appearances INTEGER,
    goals INTEGER,
    assists INTEGER,
    minutes INTEGER,

    ucl_appearances INTEGER,
    big5_appearances INTEGER,
    top_competition_appearances INTEGER,

    coverage_first_year INTEGER,
    coverage_last_year INTEGER,
    coverage_class TEXT,

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE
);


CREATE TABLE career_spells (
    player_id INTEGER NOT NULL,
    sequence INTEGER NOT NULL,
    club_id INTEGER NOT NULL,

    start_date TEXT,
    end_date TEXT,
    confidence TEXT,
    appearances INTEGER,

    PRIMARY KEY(player_id, sequence),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE,

    FOREIGN KEY(club_id)
        REFERENCES clubs(id)
) WITHOUT ROWID;


CREATE TABLE player_club_stats (
    player_id INTEGER NOT NULL,
    club_id INTEGER NOT NULL,

    appearances INTEGER,
    goals INTEGER,
    assists INTEGER,
    minutes INTEGER,

    PRIMARY KEY(player_id, club_id),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE,

    FOREIGN KEY(club_id)
        REFERENCES clubs(id)
) WITHOUT ROWID;


CREATE TABLE competitions (
    id TEXT PRIMARY KEY,
    name TEXT,
    type TEXT,
    sub_type TEXT,
    country TEXT,
    confederation TEXT,
    is_big5 INTEGER NOT NULL DEFAULT 0,
    is_top INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;


CREATE TABLE player_competition_stats (
    player_id INTEGER NOT NULL,
    competition_id TEXT NOT NULL,

    appearances INTEGER,
    goals INTEGER,
    assists INTEGER,
    minutes INTEGER,

    PRIMARY KEY(
        player_id,
        competition_id
    ),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE,

    FOREIGN KEY(competition_id)
        REFERENCES competitions(id)
) WITHOUT ROWID;


CREATE TABLE transfers (
    event_id TEXT PRIMARY KEY,
    player_id INTEGER NOT NULL,

    transfer_date TEXT,
    transfer_year INTEGER,

    from_club_id INTEGER NOT NULL,
    to_club_id INTEGER NOT NULL,

    trust INTEGER NOT NULL DEFAULT 0,

    source_player_id INTEGER,

    FOREIGN KEY(player_id)
        REFERENCES players(id),

    FOREIGN KEY(from_club_id)
        REFERENCES clubs(id),

    FOREIGN KEY(to_club_id)
        REFERENCES clubs(id)
);


CREATE TABLE player_tags (
    player_id INTEGER NOT NULL,
    tag TEXT NOT NULL,

    PRIMARY KEY(player_id, tag),

    FOREIGN KEY(player_id)
        REFERENCES players(id)
        ON DELETE CASCADE
) WITHOUT ROWID;


/*
 Coach data is deliberately encapsulated in the
 same production DB. Coach.fromJson can consume
 payload_json during the first repository migration.
*/
CREATE TABLE coaches (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    payload_json TEXT NOT NULL
);
""")


# ============================================================
# Players + RAW enrichment
# ============================================================

player_rows = []
country_rows = []
alias_rows = []
search_rows = []

for pid in sorted(final_ids):
    v3 = v3_players[pid]
    raw = raw_players[pid]

    name = as_text(
        v3["name"]
    )

    if not name:
        name = as_text(
            raw.get("name")
        )

    if not name:
        raise SystemExit(
            f"[FAIL] Empty player name: {pid}"
        )

    market = as_float(
        raw.get("marketValue"),
        0.0,
    )

    peak = as_float(
        raw.get("peakMarketValue"),
        0.0,
    )

    career_goals = as_int(
        raw.get("careerGoals"),
        0,
    )

    avatar_key = as_text(
        raw.get("avatarKey")
    )

    player_rows.append(
        (
            pid,
            name,
            as_text(v3["country"]),
            as_text(v3["position"]),
            v3["selection_score"],
            v3["selection_rank"],
            int(v3["answer_eligible"] or 0),
            int(v3["playable"] or 0),
            int(v3["casual"] or 0),
            int(v3["normal"] or 0),
            int(v3["hard"] or 0),
            int(v3["visual_priority"] or 0),
            market,
            peak,
            career_goals,
            avatar_key,
            "v4",
        )
    )

    countries = raw.get(
        "countries"
    )

    if not isinstance(
        countries,
        list,
    ):
        countries = []

    seen_countries = set()

    for value in countries:
        country = as_text(value)

        if not country:
            continue

        key = country.lower()

        if key in seen_countries:
            continue

        seen_countries.add(key)

        country_rows.append(
            (
                pid,
                len(seen_countries) - 1,
                country,
            )
        )

    aliases = raw.get(
        "aliases"
    )

    if not isinstance(
        aliases,
        list,
    ):
        aliases = []

    seen_aliases = set()

    clean_aliases = []

    for value in aliases:
        alias = as_text(value)

        if not alias:
            continue

        key = alias.lower()

        if key in seen_aliases:
            continue

        seen_aliases.add(key)
        clean_aliases.append(alias)

    for idx, alias in enumerate(
        clean_aliases
    ):
        alias_rows.append(
            (
                pid,
                idx,
                alias,
                norm(alias),
            )
        )

    # Search terms are generated at compile time.
    labels = [
        ("name", name, 100),
    ]

    for alias in clean_aliases:
        labels.append(
            ("alias", alias, 80)
        )

    # Last name is useful for surname search.
    parts = norm(name).split()

    if len(parts) >= 2:
        labels.append(
            (
                "surname",
                parts[-1],
                60,
            )
        )

    seen_terms = set()

    for kind, label, priority in labels:
        term = norm(label)

        if not term:
            continue

        key = (
            term,
            kind,
        )

        if key in seen_terms:
            continue

        seen_terms.add(key)

        search_rows.append(
            (
                pid,
                term,
                compact(term),
                kind,
                priority,
            )
        )


db.executemany("""
    INSERT INTO players VALUES (
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?,?,?,?
    )
""", player_rows)

db.executemany("""
    INSERT INTO player_countries
    VALUES (?,?,?)
""", country_rows)

db.executemany("""
    INSERT INTO player_aliases
    VALUES (?,?,?,?)
""", alias_rows)

db.executemany("""
    INSERT INTO player_search_terms
    VALUES (?,?,?,?,?)
""", search_rows)


# ============================================================
# Clubs and relations
# ============================================================

db.executemany("""
    INSERT INTO clubs VALUES (
        ?,?,?,?,?,?,
        ?,?,?,?,?
    )
""", club_output_rows)


db.executemany("""
    INSERT OR REPLACE
    INTO player_clubs
    VALUES (?,?,?,?)
""", all_player_club_rows)


# ============================================================
# Factual normalized tables
# ============================================================

db.executemany("""
    INSERT INTO profiles VALUES (
        ?,?,?,?,?,?,
        ?,?,?,?,?
    )
""", profile_rows)


db.executemany("""
    INSERT INTO player_stats VALUES (
        ?,?,?,?,?,?,
        ?,?,?,?,?
    )
""", player_stat_rows)


db.executemany("""
    INSERT INTO career_spells VALUES (
        ?,?,?,?,?,?,?
    )
""", career_rows)


db.executemany("""
    INSERT INTO player_club_stats
    VALUES (?,?,?,?,?,?)
""", player_club_stat_rows)


db.executemany("""
    INSERT INTO competitions
    VALUES (?,?,?,?,?,?,?,?)
""", competition_rows)


db.executemany("""
    INSERT INTO player_competition_stats
    VALUES (?,?,?,?,?,?)
""", player_comp_rows)


# event_id remains the stable unique key.
db.executemany("""
    INSERT OR REPLACE INTO transfers
    VALUES (?,?,?,?,?,?,?,?)
""", transfer_rows)


# ============================================================
# Coaches
# ============================================================

coach_rows = []

used_coach_ids = set()
fallback_coach_id = -1

for row in raw_coaches:
    cid = as_int(row.get("id"))

    if cid is None:
        while fallback_coach_id in used_coach_ids:
            fallback_coach_id -= 1

        cid = fallback_coach_id
        fallback_coach_id -= 1

    if cid in used_coach_ids:
        continue

    used_coach_ids.add(cid)

    name = as_text(
        row.get("name")
    )

    if not name:
        name = f"Coach {cid}"

    coach_rows.append(
        (
            cid,
            name,
            norm(name),
            json.dumps(
                row,
                ensure_ascii=False,
                separators=(",", ":"),
            ),
        )
    )


db.executemany("""
    INSERT INTO coaches
    VALUES (?,?,?,?)
""", coach_rows)


# ============================================================
# Standard universal tags
#
# These are capabilities/quality bands,
# not separate per-mode datasets.
# ============================================================

db.executescript("""
INSERT OR IGNORE INTO player_tags
SELECT id, 'playable'
FROM players
WHERE playable = 1;

INSERT OR IGNORE INTO player_tags
SELECT id, 'answer'
FROM players
WHERE answer_eligible = 1;

INSERT OR IGNORE INTO player_tags
SELECT id, 'casual'
FROM players
WHERE casual = 1;

INSERT OR IGNORE INTO player_tags
SELECT id, 'normal'
FROM players
WHERE normal = 1;

INSERT OR IGNORE INTO player_tags
SELECT id, 'hard'
FROM players
WHERE hard = 1;

INSERT OR IGNORE INTO player_tags
SELECT id, 'visual'
FROM players
WHERE visual_priority = 1;


INSERT OR IGNORE INTO player_tags
SELECT
    player_id,
    'multi_club'
FROM player_clubs
GROUP BY player_id
HAVING COUNT(DISTINCT club_id) >= 2;


INSERT OR IGNORE INTO player_tags
SELECT
    player_id,
    'career'
FROM career_spells
GROUP BY player_id
HAVING COUNT(*) >= 2;


INSERT OR IGNORE INTO player_tags
SELECT DISTINCT
    player_id,
    'transfer'
FROM transfers;


INSERT OR IGNORE INTO player_tags
SELECT DISTINCT
    player_id,
    'stats'
FROM player_stats;


INSERT OR IGNORE INTO player_tags
SELECT DISTINCT
    player_id,
    'club_stats'
FROM player_club_stats;


INSERT OR IGNORE INTO player_tags
SELECT DISTINCT
    player_id,
    'competition_stats'
FROM player_competition_stats;
""")


# ============================================================
# Metadata
# ============================================================

generated_utc = datetime.now(
    timezone.utc
).isoformat()

metadata = {
    "schema_version": "4",
    "data_version": "v4",
    "compiler_step": COMPILER_STEP,
    "generated_utc": generated_utc,

    "player_count":
        str(len(player_rows)),

    "club_count":
        str(len(club_output_rows)),

    "coach_count":
        str(len(coach_rows)),

    "player_club_rows":
        str(len(all_player_club_rows)),

    "career_spell_rows":
        str(len(career_rows)),

    "transfer_rows":
        str(len(transfer_rows)),

    "source_v3_sha256":
        sha256(V3_DB),

    "source_player_manifest_sha256":
        sha256(PLAYER_MANIFEST),

    "source_club_resolution_sha256":
        sha256(CLUB_RESOLUTION),

    "runtime_mutated":
        "false",
}


db.executemany("""
    INSERT INTO metadata(key, value)
    VALUES (?, ?)
""", metadata.items())


# ============================================================
# Indexes
# ============================================================

print("[V4] Creating indexes...")

db.executescript("""
CREATE INDEX idx_players_name
ON players(name);

CREATE INDEX idx_players_rank
ON players(selection_rank);


CREATE INDEX idx_player_country_country
ON player_countries(country, player_id);


CREATE INDEX idx_player_alias_normalized
ON player_aliases(normalized_alias, player_id);


CREATE INDEX idx_search_term
ON player_search_terms(term, priority DESC);

CREATE INDEX idx_search_compact
ON player_search_terms(compact_term, priority DESC);


CREATE INDEX idx_clubs_name
ON clubs(name);

CREATE INDEX idx_clubs_country
ON clubs(country);

CREATE INDEX idx_clubs_competition
ON clubs(competition);


CREATE INDEX idx_player_clubs_club_player
ON player_clubs(club_id, player_id);


CREATE INDEX idx_career_player_seq
ON career_spells(player_id, sequence);

CREATE INDEX idx_career_club_player
ON career_spells(club_id, player_id);


CREATE INDEX idx_club_stats_club
ON player_club_stats(club_id, player_id);


CREATE INDEX idx_comp_stats_comp
ON player_competition_stats(
    competition_id,
    player_id
);


CREATE INDEX idx_transfers_player_date
ON transfers(
    player_id,
    transfer_year
);

CREATE INDEX idx_transfers_from_to
ON transfers(
    from_club_id,
    to_club_id
);


CREATE INDEX idx_player_tags_tag
ON player_tags(
    tag,
    player_id
);


CREATE INDEX idx_coaches_name
ON coaches(normalized_name);
""")


# ============================================================
# Reviewed production prune (08D.7O), now compiler-native
# ============================================================

db.commit()

print("[V4] Applying frozen production prune...")
pruning_report = prune_transfer_only_development_clubs(db)


# ============================================================
# Analyze / foreign-key audit
# ============================================================

db.commit()

print("[V4] ANALYZE...")
db.execute("ANALYZE")

print("[V4] foreign_key_check...")
fk_errors = db.execute(
    "PRAGMA foreign_key_check"
).fetchall()

if fk_errors:
    print(
        "[FAIL] Foreign-key violations:",
        len(fk_errors),
    )

    for row in fk_errors[:30]:
        print(row)

    raise SystemExit(1)


print("[V4] quick_check...")
quick = db.execute(
    "PRAGMA quick_check"
).fetchone()[0]

if quick != "ok":
    raise SystemExit(
        f"[FAIL] SQLite quick_check: {quick}"
    )


# ============================================================
# Critical invariants
# ============================================================

def scalar(sql: str) -> int:
    return int(
        db.execute(sql).fetchone()[0]
    )


checks = {
    "players":
        scalar(
            "SELECT COUNT(*) FROM players"
        ),

    "unique_player_ids":
        scalar("""
            SELECT COUNT(DISTINCT id)
            FROM players
        """),

    "shadow_players":
        scalar("""
            SELECT COUNT(*)
            FROM players
            WHERE id IN (34601, 111961)
        """),

    "players_with_clubs":
        scalar("""
            SELECT COUNT(
                DISTINCT player_id
            )
            FROM player_clubs
        """),

    "clubs":
        scalar(
            "SELECT COUNT(*) FROM clubs"
        ),

    "career_players":
        scalar("""
            SELECT COUNT(
                DISTINCT player_id
            )
            FROM career_spells
        """),

    "transfer_players":
        scalar("""
            SELECT COUNT(
                DISTINCT player_id
            )
            FROM transfers
        """),

    "search_players":
        scalar("""
            SELECT COUNT(
                DISTINCT player_id
            )
            FROM player_search_terms
        """),

    "coaches":
        scalar(
            "SELECT COUNT(*) FROM coaches"
        ),
}


if checks["players"] != EXPECTED_PLAYERS:
    raise SystemExit(
        "[FAIL] Wrong player count."
    )

if (
    checks["unique_player_ids"]
    != EXPECTED_PLAYERS
):
    raise SystemExit(
        "[FAIL] Player IDs not unique."
    )

if checks["shadow_players"] != 0:
    raise SystemExit(
        "[FAIL] Shadow IDs leaked into V4."
    )

if (
    checks["players_with_clubs"]
    != EXPECTED_PLAYERS
):
    raise SystemExit(
        "[FAIL] Some final players "
        "have no club relation."
    )

if (
    checks["search_players"]
    != EXPECTED_PLAYERS
):
    raise SystemExit(
        "[FAIL] Some final players "
        "are missing from search."
    )


# ============================================================
# VACUUM + final SHA
# ============================================================

db.commit()
db.close()

print("[V4] VACUUM...")

vac = sqlite3.connect(OUT_DB)
vac.execute("VACUUM")
vac.close()


size_mb = (
    OUT_DB.stat().st_size
    / 1024
    / 1024
)

db_sha = sha256(OUT_DB)


# ============================================================
# Output manifest
# ============================================================

output_manifest = {
    "schemaVersion": "4",
    "dataVersion": "v4",
    "compilerStep": COMPILER_STEP,
    "generatedUtc": generated_utc,

    "database": {
        "asset":
            "assets/runtime/"
            "linkball_game_data_v4.sqlite",

        "bytes":
            OUT_DB.stat().st_size,

        "sizeMB":
            round(size_mb, 2),

        "sha256":
            db_sha,
    },

    "counts": checks,

    "pruning": pruning_report,

    "contracts": {
        "playerUniverse":
            EXPECTED_PLAYERS,

        "clubIdNamespace": {
            "existing":
                "source ID unchanged",

            "tm":
                "1_000_000_000 + source ID",

            "fallback":
                "2_000_000_000 + "
                "V3 internal ID",
        },

        "playerClubPolicy":
            "V3 primary; normalized RAW "
            "fallback for exactly 33 players",

        "careerPolicy":
            "Normalized V3 career_spells only",

        "legacyPoolsCopied":
            False,

        "runtimeJsonRequired":
            False,
    },
}

OUT_MANIFEST.write_text(
    json.dumps(
        output_manifest,
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)


REPORT_DIR.mkdir(
    parents=True,
    exist_ok=True,
)

(
    REPORT_DIR
    / "compile_summary_v4.json"
).write_text(
    json.dumps(
        output_manifest,
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)


# ============================================================
# Report
# ============================================================

print()
print(
    f"===== {COMPILER_STEP} V4 PRODUCTION DATABASE ====="
)

print(
    f"Players             : "
    f"{checks['players']:,}"
)

print(
    f"Players with clubs  : "
    f"{checks['players_with_clubs']:,}"
)

print(
    f"Clubs               : "
    f"{checks['clubs']:,}"
)

print(
    f"Career players      : "
    f"{checks['career_players']:,}"
)

print(
    f"Transfer players    : "
    f"{checks['transfer_players']:,}"
)

print(
    f"Search players      : "
    f"{checks['search_players']:,}"
)

print(
    f"Coaches             : "
    f"{checks['coaches']:,}"
)

print(
    f"Pruned clubs        : "
    f"{pruning_report['clubs_removed']:,}"
)

print(
    f"Transfers remaining : "
    f"{pruning_report['transfers_remaining']:,}"
)

print(
    f"DB size MB          : "
    f"{size_mb:.2f}"
)

print(
    f"Quick check         : ok"
)

print(
    f"Foreign keys        : ok"
)

print(
    f"SHA-256             : "
    f"{db_sha}"
)

print()
print(
    f"DB                  : "
    f"{OUT_DB}"
)

print(
    f"Manifest            : "
    f"{OUT_MANIFEST}"
)

print()
print(
    "[PASS] Frozen unified V4 production "
    "database compiled and pruned."
)
