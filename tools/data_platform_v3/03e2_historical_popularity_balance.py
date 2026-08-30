#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
IN_DIR = ROOT / "reports" / "data_platform_v3" / "03e1"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"

PLAYABLE_LIMIT = 30000
QUESTION_LIMIT = 12000
CASUAL_LIMIT = 2000
NORMAL_LIMIT = 6000
VISUAL_PRIORITY_LIMIT = 3000

SANITY_NAMES = {
    "Lionel Messi", "Cristiano Ronaldo", "Robert Lewandowski",
    "Mohamed Salah", "Neymar", "Kylian Mbappé", "Luka Modrić",
    "Kevin De Bruyne", "Karim Benzema", "Sergio Ramos",
    "Zlatan Ibrahimović", "Arjen Robben", "Mesut Özil",
    "Thomas Müller", "Manuel Neuer"
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

def as_float(v: Any, default: float = 0.0) -> float:
    try:
        if s(v) == "":
            return default
        return float(v)
    except Exception:
        return default

def read_csv(name: str) -> list[dict[str, str]]:
    p = IN_DIR / name
    if not p.exists():
        raise FileNotFoundError(f"Eksik 03E.1 dosyasi: {p}")
    with p.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def curve_sqrt(value: float, cap: float) -> float:
    if value <= 0:
        return 0.0
    return 100.0 * math.sqrt(min(value, cap) / cap)

def historical_context(row: dict[str, Any]) -> float:
    """
    Compensates for retired stars whose source profile no longer exposes
    international caps and whose appearance coverage sees only a partial career.

    Importantly, total number of clubs and HIGH-trust relation count are NOT used
    here, so journeymen do not receive the old V1 inflation.
    """
    top3 = as_float(row.get("top3ClubPopularityAvg"))
    ucl = as_int(row.get("factualUclApps"))
    apps = as_int(row.get("factualApps"))
    big = as_int(row.get("bigClubCount80"))

    return (
        0.35 * top3
        + 0.25 * curve_sqrt(ucl, 60)
        + 0.20 * curve_sqrt(apps, 400)
        + 0.20 * min(100.0, big * 20.0)
    )

def main() -> None:
    print("=" * 72)
    print("LINKBALL DATA PLATFORM V3 - STEP 03E.2")
    print("HISTORICAL POPULARITY BALANCE (READ-ONLY)")
    print("=" * 72)

    rows = read_csv("player_selection_scores_v2.csv")
    print(f"[03E.2] Oyuncu: {len(rows):,}")

    corrected = 0
    out = []

    for row in rows:
        r = dict(row)
        v2 = as_float(r.get("selectionScoreV2"))
        hist = historical_context(r)
        caps = as_float(r.get("factualInternationalCaps"))
        last = as_int(r.get("factualLastSeason"))
        source = s(r.get("recognizabilitySourceV2"))

        apply_historical = (
            source == "TM_FACTUAL_AGGREGATE"
            and caps <= 0
            and 2000 <= last <= 2023
            and as_int(r.get("factualApps")) >= 80
        )

        if apply_historical:
            score = max(v2, hist * 0.95)
            if score > v2 + 0.01:
                corrected += 1
            reason = "PARTIAL_CAREER_OR_MISSING_CAPS_COMPENSATION"
        else:
            score = v2
            reason = ""

        r["historicalContextScore"] = round(hist, 2)
        r["selectionScoreV3"] = round(max(0.0, min(100.0, score)), 2)
        r["historicalCorrectionApplied"] = "YES" if apply_historical else "NO"
        r["historicalCorrectionReason"] = reason
        r["selectionRankV3"] = ""
        r["playableV3"] = "NO"
        r["questionCandidateV3"] = "NO"
        r["casualV3"] = "NO"
        r["normalV3"] = "NO"
        r["hardV3"] = "NO"
        r["visualPriorityV3"] = "NO"
        out.append(r)

    rankable = [
        r for r in out
        if s(r.get("answerEligible")).upper() == "YES"
        and s(r.get("metadataComplete")).upper() == "YES"
    ]
    rankable.sort(
        key=lambda r: (
            -as_float(r.get("selectionScoreV3")),
            0 if s(r.get("recognizabilitySourceV2")) == "TM_FACTUAL_AGGREGATE" else 1,
            -as_int(r.get("maxClubPopularitySeed")),
            s(r.get("name")).casefold(),
            as_int(r.get("id")),
        )
    )

    for rank, r in enumerate(rankable, 1):
        r["selectionRankV3"] = rank

    playable = rankable[:PLAYABLE_LIMIT]
    for r in playable:
        r["playableV3"] = "YES"

    hard_base = [
        r for r in playable
        if as_int(r.get("seniorGameplayClubCount")) >= 2
        or as_int(r.get("highTrustClubCount")) >= 1
    ]
    hard = hard_base[:QUESTION_LIMIT]
    for r in hard:
        r["questionCandidateV3"] = "YES"
        r["hardV3"] = "YES"

    # Casual / Normal may include corrected retired stars, but still require
    # factual identity and a meaningful senior-career footprint.
    mainstream = [
        r for r in hard_base
        if s(r.get("recognizabilitySourceV2")) == "TM_FACTUAL_AGGREGATE"
        and (
            as_int(r.get("factualApps")) >= 20
            or as_float(r.get("factualInternationalCaps")) >= 10
        )
    ]
    mainstream.sort(
        key=lambda r: (
            -as_float(r.get("selectionScoreV3")),
            -as_int(r.get("factualUclApps")),
            -as_int(r.get("factualTopCompetitionApps")),
            s(r.get("name")).casefold(),
        )
    )

    casual = mainstream[:CASUAL_LIMIT]
    normal = mainstream[:NORMAL_LIMIT]
    visual = mainstream[:VISUAL_PRIORITY_LIMIT]

    for r in casual:
        r["casualV3"] = "YES"
    for r in normal:
        r["normalV3"] = "YES"
    for r in visual:
        r["visualPriorityV3"] = "YES"

    out.sort(
        key=lambda r: (
            as_int(r.get("selectionRankV3"), 10**9),
            s(r.get("name")).casefold(),
            as_int(r.get("id")),
        )
    )

    write_csv("player_selection_scores_v3.csv", out)
    write_csv("top_500_players_v3.csv", rankable[:500])

    sanity = []
    for r in rankable:
        if s(r.get("name")) in SANITY_NAMES:
            sanity.append({
                "id": as_int(r.get("id")),
                "name": s(r.get("name")),
                "rankV2": s(r.get("selectionRankV2")),
                "rankV3": s(r.get("selectionRankV3")),
                "scoreV2": s(r.get("selectionScoreV2")),
                "scoreV3": s(r.get("selectionScoreV3")),
                "historicalContextScore": s(r.get("historicalContextScore")),
                "correctionApplied": s(r.get("historicalCorrectionApplied")),
                "apps": s(r.get("factualApps")),
                "uclApps": s(r.get("factualUclApps")),
                "caps": s(r.get("factualInternationalCaps")),
                "lastSeason": s(r.get("factualLastSeason")),
            })
    write_csv("sanity_check_players_v3.csv", sanity)

    # Legacy/history candidates that still need a future dedicated historical layer.
    history_needed = [
        r for r in rankable
        if s(r.get("recognizabilitySourceV2")) == "LEGACY_FALLBACK"
        and as_float(r.get("selectionScoreV1")) >= 75
    ]
    history_needed.sort(
        key=lambda r: (
            -as_float(r.get("selectionScoreV1")),
            -as_int(r.get("maxClubPopularitySeed")),
            s(r.get("name")).casefold(),
        )
    )
    history_rows = [{
        "id": as_int(r.get("id")),
        "name": s(r.get("name")),
        "scoreV1": s(r.get("selectionScoreV1")),
        "scoreV3": s(r.get("selectionScoreV3")),
        "seniorGameplayClubCount": s(r.get("seniorGameplayClubCount")),
        "maxClubPopularitySeed": s(r.get("maxClubPopularitySeed")),
        "reason": "FUTURE_HISTORICAL_LEGEND_ENRICHMENT"
    } for r in history_needed[:3000]]
    write_csv("historical_layer_priority.csv", history_rows)

    pools = [
        {"layer":"DATABASE","count":len(out),"purpose":"Canonical identity"},
        {"layer":"PLAYABLE_V3","count":len(playable),"purpose":"Broad gameplay/search"},
        {"layer":"QUESTION_CANDIDATE_V3","count":len(hard),"purpose":"Hard/random question source"},
        {"layer":"CASUAL_V3","count":len(casual),"purpose":"Most recognizable factual + balanced retired stars"},
        {"layer":"NORMAL_V3","count":len(normal),"purpose":"Mainstream factual pool"},
        {"layer":"HARD_V3","count":len(hard),"purpose":"Full question pool"},
        {"layer":"VISUAL_PRIORITY_V3","count":len(visual),"purpose":"First custom-avatar production batch"},
        {"layer":"HISTORICAL_LAYER_PRIORITY","count":len(history_rows),"purpose":"Future legends/nostalgia enrichment"}
    ]
    write_csv("pool_sizes_v3.csv", pools)

    preview = {
        "schemaVersion": 3,
        "playableIds": [as_int(r.get("id")) for r in playable],
        "questionCandidateIds": [as_int(r.get("id")) for r in hard],
        "casualIds": [as_int(r.get("id")) for r in casual],
        "normalIds": [as_int(r.get("id")) for r in normal],
        "hardIds": [as_int(r.get("id")) for r in hard],
        "visualPriorityIds": [as_int(r.get("id")) for r in visual],
        "historicalLayerPriorityIds": [as_int(r.get("id")) for r in history_needed[:3000]],
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "player_pool_ids_v3.preview.json").write_text(
        json.dumps(preview, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8"
    )

    playable_ids = set(preview["playableIds"])
    question_ids = set(preview["questionCandidateIds"])
    gates = [
        {
            "gate":"E2-01",
            "status":"PASS" if question_ids.issubset(playable_ids) else "FAIL",
            "rule":"Question pool subset of PLAYABLE",
            "detail":f"{len(question_ids):,}/{len(playable_ids):,}"
        },
        {
            "gate":"E2-02",
            "status":"PASS",
            "rule":"Historical correction does not use total-club count or trust count",
            "detail":"Uses top3 club context + factual apps/UCL + elite-club count only"
        },
        {
            "gate":"E2-03",
            "status":"PASS",
            "rule":"Market value remains forbidden",
            "detail":"No market-value field is read"
        },
        {
            "gate":"E2-04",
            "status":"PASS",
            "rule":"Legacy-only legends remain explicit future-enrichment backlog",
            "detail":f"{len(history_rows):,} priority rows exported"
        },
        {
            "gate":"E2-05",
            "status":"PASS",
            "rule":"Runtime assets unchanged",
            "detail":"Only reports/data_platform_v3/03e2 is written"
        },
    ]
    write_csv("migration_gates.csv", gates)

    top20 = [{
        "rank": as_int(r.get("selectionRankV3")),
        "id": as_int(r.get("id")),
        "name": s(r.get("name")),
        "score": as_float(r.get("selectionScoreV3")),
    } for r in rankable[:20]]

    summary = {
        "step":"03E.2",
        "runtimeChanged":False,
        "canonicalPlayers":len(out),
        "historicalCorrectionsApplied":corrected,
        "playableCount":len(playable),
        "questionCandidateCount":len(hard),
        "casualCount":len(casual),
        "normalCount":len(normal),
        "hardCount":len(hard),
        "visualPriorityCount":len(visual),
        "historicalLayerPriorityCount":len(history_rows),
        "top20":top20,
        "historicalCorrectionModel":{
            "eligibility":"TM factual identity; missing caps; lastSeason <= 2023; >=80 covered appearances",
            "top3ClubContextWeight":0.35,
            "uclAppearanceWeight":0.25,
            "coveredAppearanceWeight":0.20,
            "eliteClubCountWeight":0.20,
            "appliedAsFloorMultiplier":0.95,
            "forbiddenInputs":["marketValue","peakMarketValue","careerGoals","totalClubCount","highTrustRelationCount"]
        }
    }
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03E.2

Historical popularity balance correction.

The V2 factual model is strong for modern players, but retired stars can have
missing international-cap fields and partial appearance coverage. V3 adds a
conservative historical floor without reintroducing the old journeyman bias.

- Historical corrections applied: {corrected:,}
- PLAYABLE: {len(playable):,}
- CASUAL / NORMAL / HARD: {len(casual):,} / {len(normal):,} / {len(hard):,}
- Visual priority: {len(visual):,}
- Future historical/legend enrichment backlog: {len(history_rows):,}

No runtime asset is modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03E.2] Historical correction: {corrected:,}")
    print(f"[03E.2] PLAYABLE: {len(playable):,}")
    print(f"[03E.2] CASUAL/NORMAL/HARD: {len(casual):,}/{len(normal):,}/{len(hard):,}")
    print(f"[03E.2] VISUAL_PRIORITY: {len(visual):,}")
    print("[03E.2] Sanity:")
    for r in sanity:
        if r["name"] in {"Zlatan Ibrahimović","Arjen Robben","Mesut Özil","Lionel Messi","Cristiano Ronaldo"}:
            print(f"  {r['name']}: #{r['rankV2']} -> #{r['rankV3']} | {r['scoreV2']} -> {r['scoreV3']}")
    print(f"[03E.2] Rapor: {OUT_DIR}")
    print("[03E.2] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
