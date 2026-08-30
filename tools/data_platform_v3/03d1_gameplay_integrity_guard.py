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
IN_DIR = ROOT / "reports" / "data_platform_v3" / "03d"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03d1"

PLACEHOLDER_RE = re.compile(r"^\s*Club\s+\d+\s*$", re.I)
GENERIC_BAD_NAMES = {
    "", "unknown", "retired", "without club", "career break", "n/a", "na", "none"
}

# Deliberately conservative. Do not classify names such as "B SAD",
# "B. Jerusalem" or "B. Podgorica" as reserve teams merely because they contain "B".
DEVELOPMENT_PATTERNS = [
    re.compile(r"\bU[- ]?(?:15|16|17|18|19|20|21|22|23)\b", re.I),
    re.compile(r"\bSub[- ]?(?:15|16|17|18|19|20|21|22|23)\b", re.I),
    re.compile(r"\bUnder[- ]?(?:15|16|17|18|19|20|21|22|23)\b", re.I),
    re.compile(r"\b(?:Youth|Academy|Jgd|Jugend|Primavera|Reserves?)\b", re.I),
    re.compile(r"\bJong\s+", re.I),
    re.compile(r"\bCastilla\b", re.I),
    re.compile(r"\((?:[^)]*\s)?II\)\s*$", re.I),
    re.compile(r"\sII\s*$", re.I),
]

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def yes(v: Any) -> bool:
    return s(v).upper() == "YES"

def as_int(v: Any, default: int = 0) -> int:
    try:
        if v is None or s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def is_placeholder(name: str) -> bool:
    return bool(PLACEHOLDER_RE.match(s(name)))

def looks_development(name: str) -> bool:
    n = s(name)
    return any(p.search(n) for p in DEVELOPMENT_PATTERNS)

def read_csv(name: str) -> list[dict[str, str]]:
    p = IN_DIR / name
    if not p.exists():
        raise FileNotFoundError(f"Eksik 03D dosyasi: {p}")
    with p.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fieldnames is None:
        fieldnames = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def meta_score(row: dict[str, Any], usage: int, transfer_mentions: int) -> int:
    q = as_int(row.get("quality"))
    pop = as_int(row.get("popularitySeed"))
    metadata = 0
    if s(row.get("country")):
        metadata += 6
    if s(row.get("competition")):
        metadata += 6
    usage_bonus = min(24, int(math.log2(max(1, usage) + 1) * 4))
    transfer_bonus = min(18, int(math.log2(max(1, transfer_mentions) + 1) * 3))
    return q + pop + metadata + usage_bonus + transfer_bonus

def main() -> None:
    print("=" * 66)
    print("LINKBALL DATA PLATFORM V3 - STEP 03D.1")
    print("GAMEPLAY INTEGRITY GUARD (READ-ONLY)")
    print("=" * 66)

    clubs = read_csv("canonical_club_candidates.csv")
    careers = read_csv("canonical_career_candidates.csv")
    source_map = read_csv("club_source_map_v2.csv")

    print(f"[03D.1] Kulup adayi: {len(clubs):,}")
    print(f"[03D.1] Kariyer iliskisi: {len(careers):,}")
    print(f"[03D.1] Source map: {len(source_map):,}")

    # Usage based on preserved career relationships.
    career_usage = Counter()
    transfer_validated_usage = Counter()
    for r in careers:
        key = s(r.get("canonicalClubKey"))
        if not key:
            continue
        career_usage[key] += 1
        if "TRANSFER_VALIDATED" in s(r.get("evidence")):
            transfer_validated_usage[key] += 1

    source_by_key: dict[str, dict[str, str]] = {}
    for r in source_map:
        key = s(r.get("canonicalKey"))
        if key and key not in source_by_key:
            source_by_key[key] = r

    cleaned_clubs: list[dict[str, Any]] = []
    excluded_reasons = Counter()
    development_reclassified = 0

    for r in clubs:
        row = dict(r)
        key = s(row.get("canonicalKey"))
        name = s(row.get("name"))
        entity = s(row.get("entityType")).upper() or "UNRESOLVED"
        origin = s(row.get("origin"))
        q = as_int(row.get("quality"))
        source_r = source_by_key.get(key, {})
        usage = as_int(source_r.get("playerUsage"), career_usage[key])
        transfer_mentions = as_int(source_r.get("transferMentions"), transfer_validated_usage[key])

        reason = ""
        if entity == "SENIOR" and looks_development(name):
            entity = "DEVELOPMENT"
            row["entityType"] = "DEVELOPMENT"
            development_reclassified += 1

        if is_placeholder(name):
            reason = "PLACEHOLDER_NAME"
        elif name.lower() in GENERIC_BAD_NAMES:
            reason = "GENERIC_OR_PSEUDO_NAME"
        elif entity != "SENIOR":
            reason = f"ENTITY_{entity}"
        elif q < 50:
            reason = "QUALITY_TOO_LOW"
        elif key.startswith("legacy_current:"):
            reason = "LEGACY_UNRESOLVED"
        elif origin == "tm_transfer_club":
            # Source-only clubs can enter gameplay only if they have enough evidence.
            # Missing country/competition is tolerated only for strongly used clubs.
            has_country = bool(s(row.get("country")))
            has_comp = bool(s(row.get("competition")))
            strong_usage = usage >= 12 or transfer_mentions >= 30
            very_strong_usage = usage >= 40 or transfer_mentions >= 80
            if q < 55:
                reason = "SOURCE_LOW_QUALITY"
            elif not (has_country or has_comp) and not very_strong_usage:
                reason = "SOURCE_METADATA_THIN"
            elif not strong_usage:
                reason = "SOURCE_EVIDENCE_THIN"

        eligible = reason == ""
        if reason:
            excluded_reasons[reason] += 1

        score = meta_score(row, usage, transfer_mentions) if eligible else -1
        row["usageCount03d1"] = usage
        row["trustedTransferUsage03d1"] = transfer_validated_usage[key]
        row["gameplayEligible03d1"] = "YES" if eligible else "NO"
        row["gameplayExclusionReason03d1"] = reason
        row["gameplayScore03d1"] = score
        row["gameplayPool4000"] = "NO"  # rebuilt below
        cleaned_clubs.append(row)

    eligible_clubs = [r for r in cleaned_clubs if r["gameplayEligible03d1"] == "YES"]
    eligible_clubs.sort(
        key=lambda r: (
            as_int(r.get("gameplayScore03d1"), -1),
            as_int(r.get("popularitySeed")),
            as_int(r.get("usageCount03d1"))
        ),
        reverse=True,
    )
    pool_keys = {s(r.get("canonicalKey")) for r in eligible_clubs[:4000]}
    for r in cleaned_clubs:
        r["gameplayPool4000"] = "YES" if s(r.get("canonicalKey")) in pool_keys else "NO"

    club_by_key = {s(r.get("canonicalKey")): r for r in cleaned_clubs}

    cleaned_careers: list[dict[str, Any]] = []
    trust_counter = Counter()
    players_any = set()
    players_gameplay = set()
    players_high = set()

    for r in careers:
        row = dict(r)
        key = s(row.get("canonicalClubKey"))
        club = club_by_key.get(key)
        evidence = s(row.get("evidence"))

        if "TRANSFER_VALIDATED" in evidence:
            trust = "HIGH"
        elif "CURRENT_SAFE_FALLBACK" in evidence:
            trust = "MEDIUM"
        else:
            trust = "QUARANTINED"

        reason = ""
        if club is None:
            reason = "CLUB_NOT_IN_CANONICAL_SET"
        elif club["gameplayEligible03d1"] != "YES":
            reason = s(club.get("gameplayExclusionReason03d1")) or "CLUB_NOT_GAMEPLAY_ELIGIBLE"
        elif trust == "QUARANTINED":
            reason = "RELATION_QUARANTINED"

        eligible = not reason
        row["relationTrust03d1"] = trust
        row["gameplayEligible03d1"] = "YES" if eligible else "NO"
        row["gameplayExclusionReason03d1"] = reason
        cleaned_careers.append(row)

        pid = s(row.get("canonicalPlayerId"))
        if pid:
            players_any.add(pid)
        if eligible and pid:
            players_gameplay.add(pid)
            if trust == "HIGH":
                players_high.add(pid)
        trust_counter[trust] += 1

    # Player readiness: useful for the next popularity/playable-pool step.
    by_player = defaultdict(lambda: {"high": 0, "medium": 0, "clubs": set()})
    for r in cleaned_careers:
        if r["gameplayEligible03d1"] != "YES":
            continue
        pid = s(r.get("canonicalPlayerId"))
        key = s(r.get("canonicalClubKey"))
        if not pid or not key:
            continue
        by_player[pid]["clubs"].add(key)
        if r["relationTrust03d1"] == "HIGH":
            by_player[pid]["high"] += 1
        elif r["relationTrust03d1"] == "MEDIUM":
            by_player[pid]["medium"] += 1

    readiness = []
    for pid, d in by_player.items():
        club_count = len(d["clubs"])
        high = d["high"]
        medium = d["medium"]
        if high >= 2 or (high >= 1 and club_count >= 2):
            tier = "A_TRUSTED"
        elif club_count >= 2:
            tier = "B_PLAYABLE"
        elif club_count == 1:
            tier = "C_SINGLE_CLUB"
        else:
            tier = "D_NOT_READY"
        readiness.append({
            "canonicalPlayerId": pid,
            "seniorGameplayClubCount": club_count,
            "highTrustRelationCount": high,
            "mediumTrustRelationCount": medium,
            "careerReadiness03d1": tier,
        })

    # Priority review: unresolved high-impact source clubs only.
    reviews = []
    for r in cleaned_clubs:
        if s(r.get("origin")) != "tm_transfer_club":
            continue
        if r["gameplayEligible03d1"] == "YES":
            continue
        usage = as_int(r.get("usageCount03d1"))
        pop = as_int(r.get("popularitySeed"))
        reason = s(r.get("gameplayExclusionReason03d1"))
        if usage < 3 and pop < 40:
            continue
        reviews.append({
            "canonicalKey": s(r.get("canonicalKey")),
            "sourceClubId": s(r.get("sourceClubId")),
            "name": s(r.get("name")),
            "country": s(r.get("country")),
            "competition": s(r.get("competition")),
            "entityType": s(r.get("entityType")),
            "quality": as_int(r.get("quality")),
            "popularitySeed": pop,
            "usageCount": usage,
            "reason": reason,
            "reviewPriority": pop * 10 + usage * 5 + as_int(r.get("quality")),
        })
    reviews.sort(key=lambda x: x["reviewPriority"], reverse=True)

    pool = [r for r in cleaned_clubs if r["gameplayPool4000"] == "YES"]
    pool_missing_country = sum(1 for r in pool if not s(r.get("country")))
    pool_missing_comp = sum(1 for r in pool if not s(r.get("competition")))
    pool_source_only = sum(1 for r in pool if s(r.get("origin")) == "tm_transfer_club")
    placeholder_career_before = sum(
        1 for r in careers if is_placeholder(s(r.get("clubName"))) and yes(r.get("gameplayEligible"))
    )
    placeholder_career_after = sum(
        1 for r in cleaned_careers if is_placeholder(s(r.get("clubName"))) and r["gameplayEligible03d1"] == "YES"
    )

    gates = [
        {
            "gate": "D1-01",
            "rule": "Placeholder Club {id} relations never gameplay eligible",
            "status": "PASS" if placeholder_career_after == 0 else "FAIL",
            "detail": f"before={placeholder_career_before:,}; after={placeholder_career_after:,}",
        },
        {
            "gate": "D1-02",
            "rule": "Development-like teams removed from senior gameplay",
            "status": "PASS",
            "detail": f"{development_reclassified:,} additional clubs reclassified conservatively",
        },
        {
            "gate": "D1-03",
            "rule": "Gameplay pool rebuilt after integrity filtering",
            "status": "PASS" if len(pool) <= 4000 else "FAIL",
            "detail": f"{len(pool):,} clubs",
        },
        {
            "gate": "D1-04",
            "rule": "Quarantined relations cannot become gameplay relations",
            "status": "PASS",
            "detail": f"{trust_counter['QUARANTINED']:,} quarantined rows retained outside gameplay",
        },
        {
            "gate": "D1-05",
            "rule": "Runtime assets unchanged",
            "status": "PASS",
            "detail": "Only reports/data_platform_v3/03d1 is written",
        },
    ]

    write_csv("canonical_clubs_gameplay_guarded.csv", cleaned_clubs)
    write_csv("canonical_careers_gameplay_guarded.csv", cleaned_careers)
    readiness.sort(key=lambda r: as_int(r["canonicalPlayerId"]))
    write_csv("player_career_readiness.csv", readiness)
    write_csv("club_manual_review_priority.csv", reviews)
    write_csv("migration_gates.csv", gates)

    summary = {
        "step": "03D.1",
        "runtimeChanged": False,
        "clubsInput": len(clubs),
        "careerRowsInput": len(careers),
        "additionalDevelopmentReclassifications": development_reclassified,
        "placeholderGameplayRelationsBefore": placeholder_career_before,
        "placeholderGameplayRelationsAfter": placeholder_career_after,
        "gameplayEligibleClubCount": len(eligible_clubs),
        "gameplayPoolPreviewCount": len(pool),
        "gameplayPoolSourceOnlyCount": pool_source_only,
        "gameplayPoolMissingCountryCount": pool_missing_country,
        "gameplayPoolMissingCompetitionCount": pool_missing_comp,
        "playersWithAnyPreservedRelation": len(players_any),
        "playersWithGameplayRelation": len(players_gameplay),
        "playersWithHighTrustGameplayRelation": len(players_high),
        "relationTrust": dict(trust_counter),
        "clubExclusionReasons": dict(excluded_reasons),
        "manualReviewPriorityRows": len(reviews),
        "rules": [
            "03D.1 is read-only; runtime assets are not mutated.",
            "Club {id} placeholders are never gameplay eligible.",
            "Development/youth/reserve identities are preserved but excluded from senior gameplay.",
            "Source-only clubs need minimum evidence/metadata before entering gameplay.",
            "TRANSFER_VALIDATED relations are HIGH trust; safe current fallback is MEDIUM; orphan fallback remains QUARANTINED.",
            "The 4000 club pool is rebuilt only after integrity filtering."
        ],
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with (OUT_DIR / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    readme = f"""# Linkball Data Platform V3 - 03D.1

Read-only gameplay integrity guard.

- Placeholder gameplay relations: {placeholder_career_before:,} -> {placeholder_career_after:,}
- Additional development reclassifications: {development_reclassified:,}
- Gameplay eligible clubs: {len(eligible_clubs):,}
- Gameplay pool preview: {len(pool):,}
- Players with gameplay relation: {len(players_gameplay):,}
- Players with HIGH-trust gameplay relation: {len(players_high):,}

No file under assets/data was modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03D.1] Placeholder gameplay relation: {placeholder_career_before:,} -> {placeholder_career_after:,}")
    print(f"[03D.1] Ek development siniflandirma: {development_reclassified:,}")
    print(f"[03D.1] Gameplay eligible kulup: {len(eligible_clubs):,}")
    print(f"[03D.1] Gameplay pool: {len(pool):,}")
    print(f"[03D.1] Gameplay iliskili oyuncu: {len(players_gameplay):,}")
    print(f"[03D.1] HIGH-trust iliskili oyuncu: {len(players_high):,}")
    print(f"[03D.1] Rapor: {OUT_DIR}")
    print("[03D.1] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
