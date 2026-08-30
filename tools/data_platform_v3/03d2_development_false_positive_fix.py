#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
IN_DIR = ROOT / "reports" / "data_platform_v3" / "03d1"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03d2"

# Known senior clubs whose legal/historic name can look like a reserve marker.
# Keep this list intentionally tiny and reviewable.
SENIOR_NAME_EXCEPTIONS = {
    "willem ii",
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

def read_csv(name: str):
    p = IN_DIR / name
    if not p.exists():
        raise FileNotFoundError(f"Eksik 03D.1 dosyasi: {p}")
    with p.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def eligible_score(row):
    # Preserve the 03D.1 score logic enough for a correction pass.
    q = as_int(row.get("quality"))
    pop = as_int(row.get("popularitySeed"))
    usage = as_int(row.get("usageCount03d1"))
    transfer = as_int(row.get("trustedTransferUsage03d1"))
    meta = (6 if s(row.get("country")) else 0) + (6 if s(row.get("competition")) else 0)
    usage_bonus = min(24, max(0, usage // 5))
    transfer_bonus = min(18, max(0, transfer // 8))
    return q + pop + meta + usage_bonus + transfer_bonus

def main():
    print("=" * 68)
    print("LINKBALL DATA PLATFORM V3 - STEP 03D.2")
    print("DEVELOPMENT FALSE-POSITIVE CORRECTION (READ-ONLY)")
    print("=" * 68)

    clubs = read_csv("canonical_clubs_gameplay_guarded.csv")
    careers = read_csv("canonical_careers_gameplay_guarded.csv")
    readiness = read_csv("player_career_readiness.csv")

    restored_keys = set()
    restored_clubs = []

    for row in clubs:
        name_key = s(row.get("name")).casefold()
        if name_key in SENIOR_NAME_EXCEPTIONS and s(row.get("entityType")).upper() == "DEVELOPMENT":
            row["entityType"] = "SENIOR"
            row["gameplayEligible03d1"] = "YES"
            row["gameplayExclusionReason03d1"] = ""
            row["gameplayScore03d1"] = str(eligible_score(row))
            restored_keys.add(s(row.get("canonicalKey")))
            restored_clubs.append({
                "canonicalKey": s(row.get("canonicalKey")),
                "name": s(row.get("name")),
                "country": s(row.get("country")),
                "competition": s(row.get("competition")),
                "reason": "KNOWN_SENIOR_NAME_EXCEPTION",
            })

    # Rebuild pool after correction.
    eligible = [r for r in clubs if s(r.get("gameplayEligible03d1")).upper() == "YES"]
    eligible.sort(
        key=lambda r: (
            as_int(r.get("gameplayScore03d1"), -1),
            as_int(r.get("popularitySeed")),
            as_int(r.get("usageCount03d1")),
        ),
        reverse=True,
    )
    pool_keys = {s(r.get("canonicalKey")) for r in eligible[:4000]}
    for row in clubs:
        row["gameplayPool4000"] = "YES" if s(row.get("canonicalKey")) in pool_keys else "NO"

    restored_relations = 0
    for row in careers:
        if s(row.get("canonicalClubKey")) not in restored_keys:
            continue
        trust = s(row.get("relationTrust03d1")).upper()
        if trust in {"HIGH", "MEDIUM"}:
            row["entityType"] = "SENIOR"
            row["gameplayEligible03d1"] = "YES"
            row["gameplayExclusionReason03d1"] = ""
            restored_relations += 1

    # Rebuild readiness from corrected career rows.
    by_player = {}
    for row in careers:
        if s(row.get("gameplayEligible03d1")).upper() != "YES":
            continue
        pid = s(row.get("canonicalPlayerId"))
        if not pid:
            continue
        d = by_player.setdefault(pid, {"clubs": set(), "high": 0, "medium": 0})
        d["clubs"].add(s(row.get("canonicalClubKey")))
        trust = s(row.get("relationTrust03d1")).upper()
        if trust == "HIGH":
            d["high"] += 1
        elif trust == "MEDIUM":
            d["medium"] += 1

    readiness2 = []
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
        readiness2.append({
            "canonicalPlayerId": pid,
            "seniorGameplayClubCount": club_count,
            "highTrustRelationCount": high,
            "mediumTrustRelationCount": medium,
            "careerReadiness03d2": tier,
        })

    readiness2.sort(key=lambda r: as_int(r["canonicalPlayerId"]))

    # Audit any remaining high-quality DEVELOPMENT clubs with senior-looking metadata.
    review = []
    for row in clubs:
        if s(row.get("entityType")).upper() != "DEVELOPMENT":
            continue
        q = as_int(row.get("quality"))
        if q < 85:
            continue
        comp = s(row.get("competition"))
        if not comp:
            continue
        review.append({
            "canonicalKey": s(row.get("canonicalKey")),
            "name": s(row.get("name")),
            "country": s(row.get("country")),
            "competition": comp,
            "quality": q,
            "usageCount": as_int(row.get("usageCount03d1")),
            "note": "REVIEW_ONLY_NOT_AUTO_RESTORED",
        })
    review.sort(key=lambda r: (r["usageCount"], r["quality"]), reverse=True)

    write_csv("canonical_clubs_gameplay_guarded_v2.csv", clubs)
    write_csv("canonical_careers_gameplay_guarded_v2.csv", careers)
    write_csv("player_career_readiness_v2.csv", readiness2)
    write_csv("restored_senior_clubs.csv", restored_clubs)
    write_csv("development_review_watchlist.csv", review)

    summary = {
        "step": "03D.2",
        "runtimeChanged": False,
        "restoredSeniorClubCount": len(restored_clubs),
        "restoredSeniorRelationCount": restored_relations,
        "gameplayEligibleClubCount": len(eligible),
        "gameplayPoolPreviewCount": len(pool_keys),
        "playersWithGameplayRelation": len(by_player),
        "watchlistRows": len(review),
        "knownSeniorExceptions": sorted(SENIOR_NAME_EXCEPTIONS),
        "notes": [
            "This is a correction pass over 03D.1 outputs.",
            "Willem II is a senior Dutch club; the Roman numeral is part of its name.",
            "No assets/data file is modified.",
            "Remaining development candidates are review-only and are not auto-restored."
        ],
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    gates = [
        {"gate":"D2-01","status":"PASS" if len(restored_clubs) >= 1 else "WARN",
         "rule":"Known senior-name false positives restored",
         "detail":f"{len(restored_clubs)} club(s), {restored_relations} relations"},
        {"gate":"D2-02","status":"PASS",
         "rule":"No automatic restore outside explicit exception list",
         "detail":f"{len(review)} development rows left as review-only"},
        {"gate":"D2-03","status":"PASS",
         "rule":"Runtime assets unchanged",
         "detail":"Only reports/data_platform_v3/03d2 is written"},
    ]
    write_csv("migration_gates.csv", gates)

    readme = f"""# Linkball 03D.2

03D.1 development false-positive correction pass.

- Restored senior clubs: {len(restored_clubs)}
- Restored gameplay career relations: {restored_relations}
- Gameplay eligible clubs after correction: {len(eligible)}
- Development review watchlist: {len(review)}
- Runtime assets changed: NO

Known correction: Willem II is a senior club; `II` is part of the club name.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03D.2] Senior olarak geri alinan kulup: {len(restored_clubs):,}")
    print(f"[03D.2] Geri alinan gameplay kariyer iliskisi: {restored_relations:,}")
    print(f"[03D.2] Gameplay eligible kulup: {len(eligible):,}")
    print(f"[03D.2] Review watchlist: {len(review):,}")
    print(f"[03D.2] Rapor: {OUT_DIR}")
    print("[03D.2] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
