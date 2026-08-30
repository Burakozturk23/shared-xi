#!/usr/bin/env python3
from __future__ import annotations

import csv
import hashlib
import json
import sqlite3
import time
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[2]
D2_DIR = ROOT / "reports" / "data_platform_v3" / "03d2"
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
F_DIR = ROOT / "reports" / "data_platform_v3" / "03f"
G1_DIR = ROOT / "reports" / "data_platform_v3" / "03g1"
G12_DIR = ROOT / "reports" / "data_platform_v3" / "03g1_2"
G2_DIR = ROOT / "reports" / "data_platform_v3" / "03g2"
G21_DIR = ROOT / "reports" / "data_platform_v3" / "03g2_1"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03g3"
DB_PATH = OUT_DIR / "linkball_runtime_v3.preview.sqlite"

FORBIDDEN_SCHEMA_TERMS = (
    "marketvalue", "peakmarketvalue", "market_value",
    "image_url", "imageurl", "source_url", "transfer_fee",
    "agent_name", "agent"
)
PSEUDO_NAMES = {
    "retired", "without club", "career break",
    "unknown", "free agent", "unattached"
}
BATCH = 20000

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def as_int(v: Any, default: int = 0) -> int:
    try:
        if s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def as_float(v: Any, default: float = 0.0) -> float:
    try:
        if s(v) == "":
            return default
        return float(v)
    except Exception:
        return default

def yes(v: Any) -> bool:
    return s(v).upper() == "YES"

def csv_rows(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        yield from csv.DictReader(f)

def read_small_csv(path: Path):
    return list(csv_rows(path))

def write_csv(name: str, rows, fields=None):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fields is None:
        fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def compressed_estimate(path: Path) -> int:
    tmp = OUT_DIR / "_sqlite_deflate_estimate.zip"
    if tmp.exists():
        tmp.unlink()
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.write(path, path.name)
    size = tmp.stat().st_size
    tmp.unlink()
    return size

def chunked(items: Iterable[tuple], size: int = BATCH):
    batch = []
    for item in items:
        batch.append(item)
        if len(batch) >= size:
            yield batch
            batch = []
    if batch:
        yield batch

def main():
    started = time.perf_counter()
    print("=" * 82)
    print("LINKBALL DATA PLATFORM V3 - STEP 03G.3")
    print("FINAL DATA QA + RUNTIME SQLITE COMPILER PREVIEW (READ-ONLY)")
    print("=" * 82)

    # Small/medium dimensions are kept in memory. Large fact tables are streamed.
    players = read_small_csv(E2_DIR / "player_selection_scores_v3.csv")
    clubs = read_small_csv(D2_DIR / "canonical_clubs_gameplay_guarded_v2.csv")
    profiles = read_small_csv(G12_DIR / "player_profile_factual_v3.csv")
    stats = read_small_csv(G12_DIR / "player_stats_source_window_v3.csv")
    competitions = read_small_csv(G1_DIR / "competitions_factual.csv")
    puzzle_candidates = read_small_csv(G21_DIR / "career_puzzle_candidates_v2.csv")
    shadows = read_small_csv(G12_DIR / "shadow_duplicate_suppressions_v2.csv")
    transfer_detective = read_small_csv(G2_DIR / "transfer_detective_events.preview.csv")

    pool_path = F_DIR / "mode_pool_ids.preview.json"
    if not pool_path.exists():
        raise FileNotFoundError(f"Eksik dosya: {pool_path}")
    pools = json.loads(pool_path.read_text(encoding="utf-8"))["pools"]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()

    shadow_map = {
        as_int(r.get("shadowCanonicalPlayerId"), -1): as_int(r.get("primaryCanonicalPlayerId"), -1)
        for r in shadows if as_int(r.get("shadowCanonicalPlayerId"), -1) >= 0
    }
    player_ids = {as_int(r.get("id"), -1) for r in players if as_int(r.get("id"), -1) >= 0}
    player_by_id = {as_int(r.get("id"), -1): r for r in players if as_int(r.get("id"), -1) >= 0}

    club_sorted = sorted(
        [r for r in clubs if s(r.get("canonicalKey"))],
        key=lambda r: s(r.get("canonicalKey"))
    )
    club_pk = {s(r.get("canonicalKey")): i + 1 for i, r in enumerate(club_sorted)}

    print(f"[03G.3] Player: {len(player_ids):,}")
    print(f"[03G.3] Club master: {len(club_sorted):,}")
    print(f"[03G.3] Factual profile: {len(profiles):,}")
    print(f"[03G.3] Factual stats: {len(stats):,}")
    print(f"[03G.3] Shadow suppression: {len(shadow_map):,}")

    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.executescript("""
    PRAGMA page_size=4096;
    PRAGMA journal_mode=OFF;
    PRAGMA synchronous=OFF;
    PRAGMA temp_store=MEMORY;
    PRAGMA cache_size=-120000;
    PRAGMA foreign_keys=OFF;

    CREATE TABLE metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) WITHOUT ROWID;

    CREATE TABLE players (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      country TEXT,
      position TEXT,
      selection_score REAL NOT NULL DEFAULT 0,
      selection_rank INTEGER,
      answer_eligible INTEGER NOT NULL DEFAULT 0,
      playable INTEGER NOT NULL DEFAULT 0,
      casual INTEGER NOT NULL DEFAULT 0,
      normal INTEGER NOT NULL DEFAULT 0,
      hard INTEGER NOT NULL DEFAULT 0,
      visual_priority INTEGER NOT NULL DEFAULT 0,
      is_shadow INTEGER NOT NULL DEFAULT 0,
      shadow_primary_id INTEGER
    );

    CREATE TABLE clubs (
      id INTEGER PRIMARY KEY,
      canonical_key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      country TEXT,
      competition TEXT,
      entity_type TEXT,
      popularity_seed INTEGER NOT NULL DEFAULT 0,
      gameplay_eligible INTEGER NOT NULL DEFAULT 0,
      gameplay_pool INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE player_clubs (
      player_id INTEGER NOT NULL,
      club_id INTEGER NOT NULL,
      trust INTEGER NOT NULL,
      PRIMARY KEY(player_id, club_id),
      FOREIGN KEY(player_id) REFERENCES players(id),
      FOREIGN KEY(club_id) REFERENCES clubs(id)
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
      FOREIGN KEY(player_id) REFERENCES players(id)
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
      FOREIGN KEY(player_id) REFERENCES players(id)
    );

    CREATE TABLE player_club_stats (
      player_id INTEGER NOT NULL,
      club_id INTEGER NOT NULL,
      appearances INTEGER,
      goals INTEGER,
      assists INTEGER,
      minutes INTEGER,
      PRIMARY KEY(player_id, club_id),
      FOREIGN KEY(player_id) REFERENCES players(id),
      FOREIGN KEY(club_id) REFERENCES clubs(id)
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
      PRIMARY KEY(player_id, competition_id),
      FOREIGN KEY(player_id) REFERENCES players(id),
      FOREIGN KEY(competition_id) REFERENCES competitions(id)
    ) WITHOUT ROWID;

    CREATE TABLE career_spells (
      player_id INTEGER NOT NULL,
      sequence INTEGER NOT NULL,
      club_id INTEGER NOT NULL,
      start_date TEXT,
      end_date TEXT,
      confidence TEXT NOT NULL,
      appearances INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(player_id, sequence),
      FOREIGN KEY(player_id) REFERENCES players(id),
      FOREIGN KEY(club_id) REFERENCES clubs(id)
    ) WITHOUT ROWID;

    CREATE TABLE transfers (
      event_id TEXT PRIMARY KEY,
      player_id INTEGER NOT NULL,
      transfer_date TEXT NOT NULL,
      transfer_year INTEGER,
      from_club_id INTEGER NOT NULL,
      to_club_id INTEGER NOT NULL,
      trust TEXT,
      FOREIGN KEY(player_id) REFERENCES players(id),
      FOREIGN KEY(from_club_id) REFERENCES clubs(id),
      FOREIGN KEY(to_club_id) REFERENCES clubs(id)
    ) WITHOUT ROWID;

    CREATE TABLE player_pools (
      pool_name TEXT NOT NULL,
      player_id INTEGER NOT NULL,
      PRIMARY KEY(pool_name, player_id),
      FOREIGN KEY(player_id) REFERENCES players(id)
    ) WITHOUT ROWID;

    CREATE TABLE club_pools (
      pool_name TEXT NOT NULL,
      club_id INTEGER NOT NULL,
      PRIMARY KEY(pool_name, club_id),
      FOREIGN KEY(club_id) REFERENCES clubs(id)
    ) WITHOUT ROWID;

    CREATE TABLE event_pools (
      pool_name TEXT NOT NULL,
      event_id TEXT NOT NULL,
      PRIMARY KEY(pool_name, event_id),
      FOREIGN KEY(event_id) REFERENCES transfers(event_id)
    ) WITHOUT ROWID;
    """)

    print("[03G.3] Dimension tabloları yazılıyor...")
    cur.executemany(
        "INSERT INTO players VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [(
            pid,
            s(r.get("name")),
            s(r.get("countries")).split("|")[0] if s(r.get("countries")) else "",
            s(r.get("position")),
            as_float(r.get("selectionScoreV3")),
            as_int(r.get("selectionRankV3"), 0) or None,
            int(yes(r.get("answerEligible"))),
            int(yes(r.get("playableV3"))),
            int(yes(r.get("casualV3"))),
            int(yes(r.get("normalV3"))),
            int(yes(r.get("hardV3"))),
            int(yes(r.get("visualPriorityV3"))),
            int(pid in shadow_map),
            shadow_map.get(pid)
        ) for pid, r in player_by_id.items()]
    )

    cur.executemany(
        "INSERT INTO clubs VALUES (?,?,?,?,?,?,?,?,?)",
        [(
            club_pk[s(r.get("canonicalKey"))],
            s(r.get("canonicalKey")),
            s(r.get("name")),
            s(r.get("country")),
            s(r.get("competition")),
            s(r.get("entityType")),
            as_int(r.get("popularitySeed")),
            int(yes(r.get("gameplayEligible03d1"))),
            int(yes(r.get("gameplayPool4000")))
        ) for r in club_sorted]
    )

    profile_seen = set()
    profile_insert = []
    for r in profiles:
        pid = as_int(r.get("playerId"), -1)
        if pid not in player_ids or pid in profile_seen:
            continue
        profile_seen.add(pid)
        profile_insert.append((
            pid, as_int(r.get("birthYear")) or None, s(r.get("countryOfCitizenship")),
            s(r.get("positionGroup")), s(r.get("detailedPosition")), s(r.get("foot")),
            as_int(r.get("heightCm")) or None, as_int(r.get("internationalCaps")),
            as_int(r.get("internationalGoals")), as_int(r.get("sourceLastSeason")) or None,
            s(r.get("identityConfidence"))
        ))
    cur.executemany("INSERT INTO profiles VALUES (?,?,?,?,?,?,?,?,?,?,?)", profile_insert)

    stats_seen = set()
    stat_insert = []
    for r in stats:
        pid = as_int(r.get("playerId"), -1)
        if pid not in player_ids or pid in stats_seen:
            continue
        stats_seen.add(pid)
        stat_insert.append((
            pid, as_int(r.get("appearances")), as_int(r.get("goals")), as_int(r.get("assists")),
            as_int(r.get("minutes")), as_int(r.get("uclAppearances")),
            as_int(r.get("big5Appearances")), as_int(r.get("topCompetitionAppearances")),
            as_int(r.get("coverageFirstYear")) or None, as_int(r.get("coverageLastYear")) or None,
            s(r.get("coverageClass"))
        ))
    cur.executemany("INSERT INTO player_stats VALUES (?,?,?,?,?,?,?,?,?,?,?)", stat_insert)

    comp_ids = set()
    comp_insert = []
    for r in competitions:
        cid = s(r.get("competitionId"))
        if not cid or cid in comp_ids:
            continue
        comp_ids.add(cid)
        comp_insert.append((
            cid, s(r.get("name")), s(r.get("type")), s(r.get("subType")),
            s(r.get("country")), s(r.get("confederation")),
            int(yes(r.get("isBig5"))), int(yes(r.get("isTopCompetition")))
        ))
    cur.executemany("INSERT INTO competitions VALUES (?,?,?,?,?,?,?,?)", comp_insert)
    con.commit()

    # Large relationship table: stream + SQLite upsert instead of Python O(N) dictionary.
    print("[03G.3] Clean player-club ilişkileri derleniyor...")
    rel_count_input = 0
    rel_valid_rows = 0
    batch = []
    upsert_rel = """
      INSERT INTO player_clubs(player_id,club_id,trust) VALUES (?,?,?)
      ON CONFLICT(player_id,club_id) DO UPDATE
      SET trust=MAX(trust,excluded.trust)
    """
    for r in csv_rows(D2_DIR / "canonical_careers_gameplay_guarded_v2.csv"):
        rel_count_input += 1
        if rel_count_input % 150000 == 0:
            print(f"[03G.3] Career relation: {rel_count_input:,}")
        if not yes(r.get("gameplayEligible03d1")):
            continue
        pid = as_int(r.get("canonicalPlayerId"), -1)
        key = s(r.get("canonicalClubKey"))
        if pid not in player_ids or key not in club_pk:
            continue
        trust = 2 if s(r.get("relationTrust03d1")).upper() == "HIGH" else 1
        batch.append((pid, club_pk[key], trust))
        rel_valid_rows += 1
        if len(batch) >= BATCH:
            cur.executemany(upsert_rel, batch)
            batch.clear()
    if batch:
        cur.executemany(upsert_rel, batch)
    con.commit()

    print("[03G.3] Player-club factual stats derleniyor...")
    batch = []
    for i, r in enumerate(csv_rows(G12_DIR / "player_stats_by_club_v3.csv"), 1):
        pid = as_int(r.get("playerId"), -1)
        key = s(r.get("canonicalClubKey"))
        if pid not in player_ids or key not in club_pk:
            continue
        batch.append((
            pid, club_pk[key], as_int(r.get("appearances")),
            as_int(r.get("goals")), as_int(r.get("assists")), as_int(r.get("minutes"))
        ))
        if len(batch) >= BATCH:
            cur.executemany("""
              INSERT INTO player_club_stats VALUES (?,?,?,?,?,?)
              ON CONFLICT(player_id,club_id) DO UPDATE SET
                appearances=appearances+excluded.appearances,
                goals=goals+excluded.goals,
                assists=assists+excluded.assists,
                minutes=minutes+excluded.minutes
            """, batch)
            batch.clear()
    if batch:
        cur.executemany("""
          INSERT INTO player_club_stats VALUES (?,?,?,?,?,?)
          ON CONFLICT(player_id,club_id) DO UPDATE SET
            appearances=appearances+excluded.appearances,
            goals=goals+excluded.goals,
            assists=assists+excluded.assists,
            minutes=minutes+excluded.minutes
        """, batch)
    con.commit()

    print("[03G.3] Player-competition factual stats derleniyor...")
    batch = []
    for r in csv_rows(G12_DIR / "player_stats_by_competition_v3.csv"):
        pid = as_int(r.get("playerId"), -1)
        cid = s(r.get("competitionId"))
        if pid not in player_ids or cid not in comp_ids:
            continue
        batch.append((
            pid, cid, as_int(r.get("appearances")), as_int(r.get("goals")),
            as_int(r.get("assists")), as_int(r.get("minutes"))
        ))
        if len(batch) >= BATCH:
            cur.executemany("""
              INSERT INTO player_competition_stats VALUES (?,?,?,?,?,?)
              ON CONFLICT(player_id,competition_id) DO UPDATE SET
                appearances=appearances+excluded.appearances,
                goals=goals+excluded.goals,
                assists=assists+excluded.assists,
                minutes=minutes+excluded.minutes
            """, batch)
            batch.clear()
    if batch:
        cur.executemany("""
          INSERT INTO player_competition_stats VALUES (?,?,?,?,?,?)
          ON CONFLICT(player_id,competition_id) DO UPDATE SET
            appearances=appearances+excluded.appearances,
            goals=goals+excluded.goals,
            assists=assists+excluded.assists,
            minutes=minutes+excluded.minutes
        """, batch)
    con.commit()

    print("[03G.3] Gameplay-normalized timeline derleniyor...")
    seq_by_player = defaultdict(int)
    batch = []
    timeline_input = 0
    timeline_kept = 0
    for r in csv_rows(G21_DIR / "career_spells_gameplay_normalized.csv"):
        timeline_input += 1
        if timeline_input % 50000 == 0:
            print(f"[03G.3] Timeline spell: {timeline_input:,}")
        if not yes(r.get("timelineGameplayEligibleV2")):
            continue
        pid = as_int(r.get("canonicalPlayerId"), -1)
        key = s(r.get("canonicalClubKey"))
        if pid not in player_ids or key not in club_pk:
            continue
        seq_by_player[pid] += 1
        batch.append((
            pid, seq_by_player[pid], club_pk[key],
            s(r.get("startDate")), s(r.get("endDate")),
            s(r.get("spellConfidence")), as_int(r.get("appearancesInsideSpell"))
        ))
        timeline_kept += 1
        if len(batch) >= BATCH:
            cur.executemany("INSERT INTO career_spells VALUES (?,?,?,?,?,?,?)", batch)
            batch.clear()
    if batch:
        cur.executemany("INSERT INTO career_spells VALUES (?,?,?,?,?,?,?)", batch)
    con.commit()

    print("[03G.3] Canonical club-to-club transfers derleniyor...")
    batch = []
    valid_transfer_event_ids = set()
    transfer_input = 0
    transfer_kept = 0
    for r in csv_rows(G2_DIR / "canonical_transfer_events.csv"):
        transfer_input += 1
        if transfer_input % 50000 == 0:
            print(f"[03G.3] Transfer event: {transfer_input:,}")
        if s(r.get("eventType")) != "CLUB_TO_CLUB":
            continue
        pid = as_int(r.get("canonicalPlayerId"), -1)
        fk = s(r.get("fromCanonicalClubKey"))
        tk = s(r.get("toCanonicalClubKey"))
        eid = s(r.get("eventId"))
        if pid not in player_ids or fk not in club_pk or tk not in club_pk or not eid:
            continue
        valid_transfer_event_ids.add(eid)
        batch.append((
            eid, pid, s(r.get("transferDate")), as_int(r.get("transferYear")),
            club_pk[fk], club_pk[tk], s(r.get("eventTrust"))
        ))
        transfer_kept += 1
        if len(batch) >= BATCH:
            cur.executemany("INSERT OR IGNORE INTO transfers VALUES (?,?,?,?,?,?,?)", batch)
            batch.clear()
    if batch:
        cur.executemany("INSERT OR IGNORE INTO transfers VALUES (?,?,?,?,?,?,?)", batch)
    con.commit()

    # Pools.
    print("[03G.3] Mode pool'ları derleniyor...")
    player_pool_rows = set()
    club_pool_rows = set()
    pool_integrity = []

    for pool_name, ids in pools.items():
        if pool_name == "guess_the_player_clubs":
            compiled = 0
            missing = 0
            for key in ids:
                if key in club_pk:
                    club_pool_rows.add((pool_name, club_pk[key]))
                    compiled += 1
                else:
                    missing += 1
            pool_integrity.append({
                "pool": pool_name, "inputCount": len(ids), "compiledCount": compiled,
                "shadowIdsRemoved": 0, "missingRefsRemoved": missing
            })
            continue

        shadow_removed = 0
        missing = 0
        compiled = 0
        for raw in ids:
            pid = as_int(raw, -1)
            if pid in shadow_map:
                shadow_removed += 1
                continue
            if pid not in player_ids:
                missing += 1
                continue
            player_pool_rows.add((pool_name, pid))
            compiled += 1
        pool_integrity.append({
            "pool": pool_name, "inputCount": len(ids), "compiledCount": compiled,
            "shadowIdsRemoved": shadow_removed, "missingRefsRemoved": missing
        })

    for pid, r in player_by_id.items():
        if pid in shadow_map:
            continue
        for flag, pool_name in (
            ("playableV3", "playable_v3"),
            ("casualV3", "casual_v3"),
            ("normalV3", "normal_v3"),
            ("hardV3", "hard_v3"),
            ("visualPriorityV3", "visual_priority_v3"),
        ):
            if yes(r.get(flag)):
                player_pool_rows.add((pool_name, pid))

    for r in puzzle_candidates:
        pid = as_int(r.get("playerId"), -1)
        if pid not in player_ids or pid in shadow_map:
            continue
        quality = s(r.get("timelineQuality"))
        player_pool_rows.add(("career_puzzle_all_v2", pid))
        if quality == "A_TRUSTED":
            player_pool_rows.add(("career_puzzle_a_trusted_v2", pid))
        if quality in {"A_TRUSTED", "B_PLAYABLE"}:
            player_pool_rows.add(("career_puzzle_production_v2", pid))

    cur.executemany(
        "INSERT OR IGNORE INTO player_pools VALUES (?,?)",
        sorted(player_pool_rows)
    )
    cur.executemany(
        "INSERT OR IGNORE INTO club_pools VALUES (?,?)",
        sorted(club_pool_rows)
    )

    event_pool_rows = [
        ("transfer_detective_normal_v3", s(r.get("eventId")))
        for r in transfer_detective
        if s(r.get("eventId")) in valid_transfer_event_ids
    ]
    cur.executemany(
        "INSERT OR IGNORE INTO event_pools VALUES (?,?)",
        event_pool_rows
    )

    # Indexes only after bulk load.
    print("[03G.3] Indexler oluşturuluyor...")
    cur.executescript("""
    CREATE INDEX idx_players_name ON players(name COLLATE NOCASE);
    CREATE INDEX idx_players_rank ON players(selection_rank);
    CREATE INDEX idx_clubs_name ON clubs(name COLLATE NOCASE);
    CREATE INDEX idx_player_clubs_club_player ON player_clubs(club_id, player_id);
    CREATE INDEX idx_player_club_stats_club ON player_club_stats(club_id, player_id);
    CREATE INDEX idx_comp_stats_comp ON player_competition_stats(competition_id, player_id);
    CREATE INDEX idx_spells_player_start ON career_spells(player_id, start_date);
    CREATE INDEX idx_spells_club_player ON career_spells(club_id, player_id);
    CREATE INDEX idx_transfers_player_date ON transfers(player_id, transfer_date);
    CREATE INDEX idx_transfers_from_to ON transfers(from_club_id, to_club_id);
    """)

    metadata = {
        "schema_version": "3-preview",
        "compiler_step": "03G.3",
        "runtime_mutated": "false",
    }
    cur.executemany("INSERT INTO metadata VALUES (?,?)", metadata.items())
    con.commit()

    # QA after build. Foreign-key check works even though enforcement was disabled during bulk insert.
    print("[03G.3] QA çalıştırılıyor...")
    qa = []
    def check(check_id, rule, ok, detail, severity="BLOCKER"):
        qa.append({
            "check": check_id,
            "status": "PASS" if ok else ("WARN" if severity == "WARN" else "FAIL"),
            "severity": severity,
            "rule": rule,
            "detail": detail,
        })

    fk_errors = cur.execute("PRAGMA foreign_key_check").fetchall()
    check("QA-01", "SQLite foreign keys are valid", len(fk_errors) == 0, f"errors={len(fk_errors)}")

    dup_players = cur.execute(
        "SELECT COUNT(*) FROM (SELECT id,COUNT(*) c FROM players GROUP BY id HAVING c>1)"
    ).fetchone()[0]
    check("QA-02", "Player IDs are unique", dup_players == 0, f"duplicates={dup_players}")

    bad_gameplay_clubs = cur.execute("""
      SELECT COUNT(*) FROM clubs
      WHERE gameplay_eligible=1 AND (
        entity_type <> 'SENIOR' OR
        lower(name) IN ('retired','without club','career break','unknown','free agent','unattached') OR
        name GLOB 'Club [0-9]*'
      )
    """).fetchone()[0]
    check("QA-03", "Gameplay clubs contain no placeholder/pseudo/development identities",
          bad_gameplay_clubs == 0, f"bad={bad_gameplay_clubs}")

    shadow_in_pools = cur.execute("""
      SELECT COUNT(*) FROM player_pools pp
      JOIN players p ON p.id=pp.player_id
      WHERE p.is_shadow=1
    """).fetchone()[0]
    check("QA-04", "Shadow duplicate players are absent from runtime pools",
          shadow_in_pools == 0, f"shadowPoolRows={shadow_in_pools}")

    invalid_spells = cur.execute("""
      SELECT COUNT(*) FROM career_spells cs
      JOIN clubs c ON c.id=cs.club_id
      WHERE c.gameplay_eligible<>1 OR c.entity_type<>'SENIOR'
         OR (cs.start_date<>'' AND cs.end_date<>'' AND cs.start_date>cs.end_date)
    """).fetchone()[0]
    check("QA-05", "Runtime career spells use clean senior clubs and valid chronology",
          invalid_spells == 0, f"bad={invalid_spells}")

    shared_bad = cur.execute("""
      SELECT COUNT(*) FROM player_pools pp
      JOIN players p ON p.id=pp.player_id
      WHERE pp.pool_name='shared_xi_answer' AND p.answer_eligible<>1
    """).fetchone()[0]
    check("QA-06", "Shared XI answer pool contains only answer-eligible players",
          shared_bad == 0, f"bad={shared_bad}")

    odd_bad = cur.execute("""
      SELECT COUNT(*) FROM player_pools pp
      JOIN (
        SELECT player_id,COUNT(*) club_count FROM player_clubs GROUP BY player_id
      ) x ON x.player_id=pp.player_id
      WHERE pp.pool_name='odd_club_normal' AND x.club_count<3
    """).fetchone()[0]
    check("QA-07", "Odd Club pool players have >=3 clean clubs",
          odd_bad == 0, f"bad={odd_bad}")

    schema_sql = "\n".join(
        (r[0] or "") for r in cur.execute(
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL"
        ).fetchall()
    ).casefold()
    forbidden_hits = [term for term in FORBIDDEN_SCHEMA_TERMS if term in schema_sql]
    check("QA-08", "Runtime schema has no market-value/image/source-url/fee/agent fields",
          len(forbidden_hits) == 0, "hits=" + "|".join(forbidden_hits))

    admin_runtime = cur.execute("""
      SELECT COUNT(*) FROM career_spells
      WHERE start_date<>'' AND end_date<>''
        AND julianday(end_date)-julianday(start_date) <= 45
        AND appearances=0
    """).fetchone()[0]
    check("QA-09", "Short zero-appearance administrative spells are excluded",
          admin_runtime == 0, f"rows={admin_runtime}")

    career_prod_count = cur.execute(
        "SELECT COUNT(*) FROM player_pools WHERE pool_name='career_puzzle_production_v2'"
    ).fetchone()[0]
    check("QA-10", "Career Puzzle production preview has useful scale",
          career_prod_count >= 5000, f"players={career_prod_count}", severity="WARN")

    transfer_event_count = cur.execute(
        "SELECT COUNT(*) FROM event_pools WHERE pool_name='transfer_detective_normal_v3'"
    ).fetchone()[0]
    check("QA-11", "Transfer Detective event pool has useful scale",
          transfer_event_count >= 3000, f"events={transfer_event_count}", severity="WARN")

    integrity = cur.execute("PRAGMA integrity_check").fetchone()[0]
    check("QA-12", "SQLite integrity_check is ok", integrity == "ok", f"result={integrity}")

    # Representative query benchmark.
    benchmark_rows = []
    def bench(name, sql, params, loops=100):
        t0 = time.perf_counter()
        rows_seen = 0
        for _ in range(loops):
            result = cur.execute(sql, params).fetchall()
            rows_seen += len(result)
        elapsed = (time.perf_counter() - t0) * 1000
        benchmark_rows.append({
            "query": name, "loops": loops, "totalMs": round(elapsed,2),
            "avgMs": round(elapsed/loops,4), "rowsSeen": rows_seen
        })

    top_clubs = [
        r[0] for r in cur.execute(
            "SELECT id FROM clubs WHERE gameplay_eligible=1 ORDER BY popularity_seed DESC,id LIMIT 6"
        ).fetchall()
    ]
    if len(top_clubs) >= 2:
        bench(
            "shared_xi_intersection",
            """SELECT p.id,p.name FROM player_clubs a
               JOIN player_clubs b ON a.player_id=b.player_id
               JOIN players p ON p.id=a.player_id
               WHERE a.club_id=? AND b.club_id=? AND p.is_shadow=0
               LIMIT 100""",
            (top_clubs[0], top_clubs[1])
        )
    bench(
        "player_prefix_search",
        "SELECT id,name FROM players WHERE name LIKE ? AND is_shadow=0 ORDER BY selection_rank LIMIT 30",
        ("Ro%",)
    )
    if top_clubs:
        bench(
            "club_players",
            """SELECT p.id,p.name FROM player_clubs pc
               JOIN players p ON p.id=pc.player_id
               WHERE pc.club_id=? AND p.is_shadow=0
               ORDER BY p.selection_rank LIMIT 100""",
            (top_clubs[0],)
        )
    timeline_pid = cur.execute(
        "SELECT player_id FROM career_spells GROUP BY player_id HAVING COUNT(*)>=3 LIMIT 1"
    ).fetchone()
    if timeline_pid:
        bench(
            "career_timeline",
            """SELECT cs.sequence,c.name,cs.start_date,cs.end_date
               FROM career_spells cs JOIN clubs c ON c.id=cs.club_id
               WHERE cs.player_id=? ORDER BY cs.sequence""",
            (timeline_pid[0],)
        )

    con.execute("PRAGMA optimize")
    con.commit()

    tables = [
        "players","clubs","player_clubs","profiles","player_stats",
        "player_club_stats","competitions","player_competition_stats",
        "career_spells","transfers","player_pools","club_pools","event_pools"
    ]
    table_counts = [
        {"table": table, "rows": cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]}
        for table in tables
    ]

    compiled_pool_counts = [
        {"pool": r[0], "entityType":"PLAYER", "rows":r[1]}
        for r in cur.execute(
            "SELECT pool_name,COUNT(*) FROM player_pools GROUP BY pool_name ORDER BY pool_name"
        ).fetchall()
    ]
    compiled_pool_counts += [
        {"pool": r[0], "entityType":"CLUB", "rows":r[1]}
        for r in cur.execute(
            "SELECT pool_name,COUNT(*) FROM club_pools GROUP BY pool_name ORDER BY pool_name"
        ).fetchall()
    ]
    compiled_pool_counts += [
        {"pool": r[0], "entityType":"EVENT", "rows":r[1]}
        for r in cur.execute(
            "SELECT pool_name,COUNT(*) FROM event_pools GROUP BY pool_name ORDER BY pool_name"
        ).fetchall()
    ]

    con.close()

    # Size + compression estimate.
    db_size = DB_PATH.stat().st_size
    print(f"[03G.3] SQLite ham boyut: {db_size/1024/1024:.2f} MB")
    compressed_size = compressed_estimate(DB_PATH)
    sha = file_sha256(DB_PATH)

    size_rows = []
    assets_dir = ROOT / "assets" / "data"
    if assets_dir.exists():
        for name in (
            "players.json","players_min.json","clubs.json","clubs_min.json",
            "coaches_min.json","famous_transfers.json"
        ):
            p = assets_dir / name
            if p.exists():
                size_rows.append({
                    "artifact":f"assets/data/{name}",
                    "bytes":p.stat().st_size,
                    "mb":round(p.stat().st_size/1024/1024,2),
                    "kind":"CURRENT_ASSET"
                })
    size_rows += [
        {
            "artifact":"03g3/linkball_runtime_v3.preview.sqlite",
            "bytes":db_size, "mb":round(db_size/1024/1024,2), "kind":"RUNTIME_PREVIEW"
        },
        {
            "artifact":"03g3/sqlite_deflate_estimate.zip",
            "bytes":compressed_size, "mb":round(compressed_size/1024/1024,2), "kind":"COMPRESSED_ESTIMATE"
        }
    ]

    write_csv("qa_checks.csv", qa)
    write_csv("query_benchmark.csv", benchmark_rows)
    write_csv("runtime_table_counts.csv", table_counts)
    write_csv("compiled_pool_counts.csv", compiled_pool_counts)
    write_csv("pool_integrity.csv", pool_integrity)
    write_csv("bundle_size_report.csv", size_rows)

    blocker_failures = [r for r in qa if r["status"] == "FAIL"]
    warnings = [r for r in qa if r["status"] == "WARN"]

    migration_rows = [
        {
            "phase":"RUNTIME-01","status":"READY_NEXT","scope":"DataRepository / loader",
            "action":"Load SQLite behind a feature flag while retaining current JSON loader for parity testing."
        },
        {
            "phase":"RUNTIME-02","status":"READY_NEXT",
            "scope":"Shared XI / Chain / Odd Club / Guess The Player",
            "action":"Switch prompt pools and club intersections to compiled runtime tables."
        },
        {
            "phase":"RUNTIME-03","status":"READY_AFTER_COMPONENT_TEST",
            "scope":"Career Puzzle / Player Journey / Transfer Detective",
            "action":"Use normalized career_spells and canonical transfer events."
        },
        {
            "phase":"RUNTIME-04","status":"READY_AFTER_SCORING_DESIGN",
            "scope":"Build XI / Mystery / Grid",
            "action":"Use factual profile/position/stats and remove peakMarketValue selection/hints."
        },
        {
            "phase":"RUNTIME-05","status":"STILL_NEEDS_RULE_REDESIGN",
            "scope":"Higher Lower / Blind Ranking",
            "action":"Define factual comparison criteria + coverage rules; do not port market-value gameplay."
        },
        {
            "phase":"RUNTIME-06","status":"LATER","scope":"Packaging",
            "action":"After parity, remove duplicate large JSON assets from pubspec/AAB and ship compiled SQLite."
        },
    ]
    write_csv("runtime_migration_plan.csv", migration_rows)

    manifest = {
        "schemaVersion":3,
        "preview":True,
        "database":{
            "file":DB_PATH.name,
            "sha256":sha,
            "bytes":db_size,
            "mb":round(db_size/1024/1024,2),
            "deflateEstimateBytes":compressed_size,
            "deflateEstimateMb":round(compressed_size/1024/1024,2)
        },
        "tables":{r["table"]:r["rows"] for r in table_counts},
        "qa":{
            "blockerFailures":len(blocker_failures),
            "warnings":len(warnings),
            "status":"PASS_FOR_RUNTIME_INTEGRATION_PREVIEW" if not blocker_failures else "BLOCKED"
        },
        "forbiddenRuntimeFields":list(FORBIDDEN_SCHEMA_TERMS),
        "principles":[
            "Database players remain broad; random question pools are curated.",
            "Shadow duplicates remain stored but are suppressed from runtime pools/search.",
            "Only clean senior relationships are compiled into player_clubs.",
            "Only gameplay-normalized career spells are compiled.",
            "Transfer fee, market value, source URLs and image URLs are absent.",
            "The database stays under reports until runtime feature-flag integration."
        ]
    }
    (OUT_DIR / "runtime_manifest.preview.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    gates = [
        {
            "gate":"G3-01","status":"PASS" if not blocker_failures else "FAIL",
            "rule":"All blocking runtime QA checks pass",
            "detail":f"failures={len(blocker_failures)}; warnings={len(warnings)}"
        },
        {
            "gate":"G3-02","status":"PASS",
            "rule":"SQLite preview is generated outside assets/data",
            "detail":str(DB_PATH.relative_to(ROOT))
        },
        {
            "gate":"G3-03","status":"PASS" if not forbidden_hits else "FAIL",
            "rule":"Compiled runtime schema contains no forbidden market/image/url/fee fields",
            "detail":"hits="+"|".join(forbidden_hits)
        },
        {
            "gate":"G3-04","status":"PASS" if integrity=="ok" and len(fk_errors)==0 else "FAIL",
            "rule":"SQLite integrity and foreign-key QA pass",
            "detail":f"integrity={integrity}; fkErrors={len(fk_errors)}"
        },
        {
            "gate":"G3-05","status":"PASS",
            "rule":"Runtime assets remain unchanged",
            "detail":"No file under assets/data is written or deleted"
        },
    ]
    write_csv("migration_gates.csv", gates)

    elapsed = time.perf_counter() - started
    summary = {
        "step":"03G.3",
        "runtimeChanged":False,
        "qaStatus":manifest["qa"]["status"],
        "blockerFailures":len(blocker_failures),
        "warnings":len(warnings),
        "databaseSizeMb":round(db_size/1024/1024,2),
        "databaseCompressedEstimateMb":round(compressed_size/1024/1024,2),
        "compileSeconds":round(elapsed,2),
        "tableCounts":manifest["tables"],
        "careerPuzzleProductionPool":career_prod_count,
        "transferDetectiveEventPool":transfer_event_count,
        "benchmark":benchmark_rows,
        "nextRecommendedStep":"04_RUNTIME_SQLITE_INTEGRATION_WITH_FEATURE_FLAG"
    }
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03G.3

Final data QA and runtime SQLite compiler preview.

QA status: **{manifest['qa']['status']}**

- Blocking failures: {len(blocker_failures)}
- Warnings: {len(warnings)}
- Compile time: {elapsed:.1f} sec
- SQLite preview size: {db_size/1024/1024:.2f} MB
- Deflate estimate: {compressed_size/1024/1024:.2f} MB
- Players: {manifest['tables']['players']:,}
- Clubs: {manifest['tables']['clubs']:,}
- Clean player-club relations: {manifest['tables']['player_clubs']:,}
- Career spells: {manifest['tables']['career_spells']:,}
- Canonical club-to-club transfers: {manifest['tables']['transfers']:,}
- Career Puzzle production pool: {career_prod_count:,}
- Transfer Detective event pool: {transfer_event_count:,}

This is still a preview under `reports/data_platform_v3/03g3`.
`assets/data` is untouched.

Next step after PASS:
SQLite loader + feature flag + parity tests. Only after parity should duplicate large
JSON assets be removed from the production bundle.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03G.3] QA: {manifest['qa']['status']}")
    print(f"[03G.3] Blocker: {len(blocker_failures)} | Warning: {len(warnings)}")
    print(f"[03G.3] SQLite: {db_size/1024/1024:.2f} MB")
    print(f"[03G.3] Deflate estimate: {compressed_size/1024/1024:.2f} MB")
    for r in table_counts:
        if r["table"] in {"players","clubs","player_clubs","career_spells","transfers","player_pools"}:
            print(f"[03G.3] {r['table']}: {r['rows']:,}")
    print(f"[03G.3] Sure: {elapsed:.1f} sn")
    print(f"[03G.3] Rapor: {OUT_DIR}")
    print("[03G.3] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
