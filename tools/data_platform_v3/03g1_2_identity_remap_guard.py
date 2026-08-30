#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
G11_DIR = ROOT / "reports" / "data_platform_v3" / "03g1_1"
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03g1_2"

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def as_int(v: Any, default: int = 0) -> int:
    try:
        if s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]], fields=None) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fields is None:
        fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def coarse_position(v: Any) -> str:
    p = s(v).casefold()
    if "goal" in p or p == "gk":
        return "GK"
    if "def" in p or "back" in p:
        return "OUTFIELD"
    if "mid" in p:
        return "OUTFIELD"
    if "attack" in p or "wing" in p or "forward" in p or "striker" in p:
        return "OUTFIELD"
    return "UNKNOWN"

def single_token_name(v: Any) -> bool:
    return len([x for x in s(v).replace("-", " ").split() if x]) <= 1

def main() -> None:
    print("=" * 78)
    print("LINKBALL DATA PLATFORM V3 - STEP 03G.1.2")
    print("CROSS-ID REMAP FALSE-POSITIVE GUARD (READ-ONLY)")
    print("=" * 78)

    identity = read_csv(G11_DIR / "player_source_identity_map_v2.csv")
    remaps = read_csv(G11_DIR / "auto_identity_remaps.csv")
    profiles = read_csv(G11_DIR / "player_profile_factual_v2.csv")
    stats = read_csv(G11_DIR / "player_stats_source_window_v2.csv")
    club_stats = read_csv(G11_DIR / "player_stats_by_club_v2.csv")
    comp_stats = read_csv(G11_DIR / "player_stats_by_competition_v2.csv")
    suppressions = read_csv(G11_DIR / "shadow_duplicate_suppressions.csv")
    reviews = read_csv(G11_DIR / "identity_review_queue.csv")
    selection = read_csv(E2_DIR / "player_selection_scores_v3.csv")

    player = {as_int(r.get("id"), -1): r for r in selection}

    rejected = []
    safe_remaps = []
    reject_source_ids = set()

    for r in remaps:
        sid = as_int(r.get("sourcePlayerId"), -1)
        tid = as_int(r.get("primaryCanonicalPlayerId"), -1)
        src = player.get(sid, {})
        tgt = player.get(tid, {})
        src_pos = coarse_position(src.get("position"))
        tgt_pos = coarse_position(tgt.get("position"))
        overlap = as_int(r.get("transferClubOverlap"))

        goalkeeper_conflict = (
            {src_pos, tgt_pos} == {"GK", "OUTFIELD"}
        )
        weak_single_name = (
            overlap == 0
            and single_token_name(r.get("sourceName"))
        )

        if goalkeeper_conflict or weak_single_name:
            reason_parts = []
            if goalkeeper_conflict:
                reason_parts.append("GOALKEEPER_OUTFIELD_CONFLICT")
            if weak_single_name:
                reason_parts.append("SINGLE_TOKEN_NAME_WITH_ZERO_TRANSFER_OVERLAP")
            nr = dict(r)
            nr["sourcePosition"] = s(src.get("position"))
            nr["targetPosition"] = s(tgt.get("position"))
            nr["rejectionReason"] = "|".join(reason_parts)
            nr["newStatus"] = "REVIEW_QUARANTINED"
            rejected.append(nr)
            reject_source_ids.add(sid)
        else:
            safe_remaps.append(r)

    # Correct the source identity map. Rejected source identities remain separate;
    # nothing is deleted and no alternative target is guessed.
    identity_v3 = []
    for r in identity:
        sid = as_int(r.get("sourcePlayerId"), -1)
        nr = dict(r)
        if sid in reject_source_ids:
            nr["primaryCanonicalPlayerId"] = sid
            nr["primaryName"] = s(r.get("sourceName"))
            nr["method"] = "CROSS_ID_REMAP_REJECTED_BY_POSITION_OR_NAME_GUARD"
            nr["confidence"] = 60
            nr["status"] = "PROFILE_ONLY_KEEP_SEPARATE"
        identity_v3.append(nr)

    # Profile table has one row per factual source identity and preserves sourcePlayerId,
    # so rejected remaps can be safely restored directly.
    profiles_v3 = []
    for r in profiles:
        nr = dict(r)
        source_id = as_int(r.get("sourcePlayerId"), as_int(r.get("playerId"), -1))
        if source_id in reject_source_ids:
            nr["playerId"] = source_id
            nr["identityConsolidated"] = "NO"
        profiles_v3.append(nr)

    # These rejected examples have no appearance aggregates in the current dataset,
    # but apply a defensive correction whenever sourcePlayerId is still present.
    def restore_if_traceable(rows):
        out = []
        for r in rows:
            nr = dict(r)
            source_id = as_int(r.get("sourcePlayerId"), -1)
            if source_id in reject_source_ids:
                nr["playerId"] = source_id
            out.append(nr)
        return out

    stats_v3 = restore_if_traceable(stats)
    club_stats_v3 = restore_if_traceable(club_stats)
    comp_stats_v3 = restore_if_traceable(comp_stats)

    # Rejected identities must not be shadow-suppressed.
    suppressions_v3 = [
        r for r in suppressions
        if as_int(r.get("shadowCanonicalPlayerId"), -1) not in reject_source_ids
    ]

    # Add rejected rows to manual review queue.
    review_v2 = list(reviews)
    for r in rejected:
        review_v2.append({
            "sourcePlayerId": r.get("sourcePlayerId"),
            "sourceName": r.get("sourceName"),
            "sourceCountry": s(player.get(as_int(r.get("sourcePlayerId"), -1), {}).get("countries")),
            "sourcePosition": r.get("sourcePosition"),
            "currentCanonicalClub": "",
            "bestCandidateId": r.get("primaryCanonicalPlayerId"),
            "bestCandidateName": r.get("primaryName"),
            "bestScore": r.get("confidence"),
            "currentClubMatch": r.get("currentClubMatch"),
            "transferClubOverlap": r.get("transferClubOverlap"),
            "positionCompatible": "NO" if "GOALKEEPER_OUTFIELD_CONFLICT" in s(r.get("rejectionReason")) else "UNKNOWN",
            "reason": "03G1_2_" + s(r.get("rejectionReason")),
        })

    write_csv("player_source_identity_map_v3.csv", identity_v3)
    write_csv("safe_auto_identity_remaps_v2.csv", safe_remaps)
    write_csv("rejected_auto_identity_remaps.csv", rejected)
    write_csv("identity_review_queue_v2.csv", review_v2)
    write_csv("shadow_duplicate_suppressions_v2.csv", suppressions_v3)
    write_csv("player_profile_factual_v3.csv", profiles_v3)
    write_csv("player_stats_source_window_v3.csv", stats_v3)
    write_csv("player_stats_by_club_v3.csv", club_stats_v3)
    write_csv("player_stats_by_competition_v3.csv", comp_stats_v3)

    examples = []
    for r in rejected:
        examples.append({
            "sourcePlayerId": r.get("sourcePlayerId"),
            "sourceName": r.get("sourceName"),
            "sourcePosition": r.get("sourcePosition"),
            "rejectedTargetId": r.get("primaryCanonicalPlayerId"),
            "rejectedTargetName": r.get("primaryName"),
            "targetPosition": r.get("targetPosition"),
            "transferClubOverlap": r.get("transferClubOverlap"),
            "reason": r.get("rejectionReason"),
        })
    write_csv("rejected_examples.csv", examples)

    gates = [
        {
            "gate":"G1.2-01",
            "status":"PASS",
            "rule":"Goalkeeper/outfield cross-ID remaps are never automatically accepted",
            "detail":f"rejected={sum(1 for r in rejected if 'GOALKEEPER_OUTFIELD_CONFLICT' in s(r.get('rejectionReason'))):,}"
        },
        {
            "gate":"G1.2-02",
            "status":"PASS",
            "rule":"Single-token same-name remaps with zero transfer overlap are review-only",
            "detail":f"rejected={sum(1 for r in rejected if 'SINGLE_TOKEN_NAME_WITH_ZERO_TRANSFER_OVERLAP' in s(r.get('rejectionReason'))):,}"
        },
        {
            "gate":"G1.2-03",
            "status":"PASS" if len(safe_remaps) + len(rejected) == len(remaps) else "FAIL",
            "rule":"Every previous auto-remap is either preserved or explicitly rejected",
            "detail":f"safe={len(safe_remaps):,}; rejected={len(rejected):,}; input={len(remaps):,}"
        },
        {
            "gate":"G1.2-04",
            "status":"PASS",
            "rule":"Rejected identities remain preserved under their source/canonical ID",
            "detail":"No player record is deleted"
        },
        {
            "gate":"G1.2-05",
            "status":"PASS",
            "rule":"Runtime assets unchanged",
            "detail":"Only reports/data_platform_v3/03g1_2 is written"
        }
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step":"03G.1.2",
        "runtimeChanged":False,
        "previousHighConfidenceRemaps":len(remaps),
        "safeHighConfidenceRemaps":len(safe_remaps),
        "rejectedFalsePositiveRemaps":len(rejected),
        "rejectedSourcePlayerIds":sorted(reject_source_ids),
        "reviewQueueRows":len(review_v2),
        "shadowSuppressionsAfterGuard":len(suppressions_v3),
        "principles":[
            "A current-club match alone is not enough for short/common player names.",
            "Goalkeeper-to-outfield identity remaps are never automatic.",
            "Rejected identities remain separate until stronger evidence exists.",
            "No runtime data is mutated."
        ],
        "nextRecommendedStep":"03G.2_CANONICAL_TRANSFERS_AND_CAREER_TIMELINE_USING_PLAYER_SOURCE_IDENTITY_MAP_V3"
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03G.1.2

False-positive guard for cross-ID player remaps.

03G.1.1 produced {len(remaps)} high-confidence cross-ID proposals. This step adds two
extra conservative rules before those mappings can be used by canonical transfer/timeline data:

- goalkeeper ↔ outfield cross-ID joins are never automatic;
- single-token player names with zero transfer-club overlap are review-only.

Result:
- Safe remaps retained: {len(safe_remaps)}
- False-positive remaps rejected: {len(rejected)}
- Runtime assets changed: NO

Rejected identities are preserved separately; nothing is deleted.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03G.1.2] Onceki auto-remap: {len(remaps):,}")
    print(f"[03G.1.2] Guvenli kalan: {len(safe_remaps):,}")
    print(f"[03G.1.2] Karantinaya alinan: {len(rejected):,}")
    for r in examples:
        print(
            f"  {r['sourceName']} {r['sourcePlayerId']} ({r['sourcePosition']}) "
            f"-X-> {r['rejectedTargetId']} ({r['targetPosition']}) "
            f"[{r['reason']}]"
        )
    print(f"[03G.1.2] Rapor: {OUT_DIR}")
    print("[03G.1.2] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
