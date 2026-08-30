#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import json
import re
import unicodedata
import zipfile
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
D_DIR = ROOT / "reports" / "data_platform_v3" / "03d"
INPUT_DIR = ROOT / "tools" / "data_platform_v3" / "input"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03g1"

BIG5 = {"GB1", "ES1", "IT1", "L1", "FR1"}
TOP_COMPETITIONS = {
    "GB1", "ES1", "IT1", "L1", "FR1", "CL", "EL",
    "TR1", "PO1", "NL1", "BE1", "SC1", "DK1", "SE1", "NO1", "GR1"
}

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def as_int(v: Any, default: int = 0) -> int:
    try:
        if s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def norm_name(v: Any) -> str:
    text = unicodedata.normalize("NFKD", s(v))
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", " ", text.casefold()).strip()
    return " ".join(text.split())

def parse_year(v: Any) -> int:
    t = s(v)
    if not t:
        return 0
    m = re.match(r"^(\d{4})", t)
    return int(m.group(1)) if m else 0

def canonical_position_group(source_position: str, sub_position: str) -> str:
    p = s(source_position).casefold()
    sub = s(sub_position).casefold()
    if "goalkeeper" in p or "keeper" in sub:
        return "GK"
    if "defender" in p or any(x in sub for x in ["back", "centre-back", "center-back", "defender"]):
        return "DF"
    if "midfield" in p or any(x in sub for x in ["midfield", "midfielder"]):
        return "MF"
    if "attack" in p or "striker" in p or any(x in sub for x in ["winger", "forward", "second striker", "centre-forward", "center-forward"]):
        return "FW"
    return ""

def find_source_zip() -> Path:
    preferred = INPUT_DIR / "transfermarkt-datasets-csv.zip"
    if preferred.exists():
        return preferred
    for p in sorted(INPUT_DIR.glob("*.zip")):
        try:
            with zipfile.ZipFile(p) as z:
                names = z.namelist()
                if any(n.endswith("players.csv") for n in names) and any(n.endswith("appearances.csv") for n in names):
                    return p
        except Exception:
            pass
    raise FileNotFoundError(
        "Kaynak ZIP bulunamadi. tools/data_platform_v3/input/transfermarkt-datasets-csv.zip gerekli."
    )

def member(z: zipfile.ZipFile, ending: str) -> str:
    hits = [n for n in z.namelist() if n.endswith(ending)]
    if not hits:
        raise FileNotFoundError(f"ZIP icinde {ending} yok")
    return hits[0]

def read_csv_file(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]], fields: list[str] | None = None):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fields is None:
        fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def main():
    print("=" * 76)
    print("LINKBALL DATA PLATFORM V3 - STEP 03G.1")
    print("FACTUAL PROFILE + STATS + COMPETITION LAYER (READ-ONLY)")
    print("=" * 76)

    selection_path = E2_DIR / "player_selection_scores_v3.csv"
    base_rows = read_csv_file(selection_path)
    canonical = {as_int(r.get("id"), -1): r for r in base_rows if as_int(r.get("id"), -1) >= 0}
    print(f"[03G.1] Canonical player: {len(canonical):,}")

    # Club source mapping is optional for player-level stats but required for mapped club stats.
    club_map = {}
    map_path = D_DIR / "club_source_map_v2.csv"
    if map_path.exists():
        for r in read_csv_file(map_path):
            sid = as_int(r.get("sourceClubId"), -1)
            key = s(r.get("canonicalKey"))
            if sid >= 0 and key and s(r.get("status")) != "PSEUDO_EXCLUDED":
                club_map[sid] = key
        print(f"[03G.1] TM club -> canonical map: {len(club_map):,}")
    else:
        print("[03G.1] UYARI: 03D club_source_map_v2.csv yok; club aggregate canonical map sinirli olacak.")

    src = find_source_zip()
    print(f"[03G.1] Kaynak ZIP: {src}")

    safe_profiles = {}
    identity_quarantine = []

    career_stats = defaultdict(lambda: {
        "apps":0, "goals":0, "assists":0, "minutes":0,
        "yellow":0, "red":0, "uclApps":0, "big5Apps":0, "topApps":0,
        "firstYear":9999, "lastYear":0
    })
    club_stats = defaultdict(lambda: {"apps":0, "goals":0, "assists":0, "minutes":0})
    comp_stats = defaultdict(lambda: {"apps":0, "goals":0, "assists":0, "minutes":0})
    competitions = {}

    with zipfile.ZipFile(src) as z:
        # 1) Profiles, identity guarded.
        pn = member(z, "players.csv")
        print(f"[03G.1] players.csv: {pn}")
        with z.open(pn) as fb:
            r = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for row in r:
                pid = as_int(row.get("player_id"), -1)
                if pid not in canonical:
                    continue
                cname = s(canonical[pid].get("name"))
                if norm_name(row.get("name")) != norm_name(cname):
                    identity_quarantine.append({
                        "canonicalPlayerId": pid,
                        "canonicalName": cname,
                        "sourceName": s(row.get("name")),
                        "reason": "NORMALIZED_NAME_MISMATCH"
                    })
                    continue
                safe_profiles[pid] = row

        print(f"[03G.1] Safe profile identity: {len(safe_profiles):,}")
        print(f"[03G.1] Identity quarantine: {len(identity_quarantine):,}")

        # 2) Competition dictionary.
        cn = member(z, "competitions.csv")
        with z.open(cn) as fb:
            r = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for row in r:
                cid = s(row.get("competition_id"))
                if not cid:
                    continue
                competitions[cid] = {
                    "competitionId": cid,
                    "name": s(row.get("name")),
                    "type": s(row.get("type")),
                    "subType": s(row.get("sub_type")),
                    "country": s(row.get("country_name")),
                    "confederation": s(row.get("confederation")),
                    "isBig5": "YES" if cid in BIG5 else "NO",
                    "isTopCompetition": "YES" if cid in TOP_COMPETITIONS else "NO",
                }

        # 3) Appearance aggregates.
        an = member(z, "appearances.csv")
        print(f"[03G.1] appearances.csv: {an}")
        with z.open(an) as fb:
            r = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for i, row in enumerate(r, 1):
                if i % 250000 == 0:
                    print(f"[03G.1] Appearance: {i:,}")
                pid = as_int(row.get("player_id"), -1)
                if pid not in safe_profiles:
                    continue

                apps = career_stats[pid]
                apps["apps"] += 1
                apps["goals"] += as_int(row.get("goals"))
                apps["assists"] += as_int(row.get("assists"))
                apps["minutes"] += as_int(row.get("minutes_played"))
                apps["yellow"] += as_int(row.get("yellow_cards"))
                apps["red"] += as_int(row.get("red_cards"))
                cid = s(row.get("competition_id"))
                if cid == "CL":
                    apps["uclApps"] += 1
                if cid in BIG5:
                    apps["big5Apps"] += 1
                if cid in TOP_COMPETITIONS:
                    apps["topApps"] += 1
                year = parse_year(row.get("date"))
                if year:
                    apps["firstYear"] = min(apps["firstYear"], year)
                    apps["lastYear"] = max(apps["lastYear"], year)

                source_club = as_int(row.get("player_club_id"), -1)
                canonical_club = club_map.get(source_club, "")
                if canonical_club:
                    d = club_stats[(pid, canonical_club)]
                    d["apps"] += 1
                    d["goals"] += as_int(row.get("goals"))
                    d["assists"] += as_int(row.get("assists"))
                    d["minutes"] += as_int(row.get("minutes_played"))

                if cid:
                    d = comp_stats[(pid, cid)]
                    d["apps"] += 1
                    d["goals"] += as_int(row.get("goals"))
                    d["assists"] += as_int(row.get("assists"))
                    d["minutes"] += as_int(row.get("minutes_played"))

    # 4) Factual profile table.
    profile_rows = []
    coverage_rows = []
    stat_rows = []

    for pid, canonical_row in canonical.items():
        srcp = safe_profiles.get(pid)
        if not srcp:
            continue

        dob = s(srcp.get("date_of_birth"))
        birth_year = parse_year(dob)
        source_position = s(srcp.get("position"))
        detailed_position = s(srcp.get("sub_position"))
        group = canonical_position_group(source_position, detailed_position)

        caps_raw = s(srcp.get("international_caps"))
        intl_goals_raw = s(srcp.get("international_goals"))

        profile_rows.append({
            "playerId": pid,
            "name": s(canonical_row.get("name")),
            "birthDate": dob,
            "birthYear": birth_year,
            "countryOfCitizenship": s(srcp.get("country_of_citizenship")),
            "countryOfBirth": s(srcp.get("country_of_birth")),
            "positionGroup": group,
            "sourcePosition": source_position,
            "detailedPosition": detailed_position,
            "foot": s(srcp.get("foot")).lower(),
            "heightCm": as_int(srcp.get("height_in_cm")),
            "internationalCaps": as_int(caps_raw),
            "internationalGoals": as_int(intl_goals_raw),
            "internationalCapsPresent": "YES" if caps_raw != "" else "NO",
            "internationalGoalsPresent": "YES" if intl_goals_raw != "" else "NO",
            "sourceLastSeason": as_int(srcp.get("last_season")),
            "identityConfidence": "HIGH_EXACT_NORMALIZED_NAME",
        })

        st = career_stats.get(pid)
        if st:
            first_year = 0 if st["firstYear"] == 9999 else st["firstYear"]
            last_year = st["lastYear"]
            # Conservative completeness heuristic. It only means the source window
            # probably sees the player's early senior years, not legal/absolute completeness.
            likely_complete = (
                birth_year >= 1988
                and first_year > 0
                and first_year <= birth_year + 21
            )
            coverage_class = "LIKELY_COMPLETE_MODERN_WINDOW" if likely_complete else "PARTIAL_OR_UNKNOWN_WINDOW"

            stat_rows.append({
                "playerId": pid,
                "name": s(canonical_row.get("name")),
                "appearances": st["apps"],
                "goals": st["goals"],
                "assists": st["assists"],
                "minutes": st["minutes"],
                "yellowCards": st["yellow"],
                "redCards": st["red"],
                "uclAppearances": st["uclApps"],
                "big5Appearances": st["big5Apps"],
                "topCompetitionAppearances": st["topApps"],
                "coverageFirstYear": first_year,
                "coverageLastYear": last_year,
                "coverageClass": coverage_class,
            })

            coverage_rows.append({
                "playerId": pid,
                "name": s(canonical_row.get("name")),
                "birthYear": birth_year,
                "coverageFirstYear": first_year,
                "coverageLastYear": last_year,
                "coverageClass": coverage_class,
                "safeForCareerTotalComparison": "YES" if likely_complete else "NO",
                "note": "Stats are factual aggregates inside the available source window."
            })

    # 5) Club/competition aggregates.
    club_rows = []
    for (pid, key), d in club_stats.items():
        club_rows.append({
            "playerId": pid,
            "canonicalClubKey": key,
            "appearances": d["apps"],
            "goals": d["goals"],
            "assists": d["assists"],
            "minutes": d["minutes"],
        })

    comp_rows = []
    for (pid, cid), d in comp_stats.items():
        comp_rows.append({
            "playerId": pid,
            "competitionId": cid,
            "appearances": d["apps"],
            "goals": d["goals"],
            "assists": d["assists"],
            "minutes": d["minutes"],
        })

    profile_rows.sort(key=lambda r: r["playerId"])
    stat_rows.sort(key=lambda r: r["playerId"])
    coverage_rows.sort(key=lambda r: r["playerId"])
    club_rows.sort(key=lambda r: (r["playerId"], r["canonicalClubKey"]))
    comp_rows.sort(key=lambda r: (r["playerId"], r["competitionId"]))
    competition_rows = sorted(competitions.values(), key=lambda r: r["competitionId"])

    write_csv("player_profile_factual.csv", profile_rows)
    write_csv("player_stats_source_window.csv", stat_rows)
    write_csv("player_stats_by_club.csv", club_rows)
    write_csv("player_stats_by_competition.csv", comp_rows)
    write_csv("competitions_factual.csv", competition_rows)
    write_csv("stats_coverage_quality.csv", coverage_rows)
    write_csv("identity_quarantine.csv", identity_quarantine)

    likely_complete_count = sum(1 for r in coverage_rows if r["safeForCareerTotalComparison"] == "YES")
    profile_with_position = sum(1 for r in profile_rows if r["detailedPosition"])
    profile_with_foot = sum(1 for r in profile_rows if r["foot"])
    profile_with_height = sum(1 for r in profile_rows if r["heightCm"] > 0)
    profile_with_caps = sum(1 for r in profile_rows if r["internationalCapsPresent"] == "YES")

    # Mode readiness after G1.
    mode_rows = [
        {
            "mode":"Mystery Player",
            "status":"G1_READY_PROFILE_HINTS",
            "available":"birthYear, nationality, position/sub-position, foot, height, caps/goals when present",
            "remaining":"Replace star-teammate logic later; never show market value"
        },
        {
            "mode":"Build XI",
            "status":"G1_READY_POSITION_DATA",
            "available":"canonical position group + detailed position",
            "remaining":"Replace budget/value mechanic with gameplay rating/popularity percentile"
        },
        {
            "mode":"Higher / Lower",
            "status":"PARTIAL_G1",
            "available":"apps/goals/assists/minutes/UCL apps/caps/height",
            "remaining":"Career-total comparisons only where coverage is complete; otherwise use source-window/competition scoped comparisons"
        },
        {
            "mode":"Blind Ranking",
            "status":"PARTIAL_G1",
            "available":"same factual criteria as Higher/Lower",
            "remaining":"Use only complete or explicitly scoped stat criteria"
        },
        {
            "mode":"Grid",
            "status":"G1_ADDS_FACTUAL_CRITERIA",
            "available":"competition-specific apps/goals/assists + position",
            "remaining":"Avoid unscoped career-goal conditions for partial-history players"
        },
        {
            "mode":"Career Puzzle / Journey",
            "status":"STILL_BLOCKED",
            "available":"profile + stats context",
            "remaining":"03G.2 canonical transfer events and career timeline"
        },
        {
            "mode":"Transfer Detective",
            "status":"STILL_PARTIAL",
            "available":"player factual profile/stats",
            "remaining":"03G.2 canonical validated transfer events"
        },
    ]
    write_csv("mode_readiness_after_g1.csv", mode_rows)

    gates = [
        {
            "gate":"G1-01",
            "status":"PASS",
            "rule":"Source player factual data used only after normalized-name identity match",
            "detail":f"safe={len(safe_profiles):,}; quarantined={len(identity_quarantine):,}"
        },
        {
            "gate":"G1-02",
            "status":"PASS",
            "rule":"Market value / image URL / source URL are not emitted",
            "detail":"Forbidden source fields ignored"
        },
        {
            "gate":"G1-03",
            "status":"PASS",
            "rule":"Historical coverage is explicitly labeled",
            "detail":f"career-total-safe heuristic={likely_complete_count:,}; remaining partial/unknown"
        },
        {
            "gate":"G1-04",
            "status":"PASS",
            "rule":"Detailed position metadata is separated from legacy Player model",
            "detail":f"{profile_with_position:,} profile(s) with detailed position"
        },
        {
            "gate":"G1-05",
            "status":"PASS",
            "rule":"Runtime assets unchanged",
            "detail":"Only reports/data_platform_v3/03g1 is written"
        },
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step":"03G.1",
        "runtimeChanged":False,
        "canonicalPlayers":len(canonical),
        "safeSourceProfiles":len(safe_profiles),
        "identityQuarantine":len(identity_quarantine),
        "playersWithAppearanceStats":len(stat_rows),
        "playersLikelyCompleteModernStats":likely_complete_count,
        "playerClubAggregateRows":len(club_rows),
        "playerCompetitionAggregateRows":len(comp_rows),
        "competitions":len(competition_rows),
        "profileCoverage":{
            "detailedPosition":profile_with_position,
            "foot":profile_with_foot,
            "height":profile_with_height,
            "internationalCapsFieldPresent":profile_with_caps
        },
        "forbiddenFields":[
            "market_value_in_eur",
            "highest_market_value_in_eur",
            "image_url",
            "url",
            "agent_name"
        ],
        "nextRecommendedStep":"03G.2_CANONICAL_TRANSFER_EVENTS_AND_CAREER_TIMELINE"
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03G.1

Factual player profile, source-window stats and competition layer.

- Canonical players: {len(canonical):,}
- Safe source profiles: {len(safe_profiles):,}
- Players with appearance stats: {len(stat_rows):,}
- Likely-complete modern-window stat players: {likely_complete_count:,}
- Player-club aggregate rows: {len(club_rows):,}
- Player-competition aggregate rows: {len(comp_rows):,}
- Competitions: {len(competition_rows):,}

Important:
`player_stats_source_window.csv` is **not automatically a complete all-time career total**.
Each player has explicit coverage metadata in `stats_coverage_quality.csv`.

No market value, player image URL, source URL or agent data is emitted.
No runtime asset is modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03G.1] Safe profile: {len(safe_profiles):,}")
    print(f"[03G.1] Appearance stats: {len(stat_rows):,}")
    print(f"[03G.1] Likely complete modern stats: {likely_complete_count:,}")
    print(f"[03G.1] Detailed position: {profile_with_position:,}")
    print(f"[03G.1] Club stat rows: {len(club_rows):,}")
    print(f"[03G.1] Competition stat rows: {len(comp_rows):,}")
    print(f"[03G.1] Competition: {len(competition_rows):,}")
    print(f"[03G.1] Rapor: {OUT_DIR}")
    print("[03G.1] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
