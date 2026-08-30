from __future__ import annotations

import csv
import io
import json
import re
import sys
import unicodedata
import zipfile
from collections import Counter, defaultdict
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "data"
REPORT_03B1 = ROOT / "reports" / "data_platform_v3" / "03b1"
OUT = ROOT / "reports" / "data_platform_v3" / "03c"
INPUT = Path(__file__).resolve().parent / "input"
POLICY = Path(__file__).resolve().parent / "config" / "club_identity_policy.json"


def status(msg: str) -> None:
    print(f"[03C] {msg}", flush=True)


def load_json(path: Path, default=None):
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f)


def load_csv_dicts(path: Path):
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def to_int(v):
    try:
        if v is None or v == "":
            return None
        return int(float(v))
    except Exception:
        return None


def ntext(v) -> str:
    if v is None:
        return ""
    s = unicodedata.normalize("NFKD", str(v)).encode("ascii", "ignore").decode("ascii")
    s = s.casefold().replace("’", "'")
    s = re.sub(r"\([^)]*\)", " ", s)
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def name_tokens(v):
    return [x for x in ntext(v).split() if x]


def player_name_relation(a, b) -> str:
    na, nb = ntext(a), ntext(b)
    if not na or not nb:
        return "none"
    if na == nb:
        return "exact"
    ta, tb = name_tokens(a), name_tokens(b)
    if ta and tb and ta[-1] == tb[-1]:
        # Handles "R. Burki" <-> "Roman Burki" conservatively.
        ai = ta[0][0] if ta[0] else ""
        bi = tb[0][0] if tb[0] else ""
        if ai and ai == bi:
            return "initial_surname"
        return "surname"
    return "none"


LEGAL_TOKENS = {
    "fc", "cf", "sc", "ac", "afc", "fk", "sk", "sv", "vfl", "vfb", "tsv", "ssv",
    "club", "football", "futbol", "calcio", "soccer", "sporting", "deportivo", "cd",
}


def club_strict(v) -> str:
    return ntext(v)


def club_relaxed(v) -> str:
    toks = name_tokens(v)
    if not toks:
        return ""
    toks = [t for t in toks if t not in LEGAL_TOKENS and not re.fullmatch(r"18\d\d|19\d\d|20\d\d", t)]
    return " ".join(toks)


def is_placeholder_name(name: str) -> bool:
    return bool(re.fullmatch(r"club\s+\d+", ntext(name)))


def pseudo_type(name: str, policy: dict) -> str:
    nn = ntext(name)
    for ptype, variants in (policy.get("pseudoNames") or {}).items():
        for v in variants:
            nv = ntext(v)
            if nn == nv or (nv and nv in nn):
                return ptype
    return ""


def discover_source() -> tuple[str, Path]:
    candidates = [
        INPUT / "transfermarkt-datasets-csv.zip",
        ROOT / "transfermarkt-datasets-csv.zip",
        ROOT / "dataset" / "transfermarkt-datasets-csv.zip",
    ]
    for c in candidates:
        if c.exists():
            return "zip", c

    # Accept any clearly named transfermarkt zip in the private input folder.
    for c in INPUT.glob("*transfermarkt*.zip"):
        return "zip", c

    # Extracted CSV fallback.
    extracted_candidates = [
        INPUT / "transfermarkt_csv",
        INPUT,
        ROOT / "tools" / "build_dataset" / "input",
    ]
    for d in extracted_candidates:
        if (d / "transfers.csv").exists():
            return "folder", d
    raise FileNotFoundError(
        "Transfermarkt source bulunamadi. Orijinal transfermarkt-datasets-csv.zip dosyasini "
        "tools/data_platform_v3/input/ klasorune kopyala. Kaynak dosya git'e eklenmemeli."
    )


def find_zip_member(z: zipfile.ZipFile, basename: str) -> str | None:
    target = basename.casefold()
    for n in z.namelist():
        if Path(n).name.casefold() == target:
            return n
    return None


def csv_rows_from_source(kind: str, source: Path, filename: str):
    if kind == "folder":
        p = source / filename
        if not p.exists():
            return []
        f = p.open("r", encoding="utf-8-sig", newline="")
        return f, csv.DictReader(f)
    z = zipfile.ZipFile(source, "r")
    member = find_zip_member(z, filename)
    if not member:
        z.close()
        return []
    raw = z.open(member, "r")
    txt = io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")
    # return resources so caller can close all
    return (z, raw, txt), csv.DictReader(txt)


def close_source_handle(handle):
    if not handle:
        return
    if isinstance(handle, tuple):
        for obj in reversed(handle):
            try:
                obj.close()
            except Exception:
                pass
    else:
        try:
            handle.close()
        except Exception:
            pass


def write_csv(name: str, headers: list[str], rows) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / name).open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=headers, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def choose_primary_name(counter: Counter) -> str:
    if not counter:
        return ""
    # frequency first, then non-abbreviated/longer name for deterministic ties
    return sorted(counter.items(), key=lambda kv: (-kv[1], -len(kv[0]), kv[0]))[0][0]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    policy = load_json(POLICY, {}) or {}

    status("03B.1 source map yukleniyor...")
    source_map_rows = load_csv_dicts(REPORT_03B1 / "player_source_map.csv")
    if not source_map_rows:
        raise RuntimeError("reports/data_platform_v3/03b1/player_source_map.csv bulunamadi. Once 03B.1 tamamlanmali.")

    player_map = {}
    for r in source_map_rows:
        if r.get("sourceNamespace") != "players_full" or r.get("status") != "AUTO_MAP_HIGH":
            continue
        sid = to_int(r.get("sourcePlayerId"))
        cid = to_int(r.get("canonicalMinPlayerId"))
        if sid is not None and cid is not None:
            player_map[sid] = cid
    status(f"Guvenli player source map: {len(player_map):,}")

    status("players_min.json yukleniyor...")
    pmin = load_json(DATA / "players_min.json", []) or []
    min_by_id = {to_int(p.get("id")): p for p in pmin if isinstance(p, dict) and to_int(p.get("id")) is not None}
    if not min_by_id:
        raise RuntimeError("assets/data/players_min.json okunamadi.")

    status("clubs_min.json yukleniyor...")
    clubs = load_json(DATA / "clubs_min.json", []) or []
    canonical_clubs = []
    by_cid = {}
    strict_index = defaultdict(list)
    relaxed_index = defaultdict(list)
    for c in clubs:
        if not isinstance(c, dict):
            continue
        cid = to_int(c.get("id"))
        name = str(c.get("name") or "").strip()
        if cid is None or not name:
            continue
        rec = {
            "id": cid,
            "name": name,
            "country": str(c.get("country") or "").strip(),
            "league": str(c.get("league") or "").strip(),
            "placeholder": is_placeholder_name(name),
        }
        canonical_clubs.append(rec)
        by_cid[cid] = rec
        if not rec["placeholder"]:
            strict_index[club_strict(name)].append(rec)
            relaxed_index[club_relaxed(name)].append(rec)

    source_kind, source_path = discover_source()
    status(f"Kaynak bulundu: {source_path}")

    # Optional competition/club metadata enrichments.
    competition_country = {}
    handle_rows = csv_rows_from_source(source_kind, source_path, "competitions.csv")
    if handle_rows:
        handle, rows = handle_rows
        try:
            for r in rows:
                comp = str(r.get("competition_id") or "").strip()
                country = str(r.get("country_name") or "").strip()
                if comp and country and country.casefold() != "nan":
                    competition_country[comp] = country
        finally:
            close_source_handle(handle)

    source_club_meta = {}
    handle_rows = csv_rows_from_source(source_kind, source_path, "clubs.csv")
    if handle_rows:
        handle, rows = handle_rows
        try:
            for r in rows:
                sid = to_int(r.get("club_id"))
                if sid is None:
                    continue
                name = str(r.get("name") or "").strip()
                comp = str(r.get("domestic_competition_id") or "").strip()
                source_club_meta[sid] = {
                    "name": name,
                    "competition": comp,
                    "country": competition_country.get(comp, ""),
                }
        finally:
            close_source_handle(handle)

    status("transfers.csv taraniyor ve oyuncu-kulup iliskileri yeniden kuruluyor...")
    handle_rows = csv_rows_from_source(source_kind, source_path, "transfers.csv")
    if not handle_rows:
        raise RuntimeError("Kaynak icinde transfers.csv bulunamadi.")
    handle, rows = handle_rows

    club_names = defaultdict(Counter)
    club_rows = Counter()
    club_players = defaultdict(set)
    player_club = {}
    quarantine = {}
    trusted_transfer_rows = 0
    mapped_transfer_rows = 0
    name_validated_rows = 0
    total_rows = 0
    map_player_ids_seen = set()
    transfer_player_ids_seen = set()

    def add_club_name(sid, name):
        if sid is None:
            return
        name = str(name or "").strip()
        if name:
            club_names[sid][name] += 1
        club_rows[sid] += 1

    try:
        for i, r in enumerate(rows, 1):
            total_rows += 1
            if i % 50000 == 0:
                status(f"Transfer satiri: {i:,}")
            # Build the source club namespace catalogue from ALL transfer rows,
            # even when the player cannot be mapped. Player usage is counted only
            # after player identity validation below.
            for id_key, name_key in (("from_club_id", "from_club_name"), ("to_club_id", "to_club_name")):
                raw_scid = to_int(r.get(id_key))
                if raw_scid is not None:
                    add_club_name(raw_scid, str(r.get(name_key) or "").strip())

            spid = to_int(r.get("player_id"))
            if spid is None:
                continue
            transfer_player_ids_seen.add(spid)
            canonical_pid = player_map.get(spid)
            if canonical_pid is None:
                key = (spid, str(r.get("player_name") or "").strip(), "PLAYER_NOT_AUTO_MAPPED")
                q = quarantine.setdefault(key, {"count": 0})
                q["count"] += 1
                continue
            mapped_transfer_rows += 1
            map_player_ids_seen.add(spid)
            canonical_player = min_by_id.get(canonical_pid)
            canonical_name = str((canonical_player or {}).get("name") or "").strip()
            source_name = str(r.get("player_name") or "").strip()
            rel = player_name_relation(canonical_name, source_name)
            if rel not in {"exact", "initial_surname"}:
                key = (spid, source_name, f"PLAYER_NAME_MISMATCH:{canonical_name}")
                q = quarantine.setdefault(key, {"count": 0})
                q["count"] += 1
                continue
            name_validated_rows += 1
            trusted_transfer_rows += 1

            date = str(r.get("transfer_date") or "").strip()
            season = str(r.get("transfer_season") or "").strip()
            for role, id_key, name_key in (
                ("from", "from_club_id", "from_club_name"),
                ("to", "to_club_id", "to_club_name"),
            ):
                scid = to_int(r.get(id_key))
                scname = str(r.get(name_key) or "").strip()
                if scid is None:
                    continue
                club_players[scid].add(canonical_pid)
                key = (canonical_pid, scid)
                agg = player_club.setdefault(key, {
                    "canonicalPlayerId": canonical_pid,
                    "canonicalPlayerName": canonical_name,
                    "sourceNamespace": "tm_transfer_club",
                    "sourceClubId": scid,
                    "sourceClubNames": Counter(),
                    "firstDate": "",
                    "lastDate": "",
                    "seasons": set(),
                    "roles": set(),
                    "mentions": 0,
                })
                if scname:
                    agg["sourceClubNames"][scname] += 1
                if date:
                    if not agg["firstDate"] or date < agg["firstDate"]:
                        agg["firstDate"] = date
                    if not agg["lastDate"] or date > agg["lastDate"]:
                        agg["lastDate"] = date
                if season:
                    agg["seasons"].add(season)
                agg["roles"].add(role)
                agg["mentions"] += 1
    finally:
        close_source_handle(handle)

    # Clubs that exist only in clubs.csv should still be catalogued.
    for sid, meta in source_club_meta.items():
        if meta.get("name"):
            club_names[sid][meta["name"]] += 3
        club_rows.setdefault(sid, 0)

    # Mapping proposals.
    proposal_by_source = {}
    numeric_collisions = []
    pseudo_rows = []

    all_source_ids = sorted(set(club_names) | set(source_club_meta))

    # Fuzzy matching is REVIEW-ONLY. The v1 implementation compared every unresolved
    # source club against every canonical club (roughly 17.5k x 3.1k comparisons).
    # Build conservative buckets once so the scan stays bounded and predictable.
    fuzzy_by_country_initial = defaultdict(list)
    fuzzy_by_country = defaultdict(list)
    fuzzy_by_initial = defaultdict(list)
    fuzzy_relaxed_cache = {}
    for c in canonical_clubs:
        if c["placeholder"]:
            continue
        c_rel = club_relaxed(c["name"]) or club_strict(c["name"])
        if not c_rel:
            continue
        fuzzy_relaxed_cache[c["id"]] = c_rel
        c_country = ntext(c.get("country", ""))
        c_initial = c_rel[:1]
        if c_country:
            fuzzy_by_country[c_country].append(c)
            if c_initial:
                fuzzy_by_country_initial[(c_country, c_initial)].append(c)
        if c_initial:
            fuzzy_by_initial[c_initial].append(c)

    def bounded_fuzzy_candidates(primary_name: str, source_country: str):
        p_rel = club_relaxed(primary_name) or club_strict(primary_name)
        if not p_rel:
            return p_rel, []
        initial = p_rel[:1]
        country_key = ntext(source_country)
        bucket = []
        if country_key and initial:
            bucket = fuzzy_by_country_initial.get((country_key, initial), [])
        if not bucket and country_key:
            bucket = fuzzy_by_country.get(country_key, [])
        if not bucket and initial:
            bucket = fuzzy_by_initial.get(initial, [])
        if not bucket:
            return p_rel, []

        # Similar names rarely differ wildly in normalized length. This cuts the
        # candidate set further without ever creating an automatic mapping.
        p_len = len(p_rel)
        max_delta = max(5, int(round(p_len * 0.35)))
        filtered = [
            c for c in bucket
            if abs(len(fuzzy_relaxed_cache.get(c["id"], "")) - p_len) <= max_delta
        ]
        if not filtered:
            filtered = list(bucket)

        # Guardrail for countries/initials with many clubs. Prefer same first token,
        # then closest normalized length. Fuzzy is suggestion-only, so bounded review
        # candidates are safer than an unbounded O(n^2) scan.
        if len(filtered) > 240:
            first_token = p_rel.split()[0] if p_rel.split() else ""
            same_token = [
                c for c in filtered
                if (fuzzy_relaxed_cache.get(c["id"], "").split()[:1] or [""])[0] == first_token
            ]
            if same_token:
                filtered = same_token
            if len(filtered) > 240:
                filtered = sorted(
                    filtered,
                    key=lambda c: (
                        abs(len(fuzzy_relaxed_cache.get(c["id"], "")) - p_len),
                        c["id"],
                    ),
                )[:240]
        return p_rel, filtered

    match_started = perf_counter()
    fuzzy_pair_checks = 0
    status(f"Kaynak kulup katalogu eslestiriliyor: {len(all_source_ids):,} ID")
    for source_index, sid in enumerate(all_source_ids, 1):
        if source_index == 1 or source_index % 500 == 0 or source_index == len(all_source_ids):
            elapsed = perf_counter() - match_started
            rate = source_index / elapsed if elapsed > 0 else 0.0
            remaining = (len(all_source_ids) - source_index) / rate if rate > 0 else 0.0
            status(
                f"Kulup eslestirme: {source_index:,}/{len(all_source_ids):,} "
                f"({source_index / max(len(all_source_ids), 1) * 100:.1f}%) | "
                f"~{remaining:.0f} sn kaldi"
            )
        names_counter = club_names.get(sid, Counter())
        primary = choose_primary_name(names_counter) or str(source_club_meta.get(sid, {}).get("name") or "").strip()
        aliases = sorted([n for n in names_counter if n and n != primary])[:12]
        src_country = str(source_club_meta.get(sid, {}).get("country") or "").strip()
        ptype = pseudo_type(primary, policy)
        if not ptype:
            for alt in aliases:
                ptype = pseudo_type(alt, policy)
                if ptype:
                    break

        row = {
            "sourceNamespace": "tm_transfer_club",
            "sourceClubId": sid,
            "sourceName": primary,
            "sourceCountry": src_country,
            "canonicalClubId": "",
            "canonicalName": "",
            "method": "",
            "confidence": 0,
            "status": "UNRESOLVED",
            "playerUsage": len(club_players.get(sid, set())),
            "transferMentions": int(club_rows.get(sid, 0)),
        }

        if ptype:
            row.update({"method": f"pseudo:{ptype}", "confidence": 100, "status": "PSEUDO_EXCLUDED"})
            pseudo_rows.append({
                "sourceClubId": sid,
                "sourceName": primary,
                "pseudoType": ptype,
                "playerUsage": row["playerUsage"],
                "transferMentions": row["transferMentions"],
            })
            proposal_by_source[sid] = row
            # Important numeric collision report if current canonical uses same number.
            if sid in by_cid:
                numeric_collisions.append({
                    "sourceClubId": sid,
                    "sourceName": primary,
                    "canonicalSameNumericIdName": by_cid[sid]["name"],
                    "collisionType": "PSEUDO_VS_CANONICAL_NUMERIC_ID",
                    "action": "NEVER_MAP_BY_NUMERIC_ID",
                })
            continue

        strict = club_strict(primary)
        relaxed = club_relaxed(primary)
        same_id = by_cid.get(sid)
        if same_id and not same_id["placeholder"]:
            same_strict = club_strict(same_id["name"])
            same_relaxed = club_relaxed(same_id["name"])
            if strict and (strict == same_strict or (relaxed and relaxed == same_relaxed)):
                row.update({
                    "canonicalClubId": same_id["id"],
                    "canonicalName": same_id["name"],
                    "method": "same_numeric_id_plus_name",
                    "confidence": 99,
                    "status": "AUTO_MAP_HIGH",
                })
                proposal_by_source[sid] = row
                continue
            numeric_collisions.append({
                "sourceClubId": sid,
                "sourceName": primary,
                "canonicalSameNumericIdName": same_id["name"],
                "collisionType": "NAME_MISMATCH_SAME_NUMERIC_ID",
                "action": "NEVER_MAP_BY_NUMERIC_ID",
            })

        exact_candidates = strict_index.get(strict, []) if strict else []
        if len(exact_candidates) == 1:
            c = exact_candidates[0]
            row.update({
                "canonicalClubId": c["id"],
                "canonicalName": c["name"],
                "method": "unique_exact_name",
                "confidence": 98,
                "status": "AUTO_MAP_HIGH",
            })
            proposal_by_source[sid] = row
            continue

        relaxed_candidates = relaxed_index.get(relaxed, []) if relaxed else []
        if len(relaxed_candidates) == 1:
            c = relaxed_candidates[0]
            country_ok = bool(src_country and c["country"] and ntext(src_country) == ntext(c["country"]))
            row.update({
                "canonicalClubId": c["id"],
                "canonicalName": c["name"],
                "method": "unique_relaxed_name_country" if country_ok else "unique_relaxed_name",
                "confidence": 94 if country_ok else 86,
                "status": "AUTO_MAP_HIGH" if country_ok else "REVIEW_CANDIDATE",
            })
            proposal_by_source[sid] = row
            continue

        # Conservative fuzzy suggestion: REVIEW ONLY, never automatic. To keep the
        # audit fast, only spend fuzzy work on clubs actually used by trusted players.
        # Unused source-club rows still receive exact/relaxed matching above.
        if primary and row["playerUsage"] > 0:
            p_rel, candidates = bounded_fuzzy_candidates(primary, src_country)
            scored = []
            threshold = float(policy.get("fuzzyReviewThreshold", 0.90))
            for c in candidates:
                c_rel = fuzzy_relaxed_cache.get(c["id"], "")
                if not p_rel or not c_rel:
                    continue
                fuzzy_pair_checks += 1
                matcher = SequenceMatcher(None, p_rel, c_rel)
                # quick_ratio is a cheap upper bound; skip hopeless pairs before ratio().
                if matcher.quick_ratio() < threshold:
                    continue
                ratio = matcher.ratio()
                if ratio >= threshold:
                    scored.append((ratio, c))
            scored.sort(key=lambda x: (-x[0], x[1]["id"]))
            if scored:
                best = scored[0]
                second = scored[1][0] if len(scored) > 1 else 0
                if best[0] - second >= float(policy.get("fuzzyMinimumMargin", 0.05)):
                    c = best[1]
                    row.update({
                        "canonicalClubId": c["id"],
                        "canonicalName": c["name"],
                        "method": "fuzzy_review_only_bounded",
                        "confidence": round(best[0] * 100, 1),
                        "status": "REVIEW_CANDIDATE",
                    })
        proposal_by_source[sid] = row

    status(
        f"Kulup katalogu tamamlandi: {len(all_source_ids):,} ID | "
        f"bounded fuzzy karsilastirma: {fuzzy_pair_checks:,}"
    )

    # Trusted player-club source refs, annotated with current mapping proposal.
    relationship_rows = []
    for (_, scid), agg in sorted(player_club.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        ptype = pseudo_type(choose_primary_name(agg["sourceClubNames"]), policy)
        prop = proposal_by_source.get(scid, {})
        relationship_rows.append({
            "canonicalPlayerId": agg["canonicalPlayerId"],
            "canonicalPlayerName": agg["canonicalPlayerName"],
            "sourceNamespace": agg["sourceNamespace"],
            "sourceClubId": scid,
            "sourceClubName": choose_primary_name(agg["sourceClubNames"]) or prop.get("sourceName", ""),
            "firstDate": agg["firstDate"],
            "lastDate": agg["lastDate"],
            "seasons": "|".join(sorted(agg["seasons"])),
            "roles": "|".join(sorted(agg["roles"])),
            "mentions": agg["mentions"],
            "clubMapStatus": prop.get("status", "UNRESOLVED"),
            "canonicalClubId": prop.get("canonicalClubId", ""),
            "canonicalClubName": prop.get("canonicalName", ""),
            "pseudoType": ptype,
        })

    # Existing runtime collision players' clubIds are not trusted until rebuilt.
    collision_rows = load_csv_dicts(REPORT_03B1 / "player_id_collisions.csv")
    collision_watch = []
    for r in collision_rows:
        pid = to_int(r.get("numericId"))
        p = min_by_id.get(pid) if pid is not None else None
        if not p:
            continue
        club_ids = p.get("clubIds") if isinstance(p.get("clubIds"), list) else []
        collision_watch.append({
            "canonicalPlayerId": pid,
            "canonicalPlayerName": p.get("name", ""),
            "currentClubIdCount": len(club_ids),
            "currentClubIds": "|".join(str(x) for x in club_ids[:80]),
            "action": "DO_NOT_TRUST_CURRENT_CLUBIDS_UNTIL_RELATION_REBUILD",
        })

    quarantined_rows = []
    for (sid, source_name, reason), meta in sorted(quarantine.items(), key=lambda kv: (-kv[1]["count"], kv[0][0])):
        quarantined_rows.append({
            "sourcePlayerId": sid,
            "sourcePlayerName": source_name,
            "reason": reason,
            "transferRows": meta["count"],
        })

    catalog_rows = []
    for sid in all_source_ids:
        primary = choose_primary_name(club_names.get(sid, Counter())) or str(source_club_meta.get(sid, {}).get("name") or "").strip()
        alt = sorted([n for n in club_names.get(sid, Counter()) if n and n != primary])[:12]
        meta = source_club_meta.get(sid, {})
        ptype = pseudo_type(primary, policy)
        catalog_rows.append({
            "sourceNamespace": "tm_transfer_club",
            "sourceClubId": sid,
            "primaryName": primary,
            "altNames": "|".join(alt),
            "country": meta.get("country", ""),
            "competition": meta.get("competition", ""),
            "playerUsage": len(club_players.get(sid, set())),
            "transferMentions": int(club_rows.get(sid, 0)),
            "pseudoType": ptype,
        })

    proposals = [proposal_by_source[sid] for sid in all_source_ids]
    status_counts = Counter(r["status"] for r in proposals)

    # Mapping/player validation metrics.
    map_coverage = len(map_player_ids_seen)
    mapped_name_validation_pct = (name_validated_rows / mapped_transfer_rows * 100.0) if mapped_transfer_rows else 0.0
    trusted_player_count = len({r["canonicalPlayerId"] for r in relationship_rows if not r["pseudoType"]})
    trusted_nonpseudo_relationships = sum(1 for r in relationship_rows if not r["pseudoType"])
    mapped_relationships = sum(1 for r in relationship_rows if r["clubMapStatus"] == "AUTO_MAP_HIGH" and not r["pseudoType"])

    gates = [
        {
            "gate": "C01",
            "rule": "03B.1 AUTO_MAP_HIGH player source map is required",
            "status": "PASS" if player_map else "BLOCK",
            "detail": f"{len(player_map):,} safe player source mappings loaded",
        },
        {
            "gate": "C02",
            "rule": "Transfer player names must validate against canonical player identity",
            "status": "PASS" if mapped_name_validation_pct >= float(policy.get("minimumPlayerNameValidationPct", 90.0)) else "BLOCK",
            "detail": f"{mapped_name_validation_pct:.2f}% of mapped transfer rows passed name validation",
        },
        {
            "gate": "C03",
            "rule": "Pseudo clubs are excluded from playable club mappings",
            "status": "PASS",
            "detail": f"{status_counts.get('PSEUDO_EXCLUDED', 0):,} pseudo source club IDs isolated",
        },
        {
            "gate": "C04",
            "rule": "Same numeric club ID never maps without name compatibility",
            "status": "PASS",
            "detail": f"{len(numeric_collisions):,} numeric club namespace collisions quarantined",
        },
        {
            "gate": "C05",
            "rule": "Current collision-player clubIds remain quarantined",
            "status": "PASS",
            "detail": f"{len(collision_watch):,} canonical players flagged for relation rebuild",
        },
        {
            "gate": "C06",
            "rule": "03C is read-only and does not mutate runtime assets",
            "status": "PASS",
            "detail": "Only reports/data_platform_v3/03c is written",
        },
    ]

    status("Raporlar yaziliyor...")
    write_csv("club_source_catalog.csv", list(catalog_rows[0].keys()) if catalog_rows else ["sourceClubId"], catalog_rows)
    write_csv("club_mapping_proposals.csv", list(proposals[0].keys()) if proposals else ["sourceClubId"], proposals)
    write_csv("trusted_player_club_source_refs.csv", list(relationship_rows[0].keys()) if relationship_rows else ["canonicalPlayerId"], relationship_rows)
    write_csv("quarantined_transfer_players.csv", list(quarantined_rows[0].keys()) if quarantined_rows else ["sourcePlayerId"], quarantined_rows)
    write_csv("pseudo_clubs.csv", list(pseudo_rows[0].keys()) if pseudo_rows else ["sourceClubId"], pseudo_rows)
    write_csv("club_numeric_id_collisions.csv", list(numeric_collisions[0].keys()) if numeric_collisions else ["sourceClubId"], numeric_collisions)
    write_csv("current_clubids_quarantine.csv", list(collision_watch[0].keys()) if collision_watch else ["canonicalPlayerId"], collision_watch)
    write_csv("migration_gates.csv", ["gate", "rule", "status", "detail"], gates)

    summary = {
        "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
        "step": "03C",
        "runtimeChanged": False,
        "sourcePath": str(source_path),
        "safePlayerSourceMappings": len(player_map),
        "transferRows": total_rows,
        "mappedTransferRows": mapped_transfer_rows,
        "nameValidatedTransferRows": name_validated_rows,
        "playerNameValidationPct": round(mapped_name_validation_pct, 2),
        "sourceClubIds": len(all_source_ids),
        "clubMappingStatus": dict(status_counts),
        "numericClubIdCollisions": len(numeric_collisions),
        "pseudoClubIds": len(pseudo_rows),
        "trustedCanonicalPlayersWithTransferRelations": trusted_player_count,
        "trustedPlayerClubRelationships": trusted_nonpseudo_relationships,
        "autoMappedPlayerClubRelationships": mapped_relationships,
        "quarantinedCurrentCollisionPlayers": len(collision_watch),
        "decision": (
            "Do not trust existing clubIds for player-ID collision records. New career/club relations are reconstructed "
            "from namespace-qualified transfer source rows only after player-name validation. Club numeric IDs are never identity proof."
        ),
    }
    (OUT / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    md = f"""# Linkball Data Platform v3 — Step 03C\n\nGenerated: `{summary['generatedAtUtc']}`\n\n## Purpose\n\n03C rebuilds a **trusted player -> source club relationship layer** instead of trusting the current mixed `clubIds` blindly. It then creates conservative club identity proposals. This step is read-only.\n\n## Key results\n\n- Safe player source mappings loaded: **{len(player_map):,}**\n- Transfer rows scanned: **{total_rows:,}**\n- Transfer rows mapped to a canonical player: **{mapped_transfer_rows:,}**\n- Mapped transfer rows passing player-name validation: **{name_validated_rows:,} ({mapped_name_validation_pct:.2f}%)**\n- Source club IDs catalogued: **{len(all_source_ids):,}**\n- Club AUTO_MAP_HIGH: **{status_counts.get('AUTO_MAP_HIGH', 0):,}**\n- Club REVIEW_CANDIDATE: **{status_counts.get('REVIEW_CANDIDATE', 0):,}**\n- Club UNRESOLVED: **{status_counts.get('UNRESOLVED', 0):,}**\n- Pseudo club IDs excluded: **{status_counts.get('PSEUDO_EXCLUDED', 0):,}**\n- Numeric club namespace collisions quarantined: **{len(numeric_collisions):,}**\n- Current collision-player `clubIds` quarantined: **{len(collision_watch):,}**\n\n## Frozen rules\n\n1. `(sourceNamespace, sourceId)` is mandatory.\n2. A matching integer club ID is **not** identity proof.\n3. `Retired`, `Without Club`, `Career break`, `Unknown` and similar values are state markers, not playable clubs.\n4. Current `clubIds` belonging to player-ID collision records are not accepted as canonical career evidence.\n5. Only `AUTO_MAP_HIGH` club mappings can be consumed automatically by the next compiler step.\n6. Review/unresolved rows stay out of gameplay until resolved.\n\n## Important files\n\n- `trusted_player_club_source_refs.csv` — rebuilt trusted relationships\n- `club_source_catalog.csv` — source club namespace catalogue\n- `club_mapping_proposals.csv` — conservative mapping to current canonical clubs\n- `club_numeric_id_collisions.csv` — proof that numeric club IDs cannot be merged blindly\n- `current_clubids_quarantine.csv` — current player records whose clubIds must be rebuilt\n- `quarantined_transfer_players.csv` — source transfer players that could not be safely attached\n- `migration_gates.csv` — safety gates\n\n## Next\n\nSend this entire `reports/data_platform_v3/03c/` folder back. 03D will use these outputs to create the first clean canonical club/career candidate dataset without changing the live app yet.\n"""
    (OUT / "README.md").write_text(md, encoding="utf-8")

    status("Tamamlandi.")
    status(f"Rapor: {OUT}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        raise
