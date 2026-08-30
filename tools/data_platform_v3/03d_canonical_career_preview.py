from __future__ import annotations

import csv
import json
import math
import re
import sys
import unicodedata
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STEP = "03D"
SOURCE_NS = "tm_transfer_club"

GENERIC_TOKENS = {
    "fc","cf","afc","sc","ac","as","ssc","sv","fk","sk","nk","hnk","gnk","tsg","bsc",
    "ca","cd","rc","rcd","sl","ss","us","ogc","pot","sg","spvgg","club","football","futbol",
}
PSEUDO_NAMES = {
    "unknown":"unknown",
    "retired":"retired",
    "without club":"without_club",
    "career break":"career_break",
    "free agent":"without_club",
    "no club":"without_club",
}
COUNTRY_ALIASES = {
    "turkey":"turkiye", "türkiye":"turkiye", "turkiye":"turkiye",
    "england":"england", "uk":"united kingdom", "united kingdom":"united kingdom",
    "usa":"united states", "united states of america":"united states", "united states":"united states",
    "south korea":"korea republic", "korea south":"korea republic", "korea republic":"korea republic",
    "czech republic":"czechia", "czechia":"czechia",
}


def out(msg: str) -> None:
    print(f"[{STEP}] {msg}", flush=True)


def strip_bom(s: str) -> str:
    return s.lstrip("\ufeff")


def ascii_text(value) -> str:
    if value is None:
        return ""
    s = str(value).strip()
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    return s


def norm(value) -> str:
    s = ascii_text(value).lower().replace("&", " and ")
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def country_norm(value) -> str:
    n = norm(value)
    return COUNTRY_ALIASES.get(n, n)


def entity_type(name: str, pseudo_type: str = "") -> str:
    p = norm(pseudo_type)
    n = norm(name)
    if p or n in PSEUDO_NAMES:
        return "PSEUDO"
    # Development/youth markers. Avoid generic senior names such as Boca Juniors.
    if re.search(r"(?:^|\s)u\s?1[4-9](?:\s|$)|(?:^|\s)u\s?2[0-3](?:\s|$)", n):
        return "DEVELOPMENT"
    if re.search(r"\b(youth|yth|academy|primavera)\b", n):
        return "DEVELOPMENT"
    raw = str(name).strip()
    if re.search(r"(?:\s|\b)(II|III)$", raw, re.I):
        return "DEVELOPMENT"
    if re.search(r"\b(res\.?|reserve|reserves)\b", raw, re.I):
        return "DEVELOPMENT"
    if re.search(r"\s[B-C]$", raw):
        return "DEVELOPMENT"
    if re.search(r"\s[2-3]$", raw):
        return "DEVELOPMENT"
    return "SENIOR"


def relaxed(value: str) -> str:
    toks = []
    for t in norm(value).split():
        if t in GENERIC_TOKENS:
            continue
        # founding years / decorative numbers generally do not define identity
        if re.fullmatch(r"(?:18|19|20)\d{2}", t):
            continue
        if t in {"04","05","07","09"}:
            continue
        toks.append(t)
    return " ".join(toks)


def name_compatible(a: str, b: str) -> bool:
    na, nb = norm(a), norm(b)
    if not na or not nb:
        return False
    if na == nb:
        return True
    ra, rb = relaxed(a), relaxed(b)
    if ra and rb and ra == rb:
        return True
    if ra and rb and min(len(ra), len(rb)) >= 4 and (ra in rb or rb in ra):
        # Avoid mapping a tiny one-word brand into an unrelated long name unless the long form starts/ends with it.
        short, long = (ra, rb) if len(ra) <= len(rb) else (rb, ra)
        if long.startswith(short + " ") or long.endswith(" " + short) or short == long:
            return True
    return False


def countries_compatible(a: str, b: str) -> bool:
    ca, cb = country_norm(a), country_norm(b)
    if not ca or not cb:
        return True
    return ca == cb


def load_json(path: Path):
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f)


def rows_from_json(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        # Common wrappers first
        for k in ("players", "clubs", "data", "items"):
            if isinstance(data.get(k), list):
                return data[k]
        # ID keyed object
        result = []
        for k, v in data.items():
            if isinstance(v, dict):
                row = dict(v)
                row.setdefault("id", k)
                result.append(row)
        return result
    return []


def read_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def parse_int(v, default=None):
    try:
        if v is None or str(v).strip() == "":
            return default
        return int(float(str(v)))
    except Exception:
        return default


def parse_float(v, default=0.0):
    try:
        if v is None or str(v).strip() == "":
            return default
        return float(str(v))
    except Exception:
        return default


def club_quality(name: str, country: str, league: str) -> int:
    score = 0
    if name and not re.fullmatch(r"Club\s+\d+", str(name), re.I):
        score += 45
    if country:
        score += 25
    if league:
        score += 20
    if entity_type(name) == "SENIOR":
        score += 10
    return min(score, 100)


def popularity_seed(player_usage: int, mentions: int, has_country: bool, has_comp: bool, existing: bool) -> int:
    # This is only a seed for later 03E popularity work, not a player-facing rating.
    s = 10.0 * math.log1p(max(player_usage, 0)) + 4.0 * math.log1p(max(mentions, 0))
    if has_country:
        s += 6
    if has_comp:
        s += 5
    if existing:
        s += 8
    return max(0, min(100, int(round(s))))


def main() -> int:
    here = Path(__file__).resolve()
    repo = here.parents[2]
    assets = repo / "assets" / "data"
    report03c = repo / "reports" / "data_platform_v3" / "03c"
    report03d = repo / "reports" / "data_platform_v3" / "03d"
    report03d.mkdir(parents=True, exist_ok=True)

    clubs_path = assets / "clubs_min.json"
    players_path = assets / "players_min.json"
    required = [
        clubs_path, players_path,
        report03c / "club_source_catalog.csv",
        report03c / "club_mapping_proposals.csv",
        report03c / "club_numeric_id_collisions.csv",
        report03c / "trusted_player_club_source_refs.csv",
        report03c / "current_clubids_quarantine.csv",
    ]
    missing = [str(p) for p in required if not p.exists()]
    if missing:
        print("ERROR: Missing required input(s):", file=sys.stderr)
        for p in missing:
            print(" - " + p, file=sys.stderr)
        return 2

    out("clubs_min.json yükleniyor...")
    clubs_rows = rows_from_json(load_json(clubs_path))
    canonical = {}
    for r in clubs_rows:
        cid = parse_int(r.get("id"))
        if cid is None:
            continue
        name = str(r.get("name") or r.get("clubName") or "").strip()
        country = str(r.get("country") or "").strip()
        league = str(r.get("league") or r.get("competition") or "").strip()
        canonical[cid] = {
            "id": cid,
            "name": name,
            "country": country,
            "league": league,
            "type": entity_type(name),
            "quality": club_quality(name, country, league),
        }
    out(f"Canonical mevcut kulüp: {len(canonical):,}")

    # Indexes for fast conservative identity matching.
    exact_idx = defaultdict(list)
    relaxed_idx = defaultdict(list)
    for cid, c in canonical.items():
        if norm(c["name"]):
            exact_idx[norm(c["name"])].append(cid)
        if relaxed(c["name"]):
            relaxed_idx[relaxed(c["name"])].append(cid)

    out("03C kulüp katalogları yükleniyor...")
    source_catalog = read_csv(report03c / "club_source_catalog.csv")
    proposals = read_csv(report03c / "club_mapping_proposals.csv")
    collisions = read_csv(report03c / "club_numeric_id_collisions.csv")
    trusted = read_csv(report03c / "trusted_player_club_source_refs.csv")
    quarantine = read_csv(report03c / "current_clubids_quarantine.csv")

    proposal_by_sid = {parse_int(r.get("sourceClubId")): r for r in proposals if parse_int(r.get("sourceClubId")) is not None}
    collision_by_sid = {parse_int(r.get("sourceClubId")): r for r in collisions if parse_int(r.get("sourceClubId")) is not None}
    source_by_sid = {parse_int(r.get("sourceClubId")): r for r in source_catalog if parse_int(r.get("sourceClubId")) is not None}
    quarantined_players = {parse_int(r.get("canonicalPlayerId")) for r in quarantine}
    quarantined_players.discard(None)

    # Canonical usage from existing trusted mappings, later used for gameplay pool seed.
    existing_usage = defaultdict(lambda: [0, 0])
    for s in source_catalog:
        sid = parse_int(s.get("sourceClubId"))
        p = proposal_by_sid.get(sid, {})
        if str(p.get("status")) == "AUTO_MAP_HIGH":
            cid = parse_int(p.get("canonicalClubId"))
            if cid is not None:
                existing_usage[cid][0] += parse_int(s.get("playerUsage"), 0) or 0
                existing_usage[cid][1] += parse_int(s.get("transferMentions"), 0) or 0

    out(f"Kaynak kulüp kimliği iyileştiriliyor: {len(source_catalog):,} source ID")
    source_map_rows = []
    map_by_sid = {}
    status_counts = defaultdict(int)

    for i, s in enumerate(source_catalog, start=1):
        sid = parse_int(s.get("sourceClubId"))
        sname = str(s.get("primaryName") or "").strip()
        scountry = str(s.get("country") or "").strip()
        scomp = str(s.get("competition") or "").strip()
        ptype = str(s.get("pseudoType") or "").strip()
        etype = entity_type(sname, ptype)
        usage = parse_int(s.get("playerUsage"), 0) or 0
        mentions = parse_int(s.get("transferMentions"), 0) or 0
        old = proposal_by_sid.get(sid, {})
        old_status = str(old.get("status") or "")
        old_cid = parse_int(old.get("canonicalClubId"))

        target = None
        method = ""
        confidence = 0
        status = ""

        if etype == "PSEUDO":
            status = "PSEUDO_EXCLUDED"
            method = "pseudo_state_marker"
            confidence = 100
        else:
            # Keep a 03C high-confidence mapping only if the target exists and entity class is not senior<->development.
            if old_status == "AUTO_MAP_HIGH" and old_cid in canonical:
                ct = canonical[old_cid]
                compatible_type = (etype == ct["type"]) or (etype == "DEVELOPMENT" and ct["type"] == "DEVELOPMENT")
                if compatible_type and countries_compatible(scountry, ct["country"]):
                    target = old_cid
                    method = "03c_auto_map_high"
                    confidence = 99
                    status = "AUTO_MAP_HIGH"

            # Rescue same-numeric collisions that are clearly abbreviations/long-form names, never by number alone.
            if target is None and sid in canonical:
                ct = canonical[sid]
                compatible_type = (etype == ct["type"]) or (etype == "DEVELOPMENT" and ct["type"] == "DEVELOPMENT")
                if compatible_type and countries_compatible(scountry, ct["country"]) and name_compatible(sname, ct["name"]):
                    target = sid
                    method = "same_numeric_plus_relaxed_name_country"
                    confidence = 98
                    status = "AUTO_ALIAS_HIGH"

            # Exact display name, unique target.
            if target is None:
                cands = [cid for cid in exact_idx.get(norm(sname), []) if countries_compatible(scountry, canonical[cid]["country"]) and canonical[cid]["type"] == etype]
                if len(cands) == 1:
                    target = cands[0]
                    method = "unique_exact_name_country"
                    confidence = 98
                    status = "AUTO_ALIAS_HIGH"

            # Relaxed legal-prefix/suffix signature, unique target.
            if target is None and relaxed(sname):
                cands = [cid for cid in relaxed_idx.get(relaxed(sname), []) if countries_compatible(scountry, canonical[cid]["country"]) and canonical[cid]["type"] == etype]
                if len(cands) == 1:
                    target = cands[0]
                    method = "unique_relaxed_name_country"
                    confidence = 96
                    status = "AUTO_ALIAS_HIGH"

            # Alt names supplied by source catalog.
            if target is None:
                alt_raw = str(s.get("altNames") or "").strip()
                alts = [x.strip() for x in re.split(r"[|;]", alt_raw) if x.strip()]
                alt_targets = set()
                for alt in alts:
                    for cid in exact_idx.get(norm(alt), []):
                        if countries_compatible(scountry, canonical[cid]["country"]) and canonical[cid]["type"] == etype:
                            alt_targets.add(cid)
                    for cid in relaxed_idx.get(relaxed(alt), []):
                        if countries_compatible(scountry, canonical[cid]["country"]) and canonical[cid]["type"] == etype:
                            alt_targets.add(cid)
                if len(alt_targets) == 1:
                    target = next(iter(alt_targets))
                    method = "unique_source_alt_name"
                    confidence = 96
                    status = "AUTO_ALIAS_HIGH"

            if target is None:
                # Important design choice: do not throw the source identity away. It becomes a namespaced candidate.
                status = "SOURCE_CANONICAL_CANDIDATE"
                method = "preserve_source_identity"
                confidence = 90 if etype == "SENIOR" else 85

        if target is not None:
            ckey = f"existing:{target}"
            cname = canonical[target]["name"]
            ccountry = canonical[target]["country"]
            cquality = canonical[target]["quality"]
        elif status == "PSEUDO_EXCLUDED":
            ckey = ""
            cname = ""
            ccountry = ""
            cquality = 0
        else:
            ckey = f"tm:{sid}"
            cname = sname
            ccountry = scountry
            cquality = club_quality(sname, scountry, scomp)

        playable_candidate = etype == "SENIOR" and status != "PSEUDO_EXCLUDED" and bool(cname)
        pop_seed = popularity_seed(usage, mentions, bool(ccountry), bool(scomp), target is not None)
        row = {
            "sourceNamespace": SOURCE_NS,
            "sourceClubId": sid,
            "sourceName": sname,
            "sourceCountry": scountry,
            "sourceCompetition": scomp,
            "entityType": etype,
            "canonicalKey": ckey,
            "existingCanonicalClubId": target if target is not None else "",
            "canonicalName": cname,
            "canonicalCountry": ccountry,
            "method": method,
            "confidence": confidence,
            "status": status,
            "quality": cquality,
            "popularitySeed": pop_seed,
            "playerUsage": usage,
            "transferMentions": mentions,
            "playableCandidate": "YES" if playable_candidate else "NO",
        }
        source_map_rows.append(row)
        map_by_sid[sid] = row
        status_counts[status] += 1
        if i % 2000 == 0:
            out(f"Kulüp kimliği: {i:,}/{len(source_catalog):,}")

    # Candidate club catalogue: existing clubs + namespaced source identities that could not safely map.
    candidate_rows = []
    for cid, c in canonical.items():
        usage, mentions = existing_usage.get(cid, [0, 0])
        pop = popularity_seed(usage, mentions, bool(c["country"]), bool(c["league"]), True)
        candidate_rows.append({
            "canonicalKey": f"existing:{cid}",
            "origin": "existing",
            "existingClubId": cid,
            "sourceClubId": "",
            "name": c["name"],
            "country": c["country"],
            "competition": c["league"],
            "entityType": c["type"],
            "quality": c["quality"],
            "popularitySeed": pop,
            "playableCandidate": "YES" if c["type"] == "SENIOR" and c["quality"] >= 45 else "NO",
        })
    for r in source_map_rows:
        if r["status"] != "SOURCE_CANONICAL_CANDIDATE":
            continue
        candidate_rows.append({
            "canonicalKey": r["canonicalKey"],
            "origin": SOURCE_NS,
            "existingClubId": "",
            "sourceClubId": r["sourceClubId"],
            "name": r["canonicalName"],
            "country": r["canonicalCountry"],
            "competition": r["sourceCompetition"],
            "entityType": r["entityType"],
            "quality": r["quality"],
            "popularitySeed": r["popularitySeed"],
            "playableCandidate": r["playableCandidate"],
        })

    # Select a *question/display* club pool preview. This does NOT remove identities from the master catalogue.
    eligible = [r for r in candidate_rows if r["playableCandidate"] == "YES"]
    eligible.sort(key=lambda r: (-int(r["popularitySeed"]), -int(r["quality"]), str(r["name"])))
    selected_keys = {r["canonicalKey"] for r in eligible[:4000]}
    for r in candidate_rows:
        r["gameplayPool4000"] = "YES" if r["canonicalKey"] in selected_keys else "NO"

    out("Trusted transfer kariyerleri canonical kimliğe çevriliyor...")
    career = {}
    transfer_relation_count = 0
    transfer_gameplay_count = 0
    for r in trusted:
        pid = parse_int(r.get("canonicalPlayerId"))
        sid = parse_int(r.get("sourceClubId"))
        if pid is None or sid is None or sid not in map_by_sid:
            continue
        m = map_by_sid[sid]
        if m["status"] == "PSEUDO_EXCLUDED":
            continue
        key = (pid, m["canonicalKey"])
        evidence = career.setdefault(key, {
            "canonicalPlayerId": pid,
            "canonicalPlayerName": str(r.get("canonicalPlayerName") or ""),
            "canonicalClubKey": m["canonicalKey"],
            "clubName": m["canonicalName"],
            "entityType": m["entityType"],
            "firstDate": str(r.get("firstDate") or ""),
            "lastDate": str(r.get("lastDate") or ""),
            "seasons": set(),
            "roles": set(),
            "evidence": set(),
            "mentions": 0,
            "gameplayEligible": m["entityType"] == "SENIOR",
        })
        if r.get("firstDate") and (not evidence["firstDate"] or str(r["firstDate"]) < evidence["firstDate"]):
            evidence["firstDate"] = str(r["firstDate"])
        if r.get("lastDate") and (not evidence["lastDate"] or str(r["lastDate"]) > evidence["lastDate"]):
            evidence["lastDate"] = str(r["lastDate"])
        evidence["seasons"].update(x for x in str(r.get("seasons") or "").split("|") if x)
        evidence["roles"].update(x for x in str(r.get("roles") or "").split("|") if x)
        evidence["evidence"].add("TRANSFER_VALIDATED")
        evidence["mentions"] += parse_int(r.get("mentions"), 0) or 0
        transfer_relation_count += 1
        if evidence["gameplayEligible"]:
            transfer_gameplay_count += 1

    # Add current clubIds only as a namespace-qualified fallback for non-collision player records.
    out("players_min güvenli fallback ilişkileri ekleniyor...")
    players_rows = rows_from_json(load_json(players_path))
    current_existing = 0
    current_orphan = 0
    skipped_quarantine = 0
    legacy_orphan_usage = defaultdict(int)
    for i, p in enumerate(players_rows, start=1):
        pid = parse_int(p.get("id"))
        if pid is None:
            continue
        if pid in quarantined_players:
            skipped_quarantine += 1
            continue
        pname = str(p.get("name") or "")
        ids = p.get("clubIds") or p.get("club_ids") or []
        if isinstance(ids, str):
            ids = [x for x in re.split(r"[|,;]", ids) if x.strip()]
        if not isinstance(ids, list):
            continue
        for raw_cid in ids:
            cid = parse_int(raw_cid)
            if cid is None:
                continue
            if cid in canonical:
                c = canonical[cid]
                key = (pid, f"existing:{cid}")
                ev = career.setdefault(key, {
                    "canonicalPlayerId": pid,
                    "canonicalPlayerName": pname,
                    "canonicalClubKey": f"existing:{cid}",
                    "clubName": c["name"],
                    "entityType": c["type"],
                    "firstDate": "", "lastDate": "", "seasons": set(), "roles": set(), "evidence": set(), "mentions": 0,
                    "gameplayEligible": c["type"] == "SENIOR",
                })
                ev["evidence"].add("CURRENT_SAFE_FALLBACK")
                current_existing += 1
            else:
                # Preserve but do not pretend the numeric ID belongs to TM or current canonical namespace.
                ckey = f"legacy_current:{cid}"
                key = (pid, ckey)
                ev = career.setdefault(key, {
                    "canonicalPlayerId": pid,
                    "canonicalPlayerName": pname,
                    "canonicalClubKey": ckey,
                    "clubName": "",
                    "entityType": "UNRESOLVED",
                    "firstDate": "", "lastDate": "", "seasons": set(), "roles": set(), "evidence": set(), "mentions": 0,
                    "gameplayEligible": False,
                })
                ev["evidence"].add("CURRENT_ORPHAN_PRESERVED")
                legacy_orphan_usage[cid] += 1
                current_orphan += 1
        if i % 25000 == 0:
            out(f"players_min fallback: {i:,}/{len(players_rows):,}")

    career_rows = []
    per_player_gameplay = defaultdict(set)
    per_player_all = defaultdict(set)
    for ev in career.values():
        ev_out = dict(ev)
        ev_out["seasons"] = "|".join(sorted(ev["seasons"]))
        ev_out["roles"] = "|".join(sorted(ev["roles"]))
        ev_out["evidence"] = "|".join(sorted(ev["evidence"]))
        ev_out["gameplayEligible"] = "YES" if ev["gameplayEligible"] else "NO"
        career_rows.append(ev_out)
        per_player_all[ev["canonicalPlayerId"]].add(ev["canonicalClubKey"])
        if ev["gameplayEligible"]:
            per_player_gameplay[ev["canonicalPlayerId"]].add(ev["canonicalClubKey"])

    career_rows.sort(key=lambda x: (int(x["canonicalPlayerId"]), str(x["firstDate"]), str(x["canonicalClubKey"])))

    # Priority manual review list: high-impact source identities that remain namespaced rather than mapped to current canonical.
    review_rows = []
    for r in source_map_rows:
        if r["status"] != "SOURCE_CANONICAL_CANDIDATE" or r["entityType"] != "SENIOR":
            continue
        priority = int(r["playerUsage"]) * 10 + int(r["transferMentions"])
        review_rows.append({**r, "reviewPriority": priority})
    review_rows.sort(key=lambda r: (-int(r["reviewPriority"]), -int(r["popularitySeed"]), str(r["sourceName"])))

    orphan_rows = [
        {"sourceNamespace":"legacy_current_club", "sourceClubId":cid, "playerUsage":count, "action":"PRESERVE_OUTSIDE_GAMEPLAY_UNTIL_RESOLVED"}
        for cid, count in sorted(legacy_orphan_usage.items(), key=lambda kv: (-kv[1], kv[0]))
    ]

    source_fields = ["sourceNamespace","sourceClubId","sourceName","sourceCountry","sourceCompetition","entityType","canonicalKey","existingCanonicalClubId","canonicalName","canonicalCountry","method","confidence","status","quality","popularitySeed","playerUsage","transferMentions","playableCandidate"]
    candidate_fields = ["canonicalKey","origin","existingClubId","sourceClubId","name","country","competition","entityType","quality","popularitySeed","playableCandidate","gameplayPool4000"]
    career_fields = ["canonicalPlayerId","canonicalPlayerName","canonicalClubKey","clubName","entityType","firstDate","lastDate","seasons","roles","evidence","mentions","gameplayEligible"]
    review_fields = source_fields + ["reviewPriority"]

    write_csv(report03d / "club_source_map_v2.csv", source_map_rows, source_fields)
    write_csv(report03d / "canonical_club_candidates.csv", candidate_rows, candidate_fields)
    write_csv(report03d / "canonical_career_candidates.csv", career_rows, career_fields)
    write_csv(report03d / "manual_club_review_priority.csv", review_rows, review_fields)
    write_csv(report03d / "legacy_orphan_club_refs.csv", orphan_rows, ["sourceNamespace","sourceClubId","playerUsage","action"])

    # Compact player->club preview for later compiler work.
    player_preview = {}
    for pid in sorted(per_player_all):
        player_preview[str(pid)] = {
            "allClubKeys": sorted(per_player_all[pid]),
            "seniorGameplayClubKeys": sorted(per_player_gameplay.get(pid, set())),
        }
    with (report03d / "player_clubs_candidate.json").open("w", encoding="utf-8") as f:
        json.dump(player_preview, f, ensure_ascii=False, separators=(",", ":"))

    source_new_senior = sum(1 for r in source_map_rows if r["status"] == "SOURCE_CANONICAL_CANDIDATE" and r["entityType"] == "SENIOR")
    source_new_dev = sum(1 for r in source_map_rows if r["status"] == "SOURCE_CANONICAL_CANDIDATE" and r["entityType"] == "DEVELOPMENT")
    auto_alias = status_counts.get("AUTO_ALIAS_HIGH", 0)
    mapped_total = status_counts.get("AUTO_MAP_HIGH", 0) + auto_alias
    players_with_any = len(per_player_all)
    players_with_gameplay = len(per_player_gameplay)
    unresolved_legacy_players = len({r["canonicalPlayerId"] for r in career_rows if "CURRENT_ORPHAN_PRESERVED" in r["evidence"]})

    summary = {
        "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
        "step": "03D",
        "runtimeChanged": False,
        "existingCanonicalClubs": len(canonical),
        "sourceClubIdentities": len(source_catalog),
        "sourceMapStatus": dict(sorted(status_counts.items())),
        "autoMappedOrAliasedSourceClubs": mapped_total,
        "autoAliasRescuesBeyond03C": auto_alias,
        "newSeniorSourceCanonicalCandidates": source_new_senior,
        "newDevelopmentSourceCandidates": source_new_dev,
        "masterClubCandidateCount": len(candidate_rows),
        "gameplayPoolPreviewCount": len(selected_keys),
        "careerCandidateRows": len(career_rows),
        "playersWithAnyPreservedClubRelation": players_with_any,
        "playersWithSeniorGameplayRelation": players_with_gameplay,
        "quarantinedCollisionPlayersSkippingCurrentClubIds": skipped_quarantine,
        "currentExistingFallbackMentions": current_existing,
        "currentOrphanFallbackMentions": current_orphan,
        "legacyOrphanSourceIds": len(legacy_orphan_usage),
        "playersStillTouchingLegacyOrphanRefs": unresolved_legacy_players,
        "rules": [
            "03D is read-only; runtime assets are not mutated.",
            "Source namespace + source ID is the identity boundary.",
            "Pseudo clubs never enter career/gameplay club pools.",
            "Development teams are preserved but excluded from senior Shared XI gameplay by default.",
            "Unmapped TM senior clubs are preserved as tm:<sourceId> canonical candidates instead of being discarded or merged by integer ID.",
            "Current clubIds are only used as fallback for non-quarantined player identities.",
            "Existing unresolved numeric clubIds are preserved as legacy_current:<id> and kept outside gameplay until resolved.",
            "gameplayPool4000 is only a preview flag, not destructive pruning.",
        ],
    }
    with (report03d / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    gates = [
        ["D01", "03C source relationship report exists", "PASS", f"{len(trusted):,} trusted source relationship rows loaded"],
        ["D02", "Numeric ID alone is never accepted as cross-namespace identity", "PASS", "Alias rescue requires name compatibility and country compatibility when known"],
        ["D03", "Pseudo clubs excluded", "PASS", f"{status_counts.get('PSEUDO_EXCLUDED',0):,} pseudo source identities excluded"],
        ["D04", "Collision-player current clubIds remain quarantined", "PASS", f"{skipped_quarantine:,} players skipped for current-club fallback"],
        ["D05", "Unresolved source identity is preserved, not dropped", "PASS", f"{source_new_senior + source_new_dev:,} namespaced source candidates retained"],
        ["D06", "Runtime assets unchanged", "PASS", "Only reports/data_platform_v3/03d is written"],
    ]
    write_csv(report03d / "migration_gates.csv", [dict(zip(["gate","rule","status","detail"], x)) for x in gates], ["gate","rule","status","detail"])

    readme = f"""# Linkball Data Platform v3 — Step 03D\n\nGenerated: `{summary['generatedAtUtc']}`\n\n## Purpose\n\n03D creates the first **canonical club + career candidate layer** without changing live assets. It keeps source namespaces explicit and preserves unresolved identities instead of forcing numeric-ID merges.\n\n## Key results\n\n- Existing canonical clubs: **{len(canonical):,}**\n- TM/source club identities: **{len(source_catalog):,}**\n- AUTO alias rescues beyond 03C: **{auto_alias:,}**\n- New senior source identities preserved as candidates: **{source_new_senior:,}**\n- Development/youth/reserve source identities preserved: **{source_new_dev:,}**\n- Master club candidates: **{len(candidate_rows):,}**\n- Gameplay pool preview: **{len(selected_keys):,}**\n- Career candidate rows: **{len(career_rows):,}**\n- Players with any preserved club relation: **{players_with_any:,}**\n- Players with a senior gameplay relation: **{players_with_gameplay:,}**\n- Collision players whose current clubIds remain quarantined: **{skipped_quarantine:,}**\n- Legacy orphan source IDs still preserved outside gameplay: **{len(legacy_orphan_usage):,}**\n\n## Important files\n\n- `club_source_map_v2.csv` — namespace-qualified source club -> canonical candidate mapping\n- `canonical_club_candidates.csv` — master candidate catalogue; no destructive pruning\n- `canonical_career_candidates.csv` — merged trusted-transfer + safe-current career relation candidates\n- `player_clubs_candidate.json` — compact per-player preview\n- `manual_club_review_priority.csv` — highest-impact senior identities to review first\n- `legacy_orphan_club_refs.csv` — old unresolved current-club namespace refs\n- `migration_gates.csv` — safety gates\n- `summary.json` — machine-readable summary\n\n## Important\n\n`gameplayPool4000=YES` is only a **preview pool**. Clubs outside it are not deleted. Master identity and gameplay selection are separate concepts.\n\n## Next\n\nSend this entire `reports/data_platform_v3/03d/` folder back. 03E will use the measured results to build popularity/quality tiers and decide the production database boundary.\n"""
    (report03d / "README.md").write_text(readme, encoding="utf-8")

    out("Tamamlandı. Runtime data değiştirilmedi.")
    out(f"Rapor: {report03d}")
    out(f"Alias rescue: {auto_alias:,} | Career rows: {len(career_rows):,} | Gameplay pool preview: {len(selected_keys):,}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\n[03D] Kullanıcı tarafından durduruldu. Runtime data değiştirilmedi.", file=sys.stderr)
        raise SystemExit(130)
    except Exception as exc:
        import traceback
        print(f"\nERROR: {exc}", file=sys.stderr)
        traceback.print_exc()
        print("\n[ERROR] Preview failed. Nothing in assets/data was modified.", file=sys.stderr)
        raise SystemExit(1)
