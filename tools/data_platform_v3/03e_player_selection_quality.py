#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "assets" / "data"
D2_DIR = ROOT / "reports" / "data_platform_v3" / "03d2"
B1_DIR = ROOT / "reports" / "data_platform_v3" / "03b1"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03e"

PLAYABLE_LIMIT = 30000
QUESTION_LIMIT = 12000
NORMAL_LIMIT = 6000
CASUAL_LIMIT = 2000
VISUAL_PRIORITY_LIMIT = 3000

BAD_NAMES = {"", "unknown", "n/a", "na", "none", "null", "-"}
GENERIC_PLAYER_RE = re.compile(r"^\s*(?:player|oyuncu)\s+\d+\s*$", re.I)

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def as_int(v: Any, default: int = 0) -> int:
    try:
        if s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def as_list(v: Any) -> list[Any]:
    if v is None:
        return []
    if isinstance(v, list):
        return v
    return [v]

def load_players() -> list[dict[str, Any]]:
    p = DATA_DIR / "players_min.json"
    if not p.exists():
        raise FileNotFoundError(f"Eksik dosya: {p}")
    print(f"[03E] players_min.json yukleniyor: {p}")
    with p.open("r", encoding="utf-8") as f:
        raw = json.load(f)

    if isinstance(raw, list):
        rows = raw
    elif isinstance(raw, dict):
        if isinstance(raw.get("players"), list):
            rows = raw["players"]
        else:
            rows = []
            for k, v in raw.items():
                if isinstance(v, dict):
                    row = dict(v)
                    row.setdefault("id", k)
                    rows.append(row)
    else:
        raise ValueError("players_min.json desteklenmeyen root tipe sahip")

    out = []
    for r in rows:
        if isinstance(r, dict):
            out.append(r)
    print(f"[03E] Canonical/min player: {len(out):,}")
    return out

def read_csv(path: Path):
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

def valid_name(name: str) -> bool:
    n = s(name)
    if n.casefold() in BAD_NAMES:
        return False
    if GENERIC_PLAYER_RE.match(n):
        return False
    if len(n) < 2:
        return False
    if n.isdigit():
        return False
    return True

def player_countries(row: dict[str, Any]) -> list[str]:
    vals = as_list(row.get("countries"))
    if not vals:
        vals = as_list(row.get("nationality"))
    if not vals:
        vals = as_list(row.get("country"))
    return [s(x) for x in vals if s(x)]

def player_position(row: dict[str, Any]) -> str:
    return s(row.get("position") or row.get("detailedPosition"))

def score_player(club_pops: list[int], high_clubs: int, medium_clubs: int, country_ok: bool, position_ok: bool) -> int:
    if not club_pops:
        return 0
    pops = sorted(club_pops, reverse=True)
    max_pop = pops[0]
    top3 = sum(pops[:3]) / min(3, len(pops))
    club_count = len(pops)
    big_clubs = sum(1 for p in pops if p >= 80)

    score = (
        0.50 * max_pop
        + 0.22 * top3
        + min(12.0, club_count * 2.0)
        + min(10.0, big_clubs * 2.5)
        + min(6.0, high_clubs * 0.8)
        + (1.0 if country_ok else 0.0)
        + (1.0 if position_ok else 0.0)
    )
    return max(0, min(100, int(round(score))))

def main():
    print("=" * 70)
    print("LINKBALL DATA PLATFORM V3 - STEP 03E")
    print("PLAYER SELECTION QUALITY / POPULARITY SEED (READ-ONLY)")
    print("=" * 70)

    players = load_players()

    club_path = D2_DIR / "canonical_clubs_gameplay_guarded_v2.csv"
    career_path = D2_DIR / "canonical_careers_gameplay_guarded_v2.csv"
    if not club_path.exists() or not career_path.exists():
        raise FileNotFoundError(
            "03D.2 raporu bulunamadi. reports/data_platform_v3/03d2 klasoru gerekli."
        )

    print("[03E] 03D.2 kulup kalite verisi yukleniyor...")
    clubs = {}
    with club_path.open("r", encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            key = s(r.get("canonicalKey"))
            if key:
                clubs[key] = r
    print(f"[03E] Kulup adayi: {len(clubs):,}")

    # Track one trust level per unique player-club pair to avoid duplicate transfer rows
    # artificially inflating popularity.
    print("[03E] Gameplay kariyer iliskileri taraniyor...")
    by_player: dict[int, dict[str, Any]] = defaultdict(
        lambda: {"clubs": {}, "transferEvidence": set()}
    )
    rows_seen = 0
    eligible_rows = 0
    with career_path.open("r", encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            rows_seen += 1
            if rows_seen % 100000 == 0:
                print(f"[03E] Kariyer satiri: {rows_seen:,}")
            if s(r.get("gameplayEligible03d1")).upper() != "YES":
                continue
            eligible_rows += 1
            pid = as_int(r.get("canonicalPlayerId"), -1)
            key = s(r.get("canonicalClubKey"))
            if pid < 0 or not key or key not in clubs:
                continue
            trust = s(r.get("relationTrust03d1")).upper()
            rank = 2 if trust == "HIGH" else 1 if trust == "MEDIUM" else 0
            current = by_player[pid]["clubs"].get(key)
            if current is None or rank > current["trustRank"]:
                by_player[pid]["clubs"][key] = {
                    "trustRank": rank,
                    "trust": trust,
                    "pop": as_int(clubs[key].get("popularitySeed")),
                    "clubName": s(clubs[key].get("name")),
                }
            if "TRANSFER_VALIDATED" in s(r.get("evidence")):
                by_player[pid]["transferEvidence"].add(key)

    print(f"[03E] Gameplay eligible kariyer satiri: {eligible_rows:,}")
    print(f"[03E] En az bir gameplay kulubu olan oyuncu: {len(by_player):,}")

    collision_ids = set()
    collision_path = B1_DIR / "player_id_collisions.csv"
    if collision_path.exists():
        print("[03E] 03B.1 enrichment quarantine bayraklari yukleniyor...")
        with collision_path.open("r", encoding="utf-8-sig", newline="") as f:
            for r in csv.DictReader(f):
                if s(r.get("status")) == "ID_COLLISION_OR_AMBIGUOUS":
                    collision_ids.add(as_int(r.get("numericId"), -1))
        collision_ids.discard(-1)
        print(f"[03E] Full enrichment kullanilmamasi gereken canonical ID: {len(collision_ids):,}")
    else:
        print("[03E] UYARI: 03B.1 player_id_collisions.csv yok; enrichment risk flag'i bos kalacak.")

    scored = []
    seen_ids = set()
    invalid_records = 0
    duplicate_ids = 0

    print("[03E] Oyuncu selection score hesaplaniyor...")
    for idx, p in enumerate(players, 1):
        if idx % 25000 == 0:
            print(f"[03E] Oyuncu: {idx:,}/{len(players):,}")
        pid = as_int(p.get("id"), -1)
        name = s(p.get("name"))
        if pid < 0 or not valid_name(name):
            invalid_records += 1
            continue
        if pid in seen_ids:
            duplicate_ids += 1
            continue
        seen_ids.add(pid)

        countries = player_countries(p)
        position = player_position(p)
        country_ok = bool(countries)
        position_ok = bool(position)

        d = by_player.get(pid, {"clubs": {}, "transferEvidence": set()})
        club_map = d["clubs"]
        senior_club_count = len(club_map)
        club_pops = [as_int(x.get("pop")) for x in club_map.values()]
        high_clubs = sum(1 for x in club_map.values() if x.get("trustRank") == 2)
        medium_clubs = sum(1 for x in club_map.values() if x.get("trustRank") == 1)
        transfer_clubs = len(d["transferEvidence"])
        big_clubs = sum(1 for pop in club_pops if pop >= 80)
        max_club_pop = max(club_pops) if club_pops else 0
        top3_avg = round(sum(sorted(club_pops, reverse=True)[:3]) / min(3, len(club_pops)), 1) if club_pops else 0.0

        selection_score = score_player(
            club_pops, high_clubs, medium_clubs, country_ok, position_ok
        )

        answer_eligible = senior_club_count >= 1
        metadata_complete = country_ok and position_ok

        scored.append({
            "id": pid,
            "name": name,
            "countries": "|".join(countries),
            "position": position,
            "selectionScoreV1": selection_score,
            "seniorGameplayClubCount": senior_club_count,
            "highTrustClubCount": high_clubs,
            "mediumTrustClubCount": medium_clubs,
            "transferValidatedClubCount": transfer_clubs,
            "bigClubCount80": big_clubs,
            "maxClubPopularitySeed": max_club_pop,
            "top3ClubPopularityAvg": top3_avg,
            "metadataComplete": "YES" if metadata_complete else "NO",
            "answerEligible": "YES" if answer_eligible else "NO",
            "enrichmentUnsafe03b1": "YES" if pid in collision_ids else "NO",
            "playable": "NO",
            "questionCandidate": "NO",
            "casualPool": "NO",
            "normalPool": "NO",
            "hardPool": "NO",
            "visualPriority": "NO",
            "selectionRank": "",
        })

    # Rank only players with trusted gameplay relationships and sufficient UI metadata.
    rankable = [
        r for r in scored
        if r["answerEligible"] == "YES" and r["metadataComplete"] == "YES"
    ]
    rankable.sort(
        key=lambda r: (
            -as_int(r["selectionScoreV1"]),
            -as_int(r["maxClubPopularitySeed"]),
            -as_int(r["highTrustClubCount"]),
            -as_int(r["seniorGameplayClubCount"]),
            s(r["name"]).casefold(),
            as_int(r["id"]),
        )
    )

    for rank, r in enumerate(rankable, 1):
        r["selectionRank"] = rank

    playable = rankable[:PLAYABLE_LIMIT]
    playable_ids = {r["id"] for r in playable}
    for r in playable:
        r["playable"] = "YES"

    # Question generation is stricter than answer validation:
    # one-club players are still allowed if their career relation is HIGH trust.
    question_base = [
        r for r in playable
        if as_int(r["seniorGameplayClubCount"]) >= 2 or as_int(r["highTrustClubCount"]) >= 1
    ]
    question = question_base[:QUESTION_LIMIT]
    question_ids = {r["id"] for r in question}
    for r in question:
        r["questionCandidate"] = "YES"

    casual = question[:CASUAL_LIMIT]
    normal = question[:NORMAL_LIMIT]
    hard = question[:QUESTION_LIMIT]
    visual = question[:VISUAL_PRIORITY_LIMIT]

    for r in casual:
        r["casualPool"] = "YES"
    for r in normal:
        r["normalPool"] = "YES"
    for r in hard:
        r["hardPool"] = "YES"
    for r in visual:
        r["visualPriority"] = "YES"

    answer_ids = [r["id"] for r in scored if r["answerEligible"] == "YES"]
    database_ids = [r["id"] for r in scored]

    # Mode-specific preview. No market value or contaminated full-player fields are used.
    modes = [
        ("Shared XI - answer validation", sum(1 for r in scored if r["answerEligible"] == "YES"),
         "All players with >=1 clean senior gameplay club"),
        ("Shared XI - random prompts", len(question),
         "Question candidate pool"),
        ("Grid / Reverse Grid", sum(1 for r in question if r["countries"] and r["seniorGameplayClubCount"] >= 1),
         "Question candidates with nationality + club"),
        ("Find Imposter / Odd Club", sum(1 for r in question if as_int(r["seniorGameplayClubCount"]) >= 2),
         "Needs >=2 clean senior clubs"),
        ("Career Puzzle", sum(1 for r in question if as_int(r["seniorGameplayClubCount"]) >= 3),
         "Preview only; timeline years arrive in enrichment step"),
        ("Chain", sum(1 for r in playable if as_int(r["seniorGameplayClubCount"]) >= 2),
         "Large playable pool, >=2 clubs"),
        ("Transfer Detective", sum(1 for r in playable if as_int(r["transferValidatedClubCount"]) >= 1),
         "At least one source-validated transfer relation"),
        ("Mystery Player", len(question),
         "Metadata-complete question candidates"),
        ("Build XI", sum(1 for r in question if r["position"]),
         "Question candidates with position"),
        ("Higher / Lower", 0,
         "BLOCKED_FOR_STATS_V3: do not use contaminated marketValue/careerGoals as core"),
    ]
    game_rows = [
        {"mode": m, "candidateCount": c, "rule": rule}
        for m, c, rule in modes
    ]

    # Review important players whose full-player enrichment must remain quarantined.
    quarantine_priority = [
        r for r in rankable
        if r["enrichmentUnsafe03b1"] == "YES"
    ][:1000]

    metadata_gaps = [
        r for r in scored
        if r["answerEligible"] == "YES" and r["metadataComplete"] == "NO"
    ]
    metadata_gaps.sort(
        key=lambda r: (
            -as_int(r["selectionScoreV1"]),
            -as_int(r["maxClubPopularitySeed"]),
            s(r["name"]).casefold(),
        )
    )

    # Score distribution.
    dist = Counter()
    for r in rankable:
        score = as_int(r["selectionScoreV1"])
        bucket_lo = (score // 5) * 5
        bucket_hi = min(100, bucket_lo + 4)
        dist[f"{bucket_lo:02d}-{bucket_hi:02d}"] += 1
    dist_rows = [{"scoreBucket": k, "playerCount": dist[k]} for k in sorted(dist)]

    # Layer counts.
    pool_rows = [
        {"layer": "DATABASE", "count": len(database_ids), "purpose": "Canonical player identity; never random-question source by itself"},
        {"layer": "ANSWER_ELIGIBLE", "count": len(answer_ids), "purpose": "Can validate a correct club/player relationship"},
        {"layer": "PLAYABLE", "count": len(playable), "purpose": "Curated broad gameplay/search pool"},
        {"layer": "QUESTION_CANDIDATE", "count": len(question), "purpose": "Safe random question source"},
        {"layer": "CASUAL", "count": len(casual), "purpose": "Most recognizable subset"},
        {"layer": "NORMAL", "count": len(normal), "purpose": "Mainstream subset"},
        {"layer": "HARD", "count": len(hard), "purpose": "Full question-candidate subset"},
        {"layer": "VISUAL_PRIORITY", "count": len(visual), "purpose": "First custom player illustration batch priority"},
    ]

    # Write results.
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    scored_sorted = sorted(scored, key=lambda r: (as_int(r["selectionRank"], 10**9), s(r["name"]).casefold(), as_int(r["id"])))
    write_csv("player_selection_scores.csv", scored_sorted)
    write_csv("pool_sizes.csv", pool_rows)
    write_csv("game_pool_readiness.csv", game_rows)
    write_csv("selection_score_distribution.csv", dist_rows)
    write_csv("top_500_players.csv", rankable[:500])
    write_csv("metadata_gap_priority.csv", metadata_gaps[:2000])
    write_csv("enrichment_quarantine_priority.csv", quarantine_priority)

    pool_json = {
        "schemaVersion": 1,
        "databaseIds": database_ids,
        "answerEligibleIds": answer_ids,
        "playableIds": [r["id"] for r in playable],
        "questionCandidateIds": [r["id"] for r in question],
        "casualIds": [r["id"] for r in casual],
        "normalIds": [r["id"] for r in normal],
        "hardIds": [r["id"] for r in hard],
        "visualPriorityIds": [r["id"] for r in visual],
    }
    with (OUT_DIR / "player_pool_ids.preview.json").open("w", encoding="utf-8") as f:
        json.dump(pool_json, f, ensure_ascii=False, separators=(",", ":"))

    q_cutoff = as_int(question[-1]["selectionScoreV1"]) if question else None
    p_cutoff = as_int(playable[-1]["selectionScoreV1"]) if playable else None

    gates = [
        {
            "gate": "E-01",
            "status": "PASS" if question_ids.issubset(playable_ids) else "FAIL",
            "rule": "Question candidates are a subset of PLAYABLE",
            "detail": f"{len(question):,}/{len(playable):,}",
        },
        {
            "gate": "E-02",
            "status": "PASS" if all(r["answerEligible"] == "YES" for r in playable) else "FAIL",
            "rule": "PLAYABLE players have clean senior career evidence",
            "detail": f"{len(playable):,} checked",
        },
        {
            "gate": "E-03",
            "status": "PASS" if 5000 <= len(question) <= 12000 else "WARN",
            "rule": "Question-candidate target is 5k-12k",
            "detail": f"{len(question):,}",
        },
        {
            "gate": "E-04",
            "status": "PASS",
            "rule": "Popularity seed does not use marketValue, peakMarketValue or careerGoals",
            "detail": "Uses canonical career breadth, trusted relation evidence and club popularity seed only",
        },
        {
            "gate": "E-05",
            "status": "PASS",
            "rule": "03B.1 identity collisions remain enrichment-quarantined",
            "detail": f"{len(quarantine_priority):,} high-priority rows exported for later repair",
        },
        {
            "gate": "E-06",
            "status": "PASS",
            "rule": "Runtime assets unchanged",
            "detail": "Only reports/data_platform_v3/03e is written",
        },
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step": "03E",
        "runtimeChanged": False,
        "playersMinInput": len(players),
        "databasePlayerCount": len(database_ids),
        "invalidOrUnusableIdentityRows": invalid_records,
        "duplicatePlayerIdsSkipped": duplicate_ids,
        "answerEligibleCount": len(answer_ids),
        "rankableMetadataCompleteCount": len(rankable),
        "playableCount": len(playable),
        "playableScoreCutoff": p_cutoff,
        "questionCandidateCount": len(question),
        "questionScoreCutoff": q_cutoff,
        "casualCount": len(casual),
        "normalCount": len(normal),
        "hardCount": len(hard),
        "visualPriorityCount": len(visual),
        "metadataGapPriorityCount": min(2000, len(metadata_gaps)),
        "enrichmentCollisionIds": len(collision_ids),
        "selectionModel": {
            "name": "selectionScoreV1",
            "maxClubPopularityWeight": 0.50,
            "top3ClubPopularityWeight": 0.22,
            "careerBreadthBonusMax": 12,
            "bigClubBonusMax": 10,
            "highTrustEvidenceBonusMax": 6,
            "metadataBonusMax": 2,
            "forbiddenInputs": ["marketValue", "peakMarketValue", "careerGoals", "unsafe players_full enrichment"]
        }
    }
    with (OUT_DIR / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    readme = f"""# Linkball Data Platform V3 — 03E

Read-only player selection quality preview.

- Database players: {len(database_ids):,}
- Answer-eligible players: {len(answer_ids):,}
- Playable pool: {len(playable):,}
- Question candidates: {len(question):,}
- Casual / Normal / Hard: {len(casual):,} / {len(normal):,} / {len(hard):,}
- Visual priority batch: {len(visual):,}
- Playable score cutoff: {p_cutoff}
- Question score cutoff: {q_cutoff}

`selectionScoreV1` deliberately does **not** use Transfermarkt market values or unsafe `players_full` enrichment.

No file under `assets/data` is modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03E] DATABASE: {len(database_ids):,}")
    print(f"[03E] ANSWER_ELIGIBLE: {len(answer_ids):,}")
    print(f"[03E] PLAYABLE: {len(playable):,} (cutoff={p_cutoff})")
    print(f"[03E] QUESTION_CANDIDATE: {len(question):,} (cutoff={q_cutoff})")
    print(f"[03E] CASUAL/NORMAL/HARD: {len(casual):,}/{len(normal):,}/{len(hard):,}")
    print(f"[03E] VISUAL_PRIORITY: {len(visual):,}")
    print(f"[03E] Rapor: {OUT_DIR}")
    print("[03E] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
