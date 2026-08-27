#!/usr/bin/env python3
"""
Shared XI dataset builder (Faz B + mod yaması)

Girdi (input/):
  players.csv, clubs.csv, transfers.csv
  player_valuations.csv   ← market / peak
  legacy_players.json, legacy_clubs.json
  coaches.csv (opsiyonel)

Çıktı (out/):
  meta.json, clubs_min.json, players_min.json, coaches_min.json
  famous_transfers.json   ← Transfer Detective
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent
INPUT = ROOT / "input"
PATCHES = ROOT / "patches"
OUT = ROOT / "out"

# Transfer Detective / Career icin bilinen kulupler (chain_pool ozeti)
FAMOUS_CLUB_IDS = {
    11, 631, 31, 281, 985, 148, 405, 29, 762, 379, 180, 1003,
    131, 418, 13, 368, 1049, 621, 680, 336, 330, 940,
    27, 16, 15, 24, 82, 86, 89, 23826,
    5, 46, 506, 12, 398, 6195, 430, 800, 416, 276,
    583, 244, 40, 1082, 995, 162,
    141, 36, 114, 449, 610, 689,
    610, 294, 234, 383, 370,
}

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
            import pandas as pd

            df = pd.read_parquet(path)
            rows = df.to_dict(orient="records")
            log(f"  loaded {path.name}: {len(rows)} rows")
            return rows
        except Exception as e:
            log(f"  parquet fail {path}: {e}")
    return None


def load_json(name: str):
    path = INPUT / name
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    log(f"  loaded {path.name}: {len(data) if isinstance(data, list) else 'obj'}")
    return data


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


def norm_pos(raw: str | None) -> str:
    if not raw:
        return "Midfield"
    s = str(raw).strip().lower()
    for k, v in POSITION_MAP.items():
        if k in s:
            return v
    if "keep" in s:
        return "Goalkeeper"
    if any(x in s for x in ("back", "defence", "defender")):
        return "Defender"
    if "mid" in s:
        return "Midfield"
    if any(x in s for x in ("wing", "forward", "attack", "strik")):
        return "Attack"
    return "Midfield"


def parse_year(raw) -> int | None:
    if raw is None or raw == "":
        return None
    s = str(raw).strip()
    # 2019-07-01 / 2019/07/01 / 2019
    m = re.search(r"(19|20)\d{2}", s)
    if m:
        return int(m.group(0))
    # season 19/20
    m = re.match(r"(\d{2})/(\d{2})", s)
    if m:
        y = int(m.group(1))
        return 2000 + y if y < 50 else 1900 + y
    return None


# ── valuations → peak + latest ──────────────────────────────────────────
def build_valuation_maps(rows) -> tuple[dict[int, float], dict[int, float]]:
    """player_id -> (latest_market, peak_market)"""
    latest: dict[int, tuple[str, float]] = {}
    peak: dict[int, float] = {}
    if not rows:
        return {}, {}
    for r in rows:
        pid = to_int(first_key(r, ["player_id", "playerid"]))
        val = to_float(
            first_key(
                r,
                [
                    "market_value_in_eur",
                    "market_value",
                    "value",
                    "marketValue",
                ],
            )
        )
        if pid is None or val is None or val <= 0:
            continue
        dt = str(first_key(r, ["date", "datetime", "valuation_date"]) or "")
        prev = latest.get(pid)
        if prev is None or dt >= prev[0]:
            latest[pid] = (dt, val)
        peak[pid] = max(peak.get(pid, 0), val)
    latest_v = {k: v for k, (_, v) in latest.items()}
    log(f"  valuations: {len(peak)} players with peak")
    return latest_v, peak


# ── transfers → clubIds + timeline + famous ─────────────────────────────
def process_transfers(rows):
    """
    Returns:
      club_map: pid -> set(club_id)
      timeline_events: pid -> list of (year, club_id) sorted
      famous_list: list of FamousTransfer dicts
    """
    club_map: dict[int, set[int]] = defaultdict(set)
    events: dict[int, list[tuple[int, int]]] = defaultdict(list)
    famous: list[dict] = []

    if not rows:
        return club_map, {}, famous

    for r in rows:
        pid = to_int(first_key(r, ["player_id", "playerid"]))
        if pid is None or pid <= 0:
            continue
        frm = to_int(first_key(r, ["from_club_id", "from_club", "club_id_from"]))
        to = to_int(first_key(r, ["to_club_id", "to_club", "club_id_to"]))
        year = parse_year(
            first_key(
                r,
                [
                    "transfer_date",
                    "date",
                    "transfer_season",
                    "season",
                    "year",
                ],
            )
        )
        fee = to_float(
            first_key(
                r,
                [
                    "transfer_fee",
                    "fee",
                    "market_value_in_eur",
                    "fee_eur",
                ],
            )
        ) or 0.0

        if frm and frm > 0:
            club_map[pid].add(frm)
            if year:
                events[pid].append((year, frm))
        if to and to > 0:
            club_map[pid].add(to)
            if year:
                events[pid].append((year, to))

        # Famous transfer: her iki kulup bilinen havuzda
        if (
            frm
            and to
            and frm > 0
            and to > 0
            and frm != to
            and frm in FAMOUS_CLUB_IDS
            and to in FAMOUS_CLUB_IDS
            and year
            and year >= 1995
        ):
            famous.append(
                {
                    "playerId": pid,
                    "year": year,
                    "fee": fee,
                    "fromClubId": frm,
                    "toClubId": to,
                }
            )

    # timeline: sort unique by year, collapse consecutive same club
    timelines: dict[int, list[dict]] = {}
    for pid, evs in events.items():
        evs = sorted(evs, key=lambda x: (x[0], x[1]))
        stops: list[dict] = []
        for year, cid in evs:
            if stops and stops[-1]["clubId"] == cid:
                continue
            if stops and stops[-1].get("endYear") is None:
                # onceki duragin bitisi
                if year >= stops[-1]["startYear"]:
                    stops[-1]["endYear"] = year
            stops.append({"clubId": cid, "startYear": year, "endYear": None})
        # tek kulup tekrarlarini temizle
        cleaned = []
        for s in stops:
            if cleaned and cleaned[-1]["clubId"] == s["clubId"]:
                continue
            cleaned.append(s)
        if cleaned:
            timelines[pid] = cleaned

    # famous dedupe + fee sirala, limit
    seen = set()
    uniq = []
    for t in sorted(famous, key=lambda x: (-x["fee"], -x["year"])):
        key = (t["playerId"], t["fromClubId"], t["toClubId"], t["year"])
        if key in seen:
            continue
        seen.add(key)
        uniq.append(t)
    famous = uniq[:8000]

    log(f"  transfer club links: {len(club_map)} players")
    log(f"  timelines: {len(timelines)} players")
    log(f"  famous_transfers: {len(famous)}")
    return club_map, timelines, famous


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


def build_players(
    tm_players,
    legacy_players,
    transfer_clubs,
    timelines,
    latest_mv,
    peak_mv,
) -> list[dict]:
    legacy_by_id: dict[int, dict] = {}
    if legacy_players:
        for p in legacy_players:
            pid = to_int(p.get("id"))
            if pid is not None and pid > 0:
                legacy_by_id[pid] = p

    alias_patches: dict[str, list[str]] = {}
    ap = PATCHES / "aliases.json"
    if ap.exists():
        alias_patches = json.loads(ap.read_text(encoding="utf-8"))
        log(f"  alias patches: {len(alias_patches)}")

    out: dict[int, dict] = {}

    if tm_players:
        for p in tm_players:
            pid = to_int(first_key(p, ["player_id", "id"]))
            if pid is None or pid <= 0:
                continue
            name = str(
                first_key(p, ["name", "player_name", "pretty_name"]) or ""
            ).strip()
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
            if isinstance(country, str) and country.strip():
                countries = [x.strip() for x in country.split(",") if x.strip()]
            pos = norm_pos(
                str(first_key(p, ["position", "sub_position", "player_position"]) or "")
            )
            current = to_int(first_key(p, ["current_club_id", "club_id"]))

            club_ids = set(transfer_clubs.get(pid, set()))
            if current and current > 0:
                club_ids.add(current)

            leg = legacy_by_id.get(pid)
            if leg:
                for c in leg.get("clubs") or leg.get("clubIds") or []:
                    ci = to_int(c)
                    if ci and ci > 0:
                        club_ids.add(ci)
                if not countries and leg.get("countries"):
                    countries = list(leg["countries"])

            aliases = []
            if leg:
                aliases = [str(a) for a in (leg.get("aliases") or [])][:8]
            if str(pid) in alias_patches:
                for a in alias_patches[str(pid)]:
                    if a not in aliases:
                        aliases.append(a)

            # timeline: transfers onceki, yoksa legacy
            tl = timelines.get(pid)
            if not tl and leg and leg.get("careerTimeline"):
                tl = []
                for s in leg["careerTimeline"]:
                    if isinstance(s, dict) and s.get("clubId"):
                        tl.append(
                            {
                                "clubId": int(s["clubId"]),
                                "startYear": int(s.get("startYear") or 2000),
                                "endYear": s.get("endYear"),
                            }
                        )
            # timeline kuluplerini clubIds'e ekle
            if tl:
                for s in tl:
                    club_ids.add(int(s["clubId"]))

            peak = peak_mv.get(pid) or 0
            market = latest_mv.get(pid) or 0
            if leg:
                peak = max(peak, float(leg.get("peakMarketValue") or 0))
                market = max(market, float(leg.get("marketValue") or 0))

            career_goals = 0
            if leg:
                career_goals = int(leg.get("careerGoals") or 0)

            out[pid] = {
                "id": pid,
                "name": name,
                "countries": countries,
                "position": pos,
                "clubIds": sorted(club_ids),
                "aliases": aliases[:8],
                "avatarKey": f"p_{pid}",
                "rating": None,
                "marketValue": market,
                "peakMarketValue": peak if peak > 0 else market,
                "careerGoals": career_goals,
                "careerTimeline": tl or [],
            }

    # legacy-only
    for pid, leg in legacy_by_id.items():
        if pid in out:
            s = set(out[pid]["clubIds"])
            for c in leg.get("clubs") or leg.get("clubIds") or []:
                ci = to_int(c)
                if ci and ci > 0:
                    s.add(ci)
            out[pid]["clubIds"] = sorted(s)
            if not out[pid]["careerTimeline"] and leg.get("careerTimeline"):
                out[pid]["careerTimeline"] = leg["careerTimeline"]
            continue
        name = (leg.get("name") or "").strip()
        if not name:
            continue
        clubs = []
        for c in leg.get("clubs") or leg.get("clubIds") or []:
            ci = to_int(c)
            if ci and ci > 0:
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
            "marketValue": float(leg.get("marketValue") or 0),
            "peakMarketValue": float(leg.get("peakMarketValue") or 0),
            "careerGoals": int(leg.get("careerGoals") or 0),
            "careerTimeline": leg.get("careerTimeline") or [],
        }

    players = sorted(out.values(), key=lambda x: x["id"])
    with_tl = sum(1 for p in players if len(p.get("careerTimeline") or []) >= 3)
    with_peak = sum(1 for p in players if (p.get("peakMarketValue") or 0) >= 1_000_000)
    log(f"  players_min: {len(players)}")
    log(f"  timeline>=3 stops: {with_tl}")
    log(f"  peak>=1M: {with_peak}")
    return players


def build_coaches(rows) -> list[dict]:
    if not rows:
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
        out.append(
            {
                "id": cid,
                "name": name,
                "countries": countries,
                "clubIds": [],
                "aliases": [],
                "avatarKey": None,
                "rating": to_float(first_key(r, ["rating", "elo", "elo_rating"])),
            }
        )
    log(f"  coaches_min: {len(out)}")
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prefer-min-meta", action="store_true")
    args = parser.parse_args()

    INPUT.mkdir(parents=True, exist_ok=True)
    PATCHES.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    log("=== Shared XI build (mod yaması) ===")
    tm_players = load_table("players")
    tm_clubs = load_table("clubs")
    transfers = load_table("transfers")
    valuations = load_table("player_valuations")
    coaches_rows = load_table("coaches")
    legacy_players = load_json("legacy_players.json")
    legacy_clubs = load_json("legacy_clubs.json")

    if not tm_players and not legacy_players:
        log("HATA: players.csv veya legacy_players.json yok")
        sys.exit(1)

    latest_mv, peak_mv = build_valuation_maps(valuations)
    transfer_clubs, timelines, famous = process_transfers(transfers)
    clubs = build_clubs(tm_clubs, legacy_clubs)
    players = build_players(
        tm_players, legacy_players, transfer_clubs, timelines, latest_mv, peak_mv
    )
    coaches = build_coaches(coaches_rows)

    meta = {
        "schemaVersion": 2,
        "dataVersion": date.today().isoformat(),
        "playerCount": len(players),
        "clubCount": len(clubs),
        "coachCount": len(coaches),
        "famousTransferCount": len(famous),
        "preferMin": bool(args.prefer_min_meta),
        "notes": "timeline+valuations+famous_transfers",
    }

    def dump(name, obj, pretty=False):
        path = OUT / name
        if pretty:
            path.write_text(
                json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
        else:
            path.write_text(
                json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
        log(f"  out {name}: {path.stat().st_size / 1e6:.2f} MB")

    dump("meta.json", meta, pretty=True)
    dump("clubs_min.json", clubs)
    dump("players_min.json", players)
    dump("coaches_min.json", coaches, pretty=True)
    dump("famous_transfers.json", famous)

    log("DONE → out/")
    log("Kopyala assets/data/ icine: meta, clubs_min, players_min, coaches_min, famous_transfers")


if __name__ == "__main__":
    main()
