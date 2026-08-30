#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import json
import math
import re
import unicodedata
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
E_DIR = ROOT / "reports" / "data_platform_v3" / "03e"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03e1"
INPUT_DIR = ROOT / "tools" / "data_platform_v3" / "input"

PLAYABLE_LIMIT = 30000
QUESTION_LIMIT = 12000
CASUAL_LIMIT = 2000
NORMAL_LIMIT = 6000
VISUAL_PRIORITY_LIMIT = 3000

TOP_COMPETITIONS = {
    "GB1", "ES1", "IT1", "L1", "FR1",
    "CL", "EL", "TR1", "PO1", "NL1", "BE1",
    "SC1", "DK1", "SE1", "NO1", "GR1"
}
BIG5 = {"GB1", "ES1", "IT1", "L1", "FR1"}

SANITY_NAMES = [
    "Lionel Messi", "Cristiano Ronaldo", "Neymar",
    "Kylian Mbappé", "Mohamed Salah", "Kevin De Bruyne",
    "Luka Modrić", "Robert Lewandowski", "Karim Benzema",
    "Sergio Ramos", "Zlatan Ibrahimović", "Arjen Robben",
    "Mesut Özil", "Thomas Müller", "Manuel Neuer"
]

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

def norm_name(v: Any) -> str:
    text = unicodedata.normalize("NFKD", s(v))
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", " ", text.casefold()).strip()
    return " ".join(text.split())

def curve_sqrt(value: float, cap: float) -> float:
    if value <= 0:
        return 0.0
    return 100.0 * math.sqrt(min(value, cap) / cap)

def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def find_tm_zip() -> Path:
    preferred = INPUT_DIR / "transfermarkt-datasets-csv.zip"
    if preferred.exists():
        return preferred
    candidates = sorted(INPUT_DIR.glob("*.zip"))
    for p in candidates:
        try:
            with zipfile.ZipFile(p) as z:
                names = set(z.namelist())
                if any(n.endswith("/players.csv") or n == "players.csv" for n in names) and \
                   any(n.endswith("/appearances.csv") or n == "appearances.csv" for n in names):
                    return p
        except Exception:
            pass
    raise FileNotFoundError(
        "Transfermarkt kaynak ZIP bulunamadi. "
        "tools/data_platform_v3/input/transfermarkt-datasets-csv.zip konumunda olmali."
    )

def member_ending(z: zipfile.ZipFile, ending: str) -> str:
    matches = [n for n in z.namelist() if n.endswith(ending)]
    if not matches:
        raise FileNotFoundError(f"ZIP icinde bulunamadi: {ending}")
    return matches[0]

def recency_component(last_season: int) -> float:
    if last_season >= 2024:
        return 100.0
    if last_season >= 2020:
        return 85.0
    if last_season >= 2016:
        return 70.0
    if last_season >= 2012:
        return 55.0
    return 35.0

def main() -> None:
    print("=" * 72)
    print("LINKBALL DATA PLATFORM V3 - STEP 03E.1")
    print("POPULARITY / RECOGNIZABILITY V2 (READ-ONLY)")
    print("=" * 72)

    score_path = E_DIR / "player_selection_scores.csv"
    if not score_path.exists():
        raise FileNotFoundError("03E raporu gerekli: reports/data_platform_v3/03e")

    base_rows = read_csv(score_path)
    canonical = {as_int(r.get("id"), -1): r for r in base_rows if as_int(r.get("id"), -1) >= 0}
    print(f"[03E.1] 03E canonical oyuncu: {len(canonical):,}")

    tm_zip = find_tm_zip()
    print(f"[03E.1] Kaynak ZIP: {tm_zip}")

    tm_players: dict[int, dict[str, str]] = {}
    identity_mismatch = []

    with zipfile.ZipFile(tm_zip) as z:
        players_member = member_ending(z, "players.csv")
        print(f"[03E.1] players.csv okunuyor: {players_member}")
        with z.open(players_member) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for row in reader:
                pid = as_int(row.get("player_id"), -1)
                if pid not in canonical:
                    continue
                if norm_name(row.get("name")) != norm_name(canonical[pid].get("name")):
                    identity_mismatch.append({
                        "id": pid,
                        "canonicalName": s(canonical[pid].get("name")),
                        "sourceName": s(row.get("name")),
                        "status": "NAME_MISMATCH_NOT_USED"
                    })
                    continue
                tm_players[pid] = row

        print(f"[03E.1] Güvenli TM player identity: {len(tm_players):,}")
        print(f"[03E.1] Identity mismatch: {len(identity_mismatch):,}")

        stats = defaultdict(lambda: {
            "apps": 0, "minutes": 0, "goals": 0, "assists": 0,
            "uclApps": 0, "big5Apps": 0, "topApps": 0
        })

        appearances_member = member_ending(z, "appearances.csv")
        print(f"[03E.1] appearances.csv taraniyor: {appearances_member}")
        with z.open(appearances_member) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for i, row in enumerate(reader, 1):
                if i % 250000 == 0:
                    print(f"[03E.1] Appearance satiri: {i:,}")
                pid = as_int(row.get("player_id"), -1)
                if pid not in tm_players:
                    continue
                d = stats[pid]
                d["apps"] += 1
                d["minutes"] += as_int(row.get("minutes_played"))
                d["goals"] += as_int(row.get("goals"))
                d["assists"] += as_int(row.get("assists"))
                comp = s(row.get("competition_id"))
                if comp == "CL":
                    d["uclApps"] += 1
                if comp in BIG5:
                    d["big5Apps"] += 1
                if comp in TOP_COMPETITIONS:
                    d["topApps"] += 1

    print(f"[03E.1] Appearance coverage: {len(stats):,} oyuncu")

    out_rows = []
    factual_count = 0
    fallback_count = 0

    for row in base_rows:
        pid = as_int(row.get("id"), -1)
        old_score = as_float(row.get("selectionScoreV1"))
        tm = tm_players.get(pid)
        d = stats.get(pid)

        if tm is not None:
            factual_count += 1
            dd = d or {
                "apps": 0, "minutes": 0, "goals": 0, "assists": 0,
                "uclApps": 0, "big5Apps": 0, "topApps": 0
            }
            caps = as_float(tm.get("international_caps"))
            goals = dd["goals"]
            assists = dd["assists"]
            last_season = as_int(tm.get("last_season"))

            apps_c = curve_sqrt(dd["apps"], 600)
            top_c = curve_sqrt(dd["topApps"], 500)
            ucl_c = curve_sqrt(dd["uclApps"], 120)
            caps_c = curve_sqrt(caps, 150)
            ga_c = curve_sqrt(goals + assists, 500)
            rec_c = recency_component(last_season)

            # Recognizability model:
            # factual senior exposure dominates; club graph remains context, not the main signal.
            score_v2 = (
                0.18 * apps_c
                + 0.18 * top_c
                + 0.14 * ucl_c
                + 0.17 * caps_c
                + 0.12 * ga_c
                + 0.16 * old_score
                + 0.05 * rec_c
            )
            source = "TM_FACTUAL_AGGREGATE"
        else:
            fallback_count += 1
            # Legacy-only players are retained, but cannot dominate Casual/Normal
            # solely because they have many clubs.
            score_v2 = (
                0.65 * old_score
                + (10.0 if as_int(row.get("seniorGameplayClubCount")) >= 3 else 0.0)
            )
            dd = {
                "apps": 0, "minutes": 0, "goals": 0, "assists": 0,
                "uclApps": 0, "big5Apps": 0, "topApps": 0
            }
            caps = 0.0
            last_season = 0
            source = "LEGACY_FALLBACK"

        nr = dict(row)
        nr["selectionScoreV2"] = round(max(0.0, min(100.0, score_v2)), 2)
        nr["recognizabilitySourceV2"] = source
        nr["factualApps"] = dd["apps"]
        nr["factualMinutes"] = dd["minutes"]
        nr["factualGoals"] = dd["goals"]
        nr["factualAssists"] = dd["assists"]
        nr["factualUclApps"] = dd["uclApps"]
        nr["factualBig5Apps"] = dd["big5Apps"]
        nr["factualTopCompetitionApps"] = dd["topApps"]
        nr["factualInternationalCaps"] = caps
        nr["factualLastSeason"] = last_season
        nr["selectionRankV2"] = ""
        nr["playableV2"] = "NO"
        nr["questionCandidateV2"] = "NO"
        nr["casualV2"] = "NO"
        nr["normalV2"] = "NO"
        nr["hardV2"] = "NO"
        nr["visualPriorityV2"] = "NO"
        out_rows.append(nr)

    rankable = [
        r for r in out_rows
        if s(r.get("answerEligible")).upper() == "YES"
        and s(r.get("metadataComplete")).upper() == "YES"
    ]
    rankable.sort(
        key=lambda r: (
            -as_float(r.get("selectionScoreV2")),
            0 if s(r.get("recognizabilitySourceV2")) == "TM_FACTUAL_AGGREGATE" else 1,
            -as_int(r.get("maxClubPopularitySeed")),
            -as_int(r.get("highTrustClubCount")),
            s(r.get("name")).casefold()
        )
    )

    for rank, r in enumerate(rankable, 1):
        r["selectionRankV2"] = rank

    playable = rankable[:PLAYABLE_LIMIT]
    for r in playable:
        r["playableV2"] = "YES"

    # HARD may contain legacy/fallback players.
    hard_base = [
        r for r in playable
        if as_int(r.get("seniorGameplayClubCount")) >= 2
        or as_int(r.get("highTrustClubCount")) >= 1
    ]
    hard = hard_base[:QUESTION_LIMIT]
    for r in hard:
        r["questionCandidateV2"] = "YES"
        r["hardV2"] = "YES"

    # CASUAL/NORMAL deliberately require factual aggregate evidence.
    factual_question = [
        r for r in hard_base
        if s(r.get("recognizabilitySourceV2")) == "TM_FACTUAL_AGGREGATE"
        and (
            as_int(r.get("factualApps")) >= 20
            or as_float(r.get("factualInternationalCaps")) >= 10
        )
    ]
    factual_question.sort(
        key=lambda r: (
            -as_float(r.get("selectionScoreV2")),
            -as_int(r.get("factualTopCompetitionApps")),
            -as_float(r.get("factualInternationalCaps")),
            s(r.get("name")).casefold()
        )
    )

    casual = factual_question[:CASUAL_LIMIT]
    normal = factual_question[:NORMAL_LIMIT]

    for r in casual:
        r["casualV2"] = "YES"
    for r in normal:
        r["normalV2"] = "YES"

    # Visual production should start from recognizable factual identities.
    visual = factual_question[:VISUAL_PRIORITY_LIMIT]
    for r in visual:
        r["visualPriorityV2"] = "YES"

    # QuestionCandidate includes the whole hard pool.
    hard_ids = {as_int(r.get("id")) for r in hard}
    playable_ids = {as_int(r.get("id")) for r in playable}

    out_rows.sort(
        key=lambda r: (
            as_int(r.get("selectionRankV2"), 10**9),
            s(r.get("name")).casefold(),
            as_int(r.get("id"))
        )
    )

    write_csv("player_selection_scores_v2.csv", out_rows)
    write_csv("top_500_players_v2.csv", rankable[:500])
    write_csv("identity_mismatch_quarantine.csv", identity_mismatch)

    sanity = []
    by_norm = defaultdict(list)
    for r in rankable:
        by_norm[norm_name(r.get("name"))].append(r)
    for name in SANITY_NAMES:
        matches = by_norm.get(norm_name(name), [])
        for r in matches[:3]:
            sanity.append({
                "requestedName": name,
                "id": as_int(r.get("id")),
                "name": s(r.get("name")),
                "rankV1": s(r.get("selectionRank")),
                "rankV2": s(r.get("selectionRankV2")),
                "scoreV1": s(r.get("selectionScoreV1")),
                "scoreV2": s(r.get("selectionScoreV2")),
                "sourceV2": s(r.get("recognizabilitySourceV2")),
                "apps": s(r.get("factualApps")),
                "uclApps": s(r.get("factualUclApps")),
                "caps": s(r.get("factualInternationalCaps")),
            })
    write_csv("sanity_check_players.csv", sanity)

    pool_rows = [
        {"layer": "DATABASE", "count": len(out_rows), "rule": "All valid canonical identities"},
        {"layer": "ANSWER_ELIGIBLE", "count": sum(1 for r in out_rows if s(r.get("answerEligible")).upper() == "YES"), "rule": "Clean senior relation"},
        {"layer": "PLAYABLE_V2", "count": len(playable), "rule": "Top 30k recognizability/context"},
        {"layer": "QUESTION_CANDIDATE_V2", "count": len(hard), "rule": "Hard-cap 12k"},
        {"layer": "CASUAL_V2", "count": len(casual), "rule": "Top factual recognizable 2k"},
        {"layer": "NORMAL_V2", "count": len(normal), "rule": "Top factual recognizable 6k"},
        {"layer": "HARD_V2", "count": len(hard), "rule": "Full question candidate pool"},
        {"layer": "VISUAL_PRIORITY_V2", "count": len(visual), "rule": "First 3k factual avatar priority"},
    ]
    write_csv("pool_sizes_v2.csv", pool_rows)

    preview = {
        "schemaVersion": 2,
        "playableIds": [as_int(r.get("id")) for r in playable],
        "questionCandidateIds": [as_int(r.get("id")) for r in hard],
        "casualIds": [as_int(r.get("id")) for r in casual],
        "normalIds": [as_int(r.get("id")) for r in normal],
        "hardIds": [as_int(r.get("id")) for r in hard],
        "visualPriorityIds": [as_int(r.get("id")) for r in visual],
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "player_pool_ids_v2.preview.json").write_text(
        json.dumps(preview, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8"
    )

    gates = [
        {
            "gate": "E1-01",
            "status": "PASS" if hard_ids.issubset(playable_ids) else "FAIL",
            "rule": "Question candidate pool is subset of PLAYABLE",
            "detail": f"{len(hard):,}/{len(playable):,}",
        },
        {
            "gate": "E1-02",
            "status": "PASS" if len(casual) == CASUAL_LIMIT else "WARN",
            "rule": "Casual target 2k factual players",
            "detail": f"{len(casual):,}",
        },
        {
            "gate": "E1-03",
            "status": "PASS" if len(normal) == NORMAL_LIMIT else "WARN",
            "rule": "Normal target 6k factual players",
            "detail": f"{len(normal):,}",
        },
        {
            "gate": "E1-04",
            "status": "PASS",
            "rule": "No market-value input",
            "detail": "marketValue/highestMarketValue are never read",
        },
        {
            "gate": "E1-05",
            "status": "PASS",
            "rule": "Source identity verified before factual aggregate use",
            "detail": f"{len(tm_players):,} exact normalized-name matches; {len(identity_mismatch):,} quarantined",
        },
        {
            "gate": "E1-06",
            "status": "PASS",
            "rule": "Runtime assets unchanged",
            "detail": "Only reports/data_platform_v3/03e1 is written",
        }
    ]
    write_csv("migration_gates.csv", gates)

    top20 = [
        {
            "rank": as_int(r.get("selectionRankV2")),
            "id": as_int(r.get("id")),
            "name": s(r.get("name")),
            "score": as_float(r.get("selectionScoreV2")),
        }
        for r in rankable[:20]
    ]

    summary = {
        "step": "03E.1",
        "runtimeChanged": False,
        "canonicalPlayers": len(out_rows),
        "safeTmIdentityMatches": len(tm_players),
        "identityMismatchesQuarantined": len(identity_mismatch),
        "appearanceCoveragePlayers": len(stats),
        "factualScoredPlayers": factual_count,
        "legacyFallbackPlayers": fallback_count,
        "playableCount": len(playable),
        "questionCandidateCount": len(hard),
        "casualCount": len(casual),
        "normalCount": len(normal),
        "hardCount": len(hard),
        "visualPriorityCount": len(visual),
        "top20": top20,
        "selectionScoreV2": {
            "appearancesWeight": 0.18,
            "topCompetitionAppearancesWeight": 0.18,
            "uclAppearancesWeight": 0.14,
            "internationalCapsWeight": 0.17,
            "goalsAssistsWeight": 0.12,
            "clubContextV1Weight": 0.16,
            "recencyWeight": 0.05,
            "forbiddenInputs": [
                "market_value_in_eur",
                "highest_market_value_in_eur",
                "image_url",
                "url"
            ]
        }
    }
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03E.1

Popularity / recognizability V2 correction pass.

Problem fixed:
- 03E V1 over-rewarded career breadth / many-club players.
- V2 gives most weight to factual aggregate senior exposure:
  appearances, top-competition appearances, UCL appearances,
  international caps, goals+assists, with club context as a smaller component.

Results:
- Canonical players: {len(out_rows):,}
- Safe TM identities: {len(tm_players):,}
- Appearance coverage: {len(stats):,}
- PLAYABLE: {len(playable):,}
- CASUAL / NORMAL / HARD: {len(casual):,} / {len(normal):,} / {len(hard):,}
- Visual priority: {len(visual):,}

No market value, image URL or source URL is used.
No runtime asset is modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03E.1] PLAYABLE: {len(playable):,}")
    print(f"[03E.1] QUESTION_CANDIDATE/HARD: {len(hard):,}")
    print(f"[03E.1] CASUAL/NORMAL: {len(casual):,}/{len(normal):,}")
    print(f"[03E.1] VISUAL_PRIORITY: {len(visual):,}")
    print("[03E.1] Top 10:")
    for r in rankable[:10]:
        print(f"  #{r['selectionRankV2']:>3} {r['name']} ({r['selectionScoreV2']})")
    print(f"[03E.1] Rapor: {OUT_DIR}")
    print("[03E.1] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
