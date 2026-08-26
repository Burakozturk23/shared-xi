#!/usr/bin/env python3
"""
Shared XI — Faz B dataset builder

Girdi (tools/build_dataset/input/):
  players.csv | players.parquet   (TM-datasets / Kaggle player-scores)
  clubs.csv   | clubs.parquet
  transfers.csv | transfers.parquet   (opsiyonel ama onerilir)
  coaches.csv                          (opsiyonel PlayerElo / kendi list)
  legacy_players.json                  (senin mevcut players.json kopyasi)
  legacy_clubs.json                    (senin mevcut clubs.json kopyasi)

Cikti (tools/build_dataset/out/ → assets/data/ kopyalanir):
  meta.json, clubs_min.json, players_min.json, coaches_min.json

Kullanim:
  cd tools/build_dataset
  python3 build.py
  python3 build.py --prefer-min-meta   # meta.preferMin=true yazar
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
INPUT = ROOT / "input"
PATCHES = ROOT / "patches"
OUT = ROOT / "out"

POSITION_MAP = {
    "goalkeeper": "Goalkeeper",
    "gk": "Goalkeeper",
    "defender": "Defender",
    "defence": "Defender",
    "def": "Defender",
    "midfield": "Midfield",
    "midfielder": "Midfield",
    "mid": "Midfield",
    "attack": "Attack",
    "attacker": "Attack",
    "forward": "Attack",
    "fw": "Attack",
    "striker": "Attack",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def load_table(name: str):
    """CSV veya parquet yukle. Yoksa None."""
    for ext in (".csv", ".parquet"):
        path = INPUT / f"{name}{ext}"
        if not path.exists():
            continue
        if ext == ".csv":
            with path.open(newline="", encoding="utf-8") as f:
                rows = list(csv.DictReader(f))
            log(f"  loaded {path.name}: {len(rows)} rows")
            return rows
        try:
            import pandas as pd  # optional

            df = pd.read_parquet(path)
            rows = df.to_dict(orient="records")
            log(f"  loaded {path.name}: {len(rows)} rows")
            return rows
        except Exception as e:
            log(f"  parquet read failed {path}: {e}")
    return None


def load_json(name: str):
    path = INPUT / name
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    log(f"  loaded {path.name}: {len(data) if isinstance(data, list) else 'obj'}")
    return data


def norm_pos(raw: str | None) -> str:
    if not raw:
        return "Midfield"
    s = str(raw).strip().lower()
    for k, v in POSITION_MAP.items():
        if k in s:
            return v
    # sub_position like "Centre-Forward"
    if "keep" in s:
        return "Goalkeeper"
    if any(x in s for x in ("back", "defence", "defender")):
        return "Defender"
    if any(x in s for x in ("mid",)):
        return "Midfield"
    if any(x in s for x in ("wing", "forward", "attack", "strik")):
        return "Attack"
    return "Midfield"


def to_int(v):
    if v is None or v == "" or str(v).lower() in ("nan", "none", "null"):
        return None
    try:
        return int(float(v))
    except Exception:
        return None


def to_float(v):
    if v is None or v == "" or str(v).lower() in ("nan", "none", "null"):
        return None
    try:
        return float(v)
    except Exception:
        return None


def first_key(row: dict, keys: list[str]):
    for k in keys:
        if k in row and row[k] is not None and str(row[k]).strip() != "":
            return row[k]
    return None


def build_clubs(tm_clubs, legacy_clubs) -> list[dict]:
    by_id: dict[int, dict] = {}

    if legacy_clubs:
        for c in legacy_clubs:
            cid = to_int(c.get("id"))
            if cid is None:
                continue
            by_id[cid] = {
                "id": cid,
                "name": (c.get("name") or "").strip(),
                "country": (c.get("country") or "").strip(),
                "league": (c.get("league") or "").strip(),
                "badgeKey": f"c_{cid}",
                "color": None,
            }

    if tm_clubs:
        for c in tm_clubs:
            cid = to_int(first_key(c, ["club_id", "id"]))
            if cid is None:
                continue
            name = str(first_key(c, ["name", "club_name"]) or "").strip()
            country = str(
                first_key(c, ["country", "club_country", "country_name"]) or ""
            ).strip()
            league = str(
                first_key(c, ["domestic_competition_id", "league", "competition_id"])
                or ""
            ).strip()
            prev = by_id.get(cid)
            by_id[cid] = {
                "id": cid,
                "name": name or (prev or {}).get("name") or f"Club {cid}",
                "country": country or (prev or {}).get("country") or "",
                "league": (prev or {}).get("league") or league,
                "badgeKey": f"c_{cid}",
                "color": (prev or {}).get("color"),
            }

    clubs = sorted(by_id.values(), key=lambda x: x["id"])
    log(f"  clubs_min: {len(clubs)}")
    return clubs


def build_club_ids_from_transfers(transfers) -> dict[int, set[int]]:
    m: dict[int, set[int]] = defaultdict(set)
    if not transfers:
        return m
    for t in transfers:
        pid = to_int(first_key(t, ["player_id", "playerid"]))
        if pid is None:
            continue
        for k in ("from_club_id", "to_club_id", "club_id", "from_club", "to_club"):
            cid = to_int(t.get(k)) if k in t else None
            if cid is not None and cid > 0:
                m[pid].add(cid)
    log(f"  transfer club links: {len(m)} players")
    return m


def build_players(tm_players, legacy_players, transfer_map) -> list[dict]:
    legacy_by_id: dict[int, dict] = {}
    if legacy_players:
        for p in legacy_players:
            pid = to_int(p.get("id"))
            if pid is not None:
                legacy_by_id[pid] = p

    # alias patches
    alias_patches: dict[str, list[str]] = {}
    ap = PATCHES / "aliases.json"
    if ap.exists():
        alias_patches = json.loads(ap.read_text(encoding="utf-8"))
        log(f"  alias patches: {len(alias_patches)}")

    out: dict[int, dict] = {}

    # 1) TM players base
    if tm_players:
        for p in tm_players:
            pid = to_int(first_key(p, ["player_id", "id"]))
            if pid is None:
                continue
            name = str(first_key(p, ["name", "player_name", "pretty_name"]) or "").strip()
            if not name:
                continue
            country = first_key(
                p,
                [
                    "country_of_citizenship",
                    "country",
                    "nationality",
                    "citizen_of",
                ],
            )
            countries = []
            if country:
                countries = [str(country).strip()]
            # sometimes multiple
            if isinstance(country, str) and "," in country:
                countries = [x.strip() for x in country.split(",") if x.strip()]

            pos = norm_pos(
                str(first_key(p, ["position", "sub_position", "player_position"]) or "")
            )
            current = to_int(first_key(p, ["current_club_id", "club_id"]))

            club_ids = set(transfer_map.get(pid, set()))
            if current and current > 0:
                club_ids.add(current)

            leg = legacy_by_id.get(pid)
            if leg:
                for c in leg.get("clubs") or leg.get("clubIds") or []:
                    ci = to_int(c)
                    if ci:
                        club_ids.add(ci)
                for a in leg.get("aliases") or []:
                    pass  # merge below
                if not countries and leg.get("countries"):
                    countries = list(leg["countries"])

            aliases = []
            if leg:
                aliases = [str(a) for a in (leg.get("aliases") or [])][:8]
            if str(pid) in alias_patches:
                for a in alias_patches[str(pid)]:
                    if a not in aliases:
                        aliases.append(a)

            out[pid] = {
                "id": pid,
                "name": name,
                "countries": countries,
                "position": pos,
                "clubIds": sorted(club_ids),
                "aliases": aliases[:8],
                "avatarKey": f"p_{pid}",
                "rating": None,
            }

    # 2) Legacy-only players (TM'de yoksa)
    for pid, leg in legacy_by_id.items():
        if pid in out:
            # merge club ids only
            s = set(out[pid]["clubIds"])
            for c in leg.get("clubs") or leg.get("clubIds") or []:
                ci = to_int(c)
                if ci:
                    s.add(ci)
            out[pid]["clubIds"] = sorted(s)
            continue
        name = (leg.get("name") or "").strip()
        if not name:
            continue
        clubs = []
        for c in leg.get("clubs") or leg.get("clubIds") or []:
            ci = to_int(c)
            if ci:
                clubs.append(ci)
        out[pid] = {
            "id": pid,
            "name": name,
            "countries": list(leg.get("countries") or []),
            "position": norm_pos(leg.get("position")),
            "clubIds": sorted(set(clubs)),
            "aliases": [str(a) for a in (leg.get("aliases") or [])][:8],
            "avatarKey": f"p_{pid}",
            "rating": None,
        }

    players = sorted(out.values(), key=lambda x: x["id"])
    with_clubs = sum(1 for p in players if p["clubIds"])
    log(f"  players_min: {len(players)} (with clubIds: {with_clubs})")
    return players


def build_coaches(rows) -> list[dict]:
    if not rows:
        # minimal seed so app always has coaches_min
        return [
            {
                "id": "coach_pep",
                "name": "Pep Guardiola",
                "countries": ["Spain"],
                "clubIds": [131, 281, 583],
                "aliases": ["Guardiola", "Pep"],
                "avatarKey": None,
                "rating": None,
            },
            {
                "id": "coach_mourinho",
                "name": "Jose Mourinho",
                "countries": ["Portugal"],
                "clubIds": [631, 418, 506],
                "aliases": ["Mourinho"],
                "avatarKey": None,
                "rating": None,
            },
        ]

    out = []
    for i, r in enumerate(rows):
        name = str(first_key(r, ["name", "coach_name", "player_name"]) or "").strip()
        if not name:
            continue
        cid = str(first_key(r, ["id", "coach_id"]) or f"coach_{i}")
        country = first_key(r, ["country", "nationality", "countries"])
        countries = []
        if isinstance(country, list):
            countries = [str(x) for x in country]
        elif country:
            countries = [str(country)]
        club_ids = []
        raw_clubs = first_key(r, ["clubIds", "clubs", "club_id"])
        if isinstance(raw_clubs, list):
            club_ids = [to_int(x) for x in raw_clubs if to_int(x)]
        elif to_int(raw_clubs):
            club_ids = [to_int(raw_clubs)]
        rating = to_float(first_key(r, ["rating", "elo", "elo_rating"]))
        out.append(
            {
                "id": cid,
                "name": name,
                "countries": countries,
                "clubIds": club_ids,
                "aliases": [],
                "avatarKey": None,
                "rating": rating,
            }
        )
    log(f"  coaches_min: {len(out)}")
    return out


def apply_elo_ratings(players: list[dict], elo_rows) -> None:
    if not elo_rows:
        return

    def norm(s: str) -> str:
        s = s.lower().strip()
        s = re.sub(r"[^a-z0-9 ]", "", s)
        return re.sub(r"\s+", " ", s)

    by_name: dict[str, float] = {}
    for r in elo_rows:
        name = first_key(r, ["name", "player_name", "player"])
        rating = to_float(first_key(r, ["rating", "elo", "elo_rating", "value"]))
        if name and rating:
            by_name[norm(str(name))] = rating

    hit = 0
    for p in players:
        r = by_name.get(norm(p["name"]))
        if r is not None:
            p["rating"] = r
            hit += 1
    log(f"  elo matched: {hit}/{len(players)}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--prefer-min-meta",
        action="store_true",
        help="meta.json preferMin=true (sadece min veriyle calistir)",
    )
    args = parser.parse_args()

    INPUT.mkdir(parents=True, exist_ok=True)
    PATCHES.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    log("=== Shared XI Faz B build ===")
    log(f"input: {INPUT}")

    tm_players = load_table("players")
    tm_clubs = load_table("clubs")
    transfers = load_table("transfers")
    coaches_rows = load_table("coaches")
    elo_rows = load_table("playerelo") or load_table("elo")

    legacy_players = load_json("legacy_players.json")
    legacy_clubs = load_json("legacy_clubs.json")

    if not tm_players and not legacy_players:
        log("HATA: input/ icinde players.csv veya legacy_players.json yok.")
        log("Bak: README_FAZ_B.md")
        sys.exit(1)

    transfer_map = build_club_ids_from_transfers(transfers)
    clubs = build_clubs(tm_clubs, legacy_clubs)
    players = build_players(tm_players, legacy_players, transfer_map)
    apply_elo_ratings(players, elo_rows)
    coaches = build_coaches(coaches_rows)

    meta = {
        "schemaVersion": 1,
        "dataVersion": __import__("datetime").date.today().isoformat(),
        "playerCount": len(players),
        "clubCount": len(clubs),
        "coachCount": len(coaches),
        "preferMin": bool(args.prefer_min_meta),
        "notes": "Built by tools/build_dataset/build.py",
    }

    (OUT / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "clubs_min.json").write_text(
        json.dumps(clubs, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    (OUT / "players_min.json").write_text(
        json.dumps(players, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    (OUT / "coaches_min.json").write_text(
        json.dumps(coaches, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # size report
    for fn in ("meta.json", "clubs_min.json", "players_min.json", "coaches_min.json"):
        p = OUT / fn
        log(f"  out {fn}: {p.stat().st_size / 1e6:.2f} MB")

    log("DONE → tools/build_dataset/out/")
    log("Kopyala: out/* → proje assets/data/")
    if not args.prefer_min_meta:
        log("Not: preferMin hâlâ false. Tam min ile gecmek icin --prefer-min-meta kullan.")


if __name__ == "__main__":
    main()
