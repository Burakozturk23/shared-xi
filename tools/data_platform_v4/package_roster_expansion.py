#!/usr/bin/env python3
"""Package a reviewed first-division roster snapshot as hash-pinned evidence."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "assets/runtime/linkball_game_data_v4.sqlite"
ALLOWED_LEAGUES = {
    "tur.1", "eng.1", "esp.1", "ita.1", "ger.1", "fra.1", "ned.1",
    "sco.1", "por.1", "bel.1", "aut.1", "usa.1", "mex.1", "arg.1",
    "bra.1", "ksa.1", "jpn.1",
}
REVISION = "v4-2026-09-29.2"
MAX_BIRTH_YEAR = 2010  # 16+ on the 2026-09-29 snapshot date


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def package(rows_path: Path, output_dir: Path) -> dict:
    rows = json.loads(rows_path.read_text(encoding="utf-8"))
    selected = []
    rejected = Counter()
    for row in rows:
        if row.get("league") not in ALLOWED_LEAGUES:
            rejected["league_out_of_scope"] += 1
            continue
        status = row.get("status")
        if status not in {"new_player", "add_link"}:
            rejected[status or "missing_status"] += 1
            continue
        if status == "new_player":
            if not row.get("birthYear") or int(row["birthYear"]) > MAX_BIRTH_YEAR:
                rejected["underage_or_missing_birth_year"] += 1
                continue
            for field in ("sourcePlayerId", "name", "nationality", "clubId", "club"):
                if not row.get(field):
                    raise ValueError(f"incomplete new-player row: {field}: {row}")
        else:
            for field in ("sourcePlayerId", "playerId", "clubId", "club"):
                if row.get(field) in (None, ""):
                    raise ValueError(f"incomplete add-link row: {field}: {row}")
        selected.append(row)

    source_dest = defaultdict(set)
    for row in selected:
        source_dest[row["sourcePlayerId"]].add(row["clubId"])
    conflicts = {sid: clubs for sid, clubs in source_dest.items() if len(clubs) > 1}
    if conflicts:
        raise ValueError(f"source player appears in multiple accepted clubs: {list(conflicts)[:5]}")

    new_players = {row["sourcePlayerId"] for row in selected if row["status"] == "new_player"}
    links = {(row["sourcePlayerId"], row["clubId"]) for row in selected}
    if len(links) != len(selected):
        raise ValueError("duplicate accepted source-player/club row")

    con = sqlite3.connect(DB)
    try:
        existing_ids = {row[0] for row in con.execute("SELECT id FROM players")}
        for source_id in new_players:
            new_id = 3_000_000_000 + int(source_id)
            if new_id in existing_ids:
                raise ValueError(f"new player ID collision: {new_id}")
        for row in selected:
            if row["status"] == "add_link" and not con.execute(
                "SELECT 1 FROM players WHERE id=?", (row["playerId"],)
            ).fetchone():
                raise ValueError(f"missing existing player for add-link: {row}")
            if not con.execute(
                "SELECT 1 FROM clubs WHERE id=? AND name=?", (row["clubId"], row["club"])
            ).fetchone():
                raise ValueError(f"canonical club mismatch: {row}")
    finally:
        con.close()

    output_dir.mkdir(parents=True, exist_ok=True)
    for part in output_dir.glob("roster-expansion-2026-09-29-*.json"):
        part.unlink()
    by_league = defaultdict(list)
    for row in sorted(selected, key=lambda r: (r["league"], r["clubId"], int(r["sourcePlayerId"]))):
        by_league[row["league"]].append(row)
    parts = []
    for league in sorted(by_league):
        path = output_dir / f"roster-expansion-2026-09-29-{league}.json"
        path.write_text(json.dumps(by_league[league], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        parts.append({"file": path.name, "sha256": digest(path), "rows": len(by_league[league]), "league": league})

    synced = sorted({row["lastSyncedAt"] for row in selected if row.get("lastSyncedAt")})
    review = {
        "id": REVISION,
        "reviewedUtc": datetime.now(timezone.utc).isoformat(),
        "baseSha256": digest(DB),
        "scope": "Current male first-division rosters for 17 recognizable leagues; add complete new identities and missing current club links. Exclude cups, lower divisions, youth/reserve records, unresolved identities, and players born after 2010.",
        "source": {
            "provider": "worldcup26.ir",
            "endpoint": "/get/soccer/{league}/clubs/{clubId}",
            "leagues": sorted(ALLOWED_LEAGUES),
            "lastSyncedAtMin": synced[0] if synced else None,
            "lastSyncedAtMax": synced[-1] if synced else None,
        },
        "newPlayers": len(new_players),
        "newLinks": len(links),
        "rows": len(selected),
        "rejected": dict(rejected),
        "parts": parts,
    }
    manifest_path = output_dir / "roster-expansion-2026-09-29.json"
    manifest_path.write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"review": str(manifest_path), "newPlayers": len(new_players), "newLinks": len(links), "rows": len(selected), "rejected": rejected}, ensure_ascii=False, indent=2))
    return review


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("rows", type=Path)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "tools/data_platform_v4/patches")
    args = parser.parse_args()
    package(args.rows, args.output_dir)
