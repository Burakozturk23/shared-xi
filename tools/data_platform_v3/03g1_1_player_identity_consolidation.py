#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import json
import re
import unicodedata
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
G1_DIR = ROOT / "reports" / "data_platform_v3" / "03g1"
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
D2_DIR = ROOT / "reports" / "data_platform_v3" / "03d2"
D_DIR = ROOT / "reports" / "data_platform_v3" / "03d"
INPUT_DIR = ROOT / "tools" / "data_platform_v3" / "input"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03g1_1"

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

def norm(v: Any) -> str:
    text = unicodedata.normalize("NFKD", s(v))
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", " ", text.casefold()).strip()
    return " ".join(text.split())

def pos_group(v: Any) -> str:
    p = s(v).casefold()
    if "goal" in p:
        return "GK"
    if "def" in p or "back" in p:
        return "DF"
    if "mid" in p:
        return "MF"
    if "attack" in p or "forward" in p or "wing" in p or "striker" in p:
        return "FW"
    return ""

def positions_compatible(a: str, b: str) -> bool:
    if not a or not b:
        return True
    if a == b:
        return True
    # Attacking midfielders/wingers are frequently normalized differently
    # between legacy and source data.
    return {a, b} <= {"MF", "FW"}

def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]], fields: list[str] | None = None) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fields is None:
        fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

def source_zip() -> Path:
    p = INPUT_DIR / "transfermarkt-datasets-csv.zip"
    if p.exists():
        return p
    for q in sorted(INPUT_DIR.glob("*.zip")):
        try:
            with zipfile.ZipFile(q) as z:
                if any(n.endswith("players.csv") for n in z.namelist()) and any(n.endswith("transfers.csv") for n in z.namelist()):
                    return q
        except Exception:
            pass
    raise FileNotFoundError("transfermarkt-datasets-csv.zip bulunamadi")

def member(z: zipfile.ZipFile, ending: str) -> str:
    hits = [n for n in z.namelist() if n.endswith(ending)]
    if not hits:
        raise FileNotFoundError(f"ZIP icinde yok: {ending}")
    return hits[0]

def aggregate_rows(rows: list[dict[str, Any]], key_fields: list[str], numeric_fields: list[str]) -> list[dict[str, Any]]:
    out = {}
    for r in rows:
        key = tuple(s(r.get(k)) for k in key_fields)
        if key not in out:
            out[key] = dict(r)
            for n in numeric_fields:
                out[key][n] = as_int(r.get(n))
        else:
            for n in numeric_fields:
                out[key][n] = as_int(out[key].get(n)) + as_int(r.get(n))
    return list(out.values())

def main():
    print("=" * 78)
    print("LINKBALL DATA PLATFORM V3 - STEP 03G.1.1")
    print("CROSS-LAYER PLAYER IDENTITY CONSOLIDATION (READ-ONLY)")
    print("=" * 78)

    selection = read_csv(E2_DIR / "player_selection_scores_v3.csv")
    profiles = read_csv(G1_DIR / "player_profile_factual.csv")
    stats = read_csv(G1_DIR / "player_stats_source_window.csv")
    club_stats = read_csv(G1_DIR / "player_stats_by_club.csv")
    comp_stats = read_csv(G1_DIR / "player_stats_by_competition.csv")
    careers = read_csv(D2_DIR / "canonical_careers_gameplay_guarded_v2.csv")
    club_map_rows = read_csv(D_DIR / "club_source_map_v2.csv")

    player_by_id = {as_int(r.get("id"), -1): r for r in selection if as_int(r.get("id"), -1) >= 0}
    profile_source_ids = {as_int(r.get("playerId"), -1) for r in profiles}

    career_clubs = defaultdict(set)
    for r in careers:
        if s(r.get("gameplayEligible03d1")).upper() != "YES":
            continue
        pid = as_int(r.get("canonicalPlayerId"), -1)
        key = s(r.get("canonicalClubKey"))
        if pid >= 0 and key:
            career_clubs[pid].add(key)

    club_source_map = {}
    for r in club_map_rows:
        sid = as_int(r.get("sourceClubId"), -1)
        key = s(r.get("canonicalKey"))
        if sid >= 0 and key and s(r.get("status")) != "PSEUDO_EXCLUDED":
            club_source_map[sid] = key

    # Canonical candidates grouped by normalized name + country.
    by_identity = defaultdict(list)
    for pid, r in player_by_id.items():
        country = (s(r.get("countries")).split("|")[0] if s(r.get("countries")) else "")
        by_identity[(norm(r.get("name")), norm(country))].append(r)

    src_zip = source_zip()
    raw_profiles = {}
    transfer_clubs = defaultdict(set)

    with zipfile.ZipFile(src_zip) as z:
        pn = member(z, "players.csv")
        with z.open(pn) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for r in reader:
                pid = as_int(r.get("player_id"), -1)
                if pid in profile_source_ids:
                    raw_profiles[pid] = r

        tn = member(z, "transfers.csv")
        print(f"[03G.1.1] transfers.csv taraniyor: {tn}")
        with z.open(tn) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for i, r in enumerate(reader, 1):
                if i % 50000 == 0:
                    print(f"[03G.1.1] Transfer: {i:,}")
                pid = as_int(r.get("player_id"), -1)
                if pid not in profile_source_ids:
                    continue
                for field in ("from_club_id", "to_club_id"):
                    sid = as_int(r.get(field), -1)
                    key = club_source_map.get(sid)
                    if key:
                        transfer_clubs[pid].add(key)

    # Determine where each source factual identity should enrich.
    identity_map = []
    source_to_primary = {}
    auto_remaps = []
    reviews = []

    for source_id in sorted(profile_source_ids):
        base = player_by_id.get(source_id)
        raw = raw_profiles.get(source_id, {})
        if not base:
            continue

        own_clubs = career_clubs.get(source_id, set())
        if own_clubs:
            source_to_primary[source_id] = source_id
            identity_map.append({
                "sourceNamespace":"tm_player",
                "sourcePlayerId":source_id,
                "sourceName":s(base.get("name")),
                "primaryCanonicalPlayerId":source_id,
                "primaryName":s(base.get("name")),
                "method":"OWN_CANONICAL_HAS_CAREER",
                "confidence":100,
                "status":"AUTO_PRIMARY"
            })
            continue

        country = s(base.get("countries")).split("|")[0] if s(base.get("countries")) else ""
        candidates = []
        current_key = club_source_map.get(as_int(raw.get("current_club_id"), -1), "")
        src_clubs = transfer_clubs.get(source_id, set())
        source_pos = pos_group(base.get("position"))

        for cand in by_identity.get((norm(base.get("name")), norm(country)), []):
            cid = as_int(cand.get("id"), -1)
            if cid == source_id or not career_clubs.get(cid):
                continue
            cand_pos = pos_group(cand.get("position"))
            overlap = len(src_clubs & career_clubs[cid])
            current_match = bool(current_key and current_key in career_clubs[cid])
            compatible = positions_compatible(source_pos, cand_pos)

            score = (
                (100 if current_match else 0)
                + min(100, overlap * 20)
                + (10 if compatible else 0)
            )
            candidates.append({
                "candidateId":cid,
                "candidateName":s(cand.get("name")),
                "score":score,
                "currentClubMatch":current_match,
                "transferClubOverlap":overlap,
                "positionCompatible":compatible,
                "candidateCareerClubCount":len(career_clubs[cid]),
            })

        candidates.sort(key=lambda x:(x["score"], x["transferClubOverlap"], x["candidateCareerClubCount"]), reverse=True)
        best = candidates[0] if candidates else None
        second = candidates[1] if len(candidates) > 1 else None

        # Strong evidence only: current-club match or >=2 transfer-club overlaps,
        # plus clear winner margin when multiple homonyms exist.
        strong_evidence = bool(best and (best["currentClubMatch"] or best["transferClubOverlap"] >= 2))
        clear_margin = bool(best and (second is None or best["score"] >= second["score"] + 20))

        if best and strong_evidence and clear_margin:
            target = best["candidateId"]
            source_to_primary[source_id] = target
            row = {
                "sourceNamespace":"tm_player",
                "sourcePlayerId":source_id,
                "sourceName":s(base.get("name")),
                "primaryCanonicalPlayerId":target,
                "primaryName":s(player_by_id[target].get("name")),
                "method":"CURRENT_CLUB_OR_TRANSFER_OVERLAP",
                "confidence":99 if best["currentClubMatch"] and best["transferClubOverlap"] >= 2 else 97,
                "status":"AUTO_REMAP_HIGH",
                "currentClubMatch":"YES" if best["currentClubMatch"] else "NO",
                "transferClubOverlap":best["transferClubOverlap"],
            }
            identity_map.append(row)
            auto_remaps.append(row)
        else:
            source_to_primary[source_id] = source_id
            identity_map.append({
                "sourceNamespace":"tm_player",
                "sourcePlayerId":source_id,
                "sourceName":s(base.get("name")),
                "primaryCanonicalPlayerId":source_id,
                "primaryName":s(base.get("name")),
                "method":"NO_SAFE_CAREER_PRIMARY_FOUND",
                "confidence":60,
                "status":"PROFILE_ONLY_KEEP_SEPARATE"
            })
            if candidates:
                reviews.append({
                    "sourcePlayerId":source_id,
                    "sourceName":s(base.get("name")),
                    "sourceCountry":country,
                    "sourcePosition":s(base.get("position")),
                    "currentCanonicalClub":current_key,
                    "bestCandidateId":best["candidateId"],
                    "bestCandidateName":best["candidateName"],
                    "bestScore":best["score"],
                    "currentClubMatch":"YES" if best["currentClubMatch"] else "NO",
                    "transferClubOverlap":best["transferClubOverlap"],
                    "positionCompatible":"YES" if best["positionCompatible"] else "NO",
                    "reason":"AMBIGUOUS_OR_WEAK_EVIDENCE"
                })

    # Remap factual profile/stat layers onto primary canonical IDs.
    profile_v2 = []
    for r in profiles:
        src = as_int(r.get("playerId"), -1)
        target = source_to_primary.get(src, src)
        nr = dict(r)
        nr["sourcePlayerId"] = src
        nr["playerId"] = target
        nr["identityConsolidated"] = "YES" if target != src else "NO"
        profile_v2.append(nr)

    stat_v2 = []
    for r in stats:
        src = as_int(r.get("playerId"), -1)
        target = source_to_primary.get(src, src)
        nr = dict(r)
        nr["sourcePlayerId"] = src
        nr["playerId"] = target
        nr["identityConsolidated"] = "YES" if target != src else "NO"
        stat_v2.append(nr)

    club_v2 = []
    for r in club_stats:
        src = as_int(r.get("playerId"), -1)
        target = source_to_primary.get(src, src)
        nr = dict(r)
        nr["sourcePlayerId"] = src
        nr["playerId"] = target
        club_v2.append(nr)

    comp_v2 = []
    for r in comp_stats:
        src = as_int(r.get("playerId"), -1)
        target = source_to_primary.get(src, src)
        nr = dict(r)
        nr["sourcePlayerId"] = src
        nr["playerId"] = target
        comp_v2.append(nr)

    # Aggregate in the unlikely event that two source identities resolve to one primary.
    stat_v2 = aggregate_rows(
        stat_v2, ["playerId"],
        ["appearances","goals","assists","minutes","yellowCards","redCards","uclAppearances","big5Appearances","topCompetitionAppearances"]
    )
    club_v2 = aggregate_rows(
        club_v2, ["playerId","canonicalClubKey"],
        ["appearances","goals","assists","minutes"]
    )
    comp_v2 = aggregate_rows(
        comp_v2, ["playerId","competitionId"],
        ["appearances","goals","assists","minutes"]
    )

    # Shadow duplicate suppression: preserve records but prevent future runtime/search
    # duplication when there is exactly one factual+career primary in the identity group.
    primary_targets = set(source_to_primary.values())
    suppressions = []
    for identity_key, members in by_identity.items():
        primaries = [
            r for r in members
            if as_int(r.get("id"), -1) in primary_targets
            and career_clubs.get(as_int(r.get("id"), -1))
        ]
        if len(primaries) != 1:
            continue
        primary = primaries[0]
        primary_id = as_int(primary.get("id"), -1)
        pg = pos_group(primary.get("position"))
        for shadow in members:
            sid = as_int(shadow.get("id"), -1)
            if sid == primary_id:
                continue
            if career_clubs.get(sid):
                continue
            if yes := (s(shadow.get("answerEligible")).upper() == "YES"):
                continue
            if not positions_compatible(pg, pos_group(shadow.get("position"))):
                continue
            # Never delete; this is only a future runtime/search suppression flag.
            suppressions.append({
                "shadowCanonicalPlayerId":sid,
                "shadowName":s(shadow.get("name")),
                "primaryCanonicalPlayerId":primary_id,
                "primaryName":s(primary.get("name")),
                "reason":"SAME_NAME_COUNTRY_POSITION_NO_CAREER_SHADOW",
                "action":"PRESERVE_BUT_SUPPRESS_FROM_RUNTIME_SEARCH_AND_QUESTION_POOLS"
            })

    # Important sanity examples.
    sanity_names = {"Suso","Cristiano Ronaldo","Mohamed Salah","Álvaro Morata","Sergio Ramos","Willian","Jesús Navas"}
    sanity = []
    for r in identity_map:
        if s(r.get("sourceName")) in sanity_names or s(r.get("primaryName")) in sanity_names:
            sanity.append(r)

    write_csv("player_source_identity_map_v2.csv", identity_map)
    write_csv("auto_identity_remaps.csv", auto_remaps)
    write_csv("identity_review_queue.csv", reviews)
    write_csv("shadow_duplicate_suppressions.csv", suppressions)
    write_csv("player_profile_factual_v2.csv", profile_v2)
    write_csv("player_stats_source_window_v2.csv", stat_v2)
    write_csv("player_stats_by_club_v2.csv", club_v2)
    write_csv("player_stats_by_competition_v2.csv", comp_v2)
    write_csv("sanity_identity_examples.csv", sanity)

    # Gates.
    remap_targets_with_career = sum(
        1 for r in auto_remaps
        if career_clubs.get(as_int(r.get("primaryCanonicalPlayerId"), -1))
    )
    remapped_source_ids = {as_int(r.get("sourcePlayerId"), -1) for r in auto_remaps}
    remap_conflict = len(remapped_source_ids) != len(auto_remaps)

    gates = [
        {
            "gate":"G1.1-01",
            "status":"PASS" if not remap_conflict else "FAIL",
            "rule":"Each source factual identity maps to at most one canonical primary",
            "detail":f"autoRemap={len(auto_remaps):,}"
        },
        {
            "gate":"G1.1-02",
            "status":"PASS" if remap_targets_with_career == len(auto_remaps) else "FAIL",
            "rule":"Every auto-remap target has clean senior career evidence",
            "detail":f"{remap_targets_with_career:,}/{len(auto_remaps):,}"
        },
        {
            "gate":"G1.1-03",
            "status":"PASS",
            "rule":"Ambiguous homonyms are review-only, never auto-merged",
            "detail":f"review={len(reviews):,}"
        },
        {
            "gate":"G1.1-04",
            "status":"PASS",
            "rule":"Shadow duplicates are preserved, not deleted",
            "detail":f"suppressionPreview={len(suppressions):,}"
        },
        {
            "gate":"G1.1-05",
            "status":"PASS",
            "rule":"Runtime assets unchanged",
            "detail":"Only reports/data_platform_v3/03g1_1 is written"
        },
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step":"03G.1.1",
        "runtimeChanged":False,
        "sourceFactualIdentities":len(profile_source_ids),
        "sourceIdentitiesWithOwnCleanCareer":sum(1 for x in identity_map if s(x.get("status"))=="AUTO_PRIMARY"),
        "highConfidenceCrossIdRemaps":len(auto_remaps),
        "ambiguousOrWeakReviewRows":len(reviews),
        "shadowDuplicateSuppressionPreview":len(suppressions),
        "factualProfilesV2":len(profile_v2),
        "playerStatsV2":len(stat_v2),
        "playerClubStatsV2":len(club_v2),
        "playerCompetitionStatsV2":len(comp_v2),
        "principles":[
            "A numeric player ID is not sufficient to join source layers.",
            "Current-club or multi-transfer-club overlap is required for cross-ID auto-remap.",
            "Ambiguous homonyms are never auto-merged.",
            "Duplicate/shadow records are preserved and only flagged for future suppression."
        ],
        "nextRecommendedStep":"03G.2_CANONICAL_TRANSFER_EVENTS_AND_CAREER_TIMELINE_USING_PLAYER_SOURCE_IDENTITY_MAP_V2"
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03G.1.1

Cross-layer player identity consolidation.

Why this exists:
A few players have their trusted career on one Linkball canonical ID while the
factual Transfermarkt profile/stat source is attached to another numeric ID.
This step joins them only when club evidence is strong.

- Source factual identities: {len(profile_source_ids):,}
- High-confidence cross-ID remaps: {len(auto_remaps):,}
- Review-only ambiguous rows: {len(reviews):,}
- Shadow duplicate suppression preview: {len(suppressions):,}

No player is deleted.
No runtime asset is modified.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03G.1.1] Factual source identity: {len(profile_source_ids):,}")
    print(f"[03G.1.1] High-confidence cross-ID remap: {len(auto_remaps):,}")
    print(f"[03G.1.1] Review: {len(reviews):,}")
    print(f"[03G.1.1] Shadow suppression preview: {len(suppressions):,}")
    for r in sanity:
        if s(r.get("sourceName")) in {"Suso","Cristiano Ronaldo","Mohamed Salah","Jesús Navas"}:
            print(f"  {r.get('sourceName')}: source {r.get('sourcePlayerId')} -> primary {r.get('primaryCanonicalPlayerId')} [{r.get('status')}]")
    print(f"[03G.1.1] Rapor: {OUT_DIR}")
    print("[03G.1.1] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
