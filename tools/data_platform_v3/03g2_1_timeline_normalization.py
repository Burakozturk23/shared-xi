#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import json
import re
import zipfile
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
G2_DIR = ROOT / "reports" / "data_platform_v3" / "03g2"
G12_DIR = ROOT / "reports" / "data_platform_v3" / "03g1_2"
D_DIR = ROOT / "reports" / "data_platform_v3" / "03d"
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
INPUT_DIR = ROOT / "tools" / "data_platform_v3" / "input"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03g2_1"

SHORT_SPELL_DAYS = 45

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def as_int(v: Any, default: int = 0) -> int:
    try:
        if s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def yes(v: Any) -> bool:
    return s(v).upper() == "YES"

def read_csv(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows, fields=None):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fields is None:
        fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def find_zip() -> Path:
    p = INPUT_DIR / "transfermarkt-datasets-csv.zip"
    if p.exists():
        return p
    for q in sorted(INPUT_DIR.glob("*.zip")):
        try:
            with zipfile.ZipFile(q) as z:
                if any(n.endswith("appearances.csv") for n in z.namelist()):
                    return q
        except Exception:
            pass
    raise FileNotFoundError(
        "Kaynak ZIP bulunamadi: tools/data_platform_v3/input/transfermarkt-datasets-csv.zip"
    )

def member(z: zipfile.ZipFile, ending: str) -> str:
    hits = [n for n in z.namelist() if n.endswith(ending)]
    if not hits:
        raise FileNotFoundError(f"ZIP icinde yok: {ending}")
    return hits[0]

def duration_days(start: str, end: str):
    if not start or not end:
        return None
    try:
        return (date.fromisoformat(end) - date.fromisoformat(start)).days
    except Exception:
        return None

def main():
    print("=" * 80)
    print("LINKBALL DATA PLATFORM V3 - STEP 03G.2.1")
    print("CAREER TIMELINE GAMEPLAY NORMALIZATION (READ-ONLY)")
    print("=" * 80)

    spells = read_csv(G2_DIR / "career_spells_candidate.csv")
    identities = read_csv(G12_DIR / "player_source_identity_map_v3.csv")
    club_map_rows = read_csv(D_DIR / "club_source_map_v2.csv")
    player_rows = read_csv(E2_DIR / "player_selection_scores_v3.csv")

    player_meta = {as_int(r.get("id"), -1): r for r in player_rows}

    source_player_map = {}
    for r in identities:
        sid = as_int(r.get("sourcePlayerId"), -1)
        pid = as_int(r.get("primaryCanonicalPlayerId"), -1)
        if sid >= 0 and pid >= 0:
            source_player_map[sid] = pid

    source_club_map = {}
    for r in club_map_rows:
        sid = as_int(r.get("sourceClubId"), -1)
        key = s(r.get("canonicalKey"))
        if sid >= 0 and key and s(r.get("status")) != "PSEUDO_EXCLUDED":
            source_club_map[sid] = key

    # Only exact official appearances count. We deliberately do not treat
    # transfer registration alone as competitive gameplay evidence.
    appearance_dates = defaultdict(list)
    src = find_zip()
    print(f"[03G.2.1] Kaynak ZIP: {src}")

    with zipfile.ZipFile(src) as z:
        an = member(z, "appearances.csv")
        print(f"[03G.2.1] appearances.csv taraniyor: {an}")
        with z.open(an) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for i, r in enumerate(reader, 1):
                if i % 250000 == 0:
                    print(f"[03G.2.1] Appearance: {i:,}")
                sid = as_int(r.get("player_id"), -1)
                pid = source_player_map.get(sid)
                if pid is None:
                    continue
                csid = as_int(r.get("player_club_id"), -1)
                key = source_club_map.get(csid)
                if not key:
                    continue
                dt = s(r.get("date"))
                if re.match(r"^\d{4}-\d{2}-\d{2}$", dt):
                    appearance_dates[(pid, key)].append(dt)

    normalized = []
    exclusions = []

    for r in spells:
        nr = dict(r)
        pid = as_int(r.get("canonicalPlayerId"), -1)
        key = s(r.get("canonicalClubKey"))
        start = s(r.get("startDate"))
        end = s(r.get("endDate"))
        dur = duration_days(start, end)

        inside = 0
        if start or end:
            for dt in appearance_dates.get((pid, key), []):
                if start and dt < start:
                    continue
                if end and dt > end:
                    continue
                inside += 1

        base_eligible = (
            yes(r.get("gameplaySenior"))
            and s(r.get("spellConfidence")) in {"HIGH", "MEDIUM"}
        )

        exclusion_reason = ""
        eligible = base_eligible

        if (
            eligible
            and dur is not None
            and 0 <= dur <= SHORT_SPELL_DAYS
            and inside == 0
        ):
            eligible = False
            exclusion_reason = "SHORT_ZERO_APPEARANCE_ADMINISTRATIVE_SPELL"
            exclusions.append({
                "canonicalPlayerId": pid,
                "canonicalPlayerName": s(r.get("canonicalPlayerName")),
                "canonicalClubKey": key,
                "canonicalClubName": s(r.get("canonicalClubName")),
                "startDate": start,
                "endDate": end,
                "durationDays": dur,
                "appearancesInsideSpell": 0,
                "reason": exclusion_reason,
            })

        nr["durationDays"] = "" if dur is None else dur
        nr["appearancesInsideSpell"] = inside
        nr["timelineGameplayEligibleV2"] = "YES" if eligible else "NO"
        nr["timelineExclusionReasonV2"] = exclusion_reason
        normalized.append(nr)

    by_player = defaultdict(list)
    for r in normalized:
        by_player[as_int(r.get("canonicalPlayerId"), -1)].append(r)

    candidates = []
    timeline_json = {}

    for pid, rows in by_player.items():
        usable = [r for r in rows if yes(r.get("timelineGameplayEligibleV2"))]
        club_keys = {s(r.get("canonicalClubKey")) for r in usable if s(r.get("canonicalClubKey"))}
        dated = [r for r in usable if s(r.get("startDate")) or s(r.get("endDate"))]
        high = [r for r in usable if s(r.get("spellConfidence")) == "HIGH"]

        if len(club_keys) < 3 or len(dated) < 3:
            continue

        if len(high) >= 3:
            quality = "A_TRUSTED"
        elif len(dated) >= 4:
            quality = "B_PLAYABLE"
        else:
            quality = "C_PREVIEW"

        pm = player_meta.get(pid, {})
        candidates.append({
            "playerId": pid,
            "name": s(pm.get("name") or (rows[0].get("canonicalPlayerName") if rows else "")),
            "selectionRankV3": as_int(pm.get("selectionRankV3"), 999999999),
            "casualV3": s(pm.get("casualV3")),
            "normalV3": s(pm.get("normalV3")),
            "hardV3": s(pm.get("hardV3")),
            "uniqueSeniorClubCount": len(club_keys),
            "datedSeniorSpellCount": len(dated),
            "highConfidenceSpellCount": len(high),
            "timelineQuality": quality,
        })

        usable.sort(
            key=lambda r: (
                s(r.get("startDate")) or "0000-00-00",
                s(r.get("endDate")) or "9999-99-99",
                as_int(r.get("sequence")),
            )
        )
        timeline_json[str(pid)] = [
            {
                "clubKey": s(r.get("canonicalClubKey")),
                "clubName": s(r.get("canonicalClubName")),
                "from": s(r.get("startDate")),
                "to": s(r.get("endDate")),
                "confidence": s(r.get("spellConfidence")),
            }
            for r in usable
        ]

    candidates.sort(
        key=lambda r: (
            r["selectionRankV3"],
            -r["uniqueSeniorClubCount"],
            r["name"].casefold(),
        )
    )
    exclusions.sort(
        key=lambda r: (
            r["durationDays"],
            r["canonicalPlayerName"].casefold(),
            r["startDate"],
        )
    )

    # QA: known administrative return examples should no longer be gameplay steps.
    known_examples = []
    wanted = {"Mohamed Salah", "Kylian Mbappé", "Antoine Griezmann"}
    for r in exclusions:
        if r["canonicalPlayerName"] in wanted:
            known_examples.append(r)

    old_candidate_ids = {
        as_int(r.get("playerId"), -1)
        for r in read_csv(G2_DIR / "career_puzzle_candidates.csv")
    }
    new_candidate_ids = {r["playerId"] for r in candidates}

    write_csv("career_spells_gameplay_normalized.csv", normalized)
    write_csv("administrative_spell_exclusions.csv", exclusions)
    write_csv("career_puzzle_candidates_v2.csv", candidates)
    write_csv("known_admin_return_examples.csv", known_examples)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "career_timeline_gameplay_v2.preview.json").write_text(
        json.dumps({"schemaVersion": 2, "players": timeline_json}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8"
    )

    quality_counts = Counter(r["timelineQuality"] for r in candidates)
    one_day_excluded = sum(1 for r in exclusions if r["durationDays"] <= 1)
    candidate_removed = len(old_candidate_ids - new_candidate_ids)

    gates = [
        {
            "gate":"G2.1-01",
            "status":"PASS",
            "rule":"Short zero-appearance registration spells are not gameplay timeline steps",
            "detail":f"excluded={len(exclusions):,}; one-day={one_day_excluded:,}"
        },
        {
            "gate":"G2.1-02",
            "status":"PASS" if len(known_examples) >= 3 else "WARN",
            "rule":"Known loan-return examples are detected",
            "detail":f"rows={len(known_examples):,}"
        },
        {
            "gate":"G2.1-03",
            "status":"PASS" if all(r["uniqueSeniorClubCount"] >= 3 and r["datedSeniorSpellCount"] >= 3 for r in candidates) else "FAIL",
            "rule":"Career Puzzle candidates remain >=3 clean usable clubs/spells",
            "detail":f"candidates={len(candidates):,}"
        },
        {
            "gate":"G2.1-04",
            "status":"PASS",
            "rule":"Excluded spells remain preserved in master timeline",
            "detail":"Rows are flagged, not deleted"
        },
        {
            "gate":"G2.1-05",
            "status":"PASS",
            "rule":"Runtime assets unchanged",
            "detail":"Only reports/data_platform_v3/03g2_1 is written"
        },
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step":"03G.2.1",
        "runtimeChanged":False,
        "careerSpellsInput":len(spells),
        "administrativeShortZeroAppearanceSpells":len(exclusions),
        "oneDayAdministrativeSpells":one_day_excluded,
        "careerPuzzleCandidatesBefore":len(old_candidate_ids),
        "careerPuzzleCandidatesAfter":len(candidates),
        "careerPuzzleCandidatesRemovedByNormalization":candidate_removed,
        "timelineQuality":dict(quality_counts),
        "shortSpellThresholdDays":SHORT_SPELL_DAYS,
        "principles":[
            "Official competitive appearance evidence is used to distinguish real short stays from administrative registration spells.",
            "Short zero-appearance spells are preserved in master history but excluded from gameplay timelines.",
            "Loans with real official appearances remain valid gameplay career spells.",
            "No runtime asset is modified."
        ],
        "nextRecommendedStep":"03G.3_DATA_QA_AND_RUNTIME_COMPILER_PREVIEW"
    }

    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03G.2.1

Career timeline gameplay normalization.

- Input career spells: {len(spells):,}
- Short zero-appearance administrative spells excluded from gameplay: {len(exclusions):,}
- One-day administrative spells: {one_day_excluded:,}
- Career Puzzle candidates: {len(old_candidate_ids):,} -> {len(candidates):,}
- A_TRUSTED candidates after normalization: {quality_counts.get('A_TRUSTED', 0):,}

Nothing is deleted from the master timeline. Excluded rows remain available with
an explicit exclusion reason.

No runtime asset is modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03G.2.1] Master spell: {len(spells):,}")
    print(f"[03G.2.1] Administrative/no-appearance exclusion: {len(exclusions):,}")
    print(f"[03G.2.1] One-day exclusion: {one_day_excluded:,}")
    print(f"[03G.2.1] Career Puzzle: {len(old_candidate_ids):,} -> {len(candidates):,}")
    print(f"[03G.2.1] A_TRUSTED: {quality_counts.get('A_TRUSTED', 0):,}")
    print(f"[03G.2.1] Rapor: {OUT_DIR}")
    print("[03G.2.1] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
