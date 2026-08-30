#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import json
import re
import unicodedata
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
G12_DIR = ROOT / "reports" / "data_platform_v3" / "03g1_2"
D_DIR = ROOT / "reports" / "data_platform_v3" / "03d"
D2_DIR = ROOT / "reports" / "data_platform_v3" / "03d2"
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
INPUT_DIR = ROOT / "tools" / "data_platform_v3" / "input"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03g2"

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

def norm(v: Any) -> str:
    text = unicodedata.normalize("NFKD", s(v))
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", " ", text.casefold()).strip()
    return " ".join(text.split())

def date_key(v: Any) -> str:
    t = s(v)
    return t if re.match(r"^\d{4}-\d{2}-\d{2}$", t) else ""

def year_of(v: Any) -> int:
    t = s(v)
    return int(t[:4]) if re.match(r"^\d{4}", t) else 0

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

def find_source_zip() -> Path:
    preferred = INPUT_DIR / "transfermarkt-datasets-csv.zip"
    if preferred.exists():
        return preferred
    for p in sorted(INPUT_DIR.glob("*.zip")):
        try:
            with zipfile.ZipFile(p) as z:
                names = z.namelist()
                if any(n.endswith("transfers.csv") for n in names) and any(n.endswith("appearances.csv") for n in names):
                    return p
        except Exception:
            pass
    raise FileNotFoundError("tools/data_platform_v3/input/transfermarkt-datasets-csv.zip gerekli.")

def member(z: zipfile.ZipFile, ending: str) -> str:
    hits = [n for n in z.namelist() if n.endswith(ending)]
    if not hits:
        raise FileNotFoundError(f"ZIP icinde {ending} yok")
    return hits[0]

def main() -> None:
    print("=" * 80)
    print("LINKBALL DATA PLATFORM V3 - STEP 03G.2")
    print("CANONICAL TRANSFERS + CAREER TIMELINE (READ-ONLY)")
    print("=" * 80)

    identity_rows = read_csv(G12_DIR / "player_source_identity_map_v3.csv")
    club_map_rows = read_csv(D_DIR / "club_source_map_v2.csv")
    club_rows = read_csv(D2_DIR / "canonical_clubs_gameplay_guarded_v2.csv")
    selection_rows = read_csv(E2_DIR / "player_selection_scores_v3.csv")

    source_identity = {}
    for r in identity_rows:
        sid = as_int(r.get("sourcePlayerId"), -1)
        target = as_int(r.get("primaryCanonicalPlayerId"), -1)
        if sid < 0 or target < 0:
            continue
        source_identity[sid] = {
            "primaryId": target,
            "sourceName": s(r.get("sourceName")),
            "primaryName": s(r.get("primaryName")),
            "status": s(r.get("status")),
            "confidence": as_int(r.get("confidence")),
        }

    club_source = {}
    pseudo_ids = set()
    for r in club_map_rows:
        sid = as_int(r.get("sourceClubId"), -1)
        if sid < 0:
            continue
        status = s(r.get("status"))
        if status == "PSEUDO_EXCLUDED":
            pseudo_ids.add(sid)
        club_source[sid] = {
            "key": s(r.get("canonicalKey")),
            "sourceName": s(r.get("sourceName")),
            "status": status,
        }

    club_meta = {s(r.get("canonicalKey")): r for r in club_rows if s(r.get("canonicalKey"))}
    player_meta = {as_int(r.get("id"), -1): r for r in selection_rows if as_int(r.get("id"), -1) >= 0}

    print(f"[03G.2] Source player identity: {len(source_identity):,}")
    print(f"[03G.2] Source club identity: {len(club_source):,}")
    print(f"[03G.2] Pseudo club: {len(pseudo_ids):,}")

    src = find_source_zip()
    print(f"[03G.2] Kaynak ZIP: {src}")

    transfer_events = []
    transfer_quarantine = []
    event_seen = set()
    events_by_player = defaultdict(list)
    appearance_bounds = {}
    appearance_name_mismatch = 0
    raw_transfer_rows = 0

    with zipfile.ZipFile(src) as z:
        tn = member(z, "transfers.csv")
        print(f"[03G.2] transfers.csv: {tn}")
        with z.open(tn) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for i, r in enumerate(reader, 1):
                raw_transfer_rows += 1
                if i % 50000 == 0:
                    print(f"[03G.2] Transfer satiri: {i:,}")

                sid = as_int(r.get("player_id"), -1)
                ident = source_identity.get(sid)
                if not ident:
                    continue

                row_name = s(r.get("player_name"))
                if norm(row_name) != norm(ident["sourceName"]):
                    transfer_quarantine.append({
                        "sourcePlayerId": sid,
                        "sourceNameExpected": ident["sourceName"],
                        "rowPlayerName": row_name,
                        "transferDate": s(r.get("transfer_date")),
                        "reason": "PLAYER_NAME_MISMATCH",
                    })
                    continue

                dt = date_key(r.get("transfer_date"))
                if not dt:
                    transfer_quarantine.append({
                        "sourcePlayerId": sid,
                        "sourceNameExpected": ident["sourceName"],
                        "rowPlayerName": row_name,
                        "transferDate": s(r.get("transfer_date")),
                        "reason": "INVALID_TRANSFER_DATE",
                    })
                    continue

                from_sid = as_int(r.get("from_club_id"), -1)
                to_sid = as_int(r.get("to_club_id"), -1)
                dedup = (sid, dt, from_sid, to_sid)
                if dedup in event_seen:
                    continue
                event_seen.add(dedup)

                fi = club_source.get(from_sid)
                ti = club_source.get(to_sid)
                from_pseudo = from_sid in pseudo_ids
                to_pseudo = to_sid in pseudo_ids
                from_key = "" if from_pseudo or not fi else fi["key"]
                to_key = "" if to_pseudo or not ti else ti["key"]

                if from_key and to_key:
                    event_type, trust = "CLUB_TO_CLUB", "HIGH"
                elif from_key and to_pseudo:
                    pseudo_name = s(ti.get("sourceName") if ti else r.get("to_club_name")).casefold()
                    event_type = "RETIREMENT" if "retir" in pseudo_name else "LEAVE_TO_PSEUDO"
                    trust = "HIGH_BOUNDARY"
                elif from_pseudo and to_key:
                    event_type, trust = "JOIN_FROM_PSEUDO", "HIGH_BOUNDARY"
                elif from_key or to_key:
                    event_type, trust = "PARTIAL_REAL_CLUB_EVENT", "MEDIUM"
                else:
                    continue

                pid = ident["primaryId"]
                ev = {
                    "eventId": f"tm:{sid}:{dt}:{from_sid}:{to_sid}",
                    "canonicalPlayerId": pid,
                    "canonicalPlayerName": s(player_meta.get(pid, {}).get("name") or ident["primaryName"]),
                    "sourcePlayerId": sid,
                    "sourcePlayerName": ident["sourceName"],
                    "identityStatus": ident["status"],
                    "transferDate": dt,
                    "transferYear": year_of(dt),
                    "transferSeason": s(r.get("transfer_season")),
                    "fromSourceClubId": from_sid,
                    "fromSourceClubName": s(r.get("from_club_name")),
                    "fromCanonicalClubKey": from_key,
                    "fromCanonicalClubName": s(club_meta.get(from_key, {}).get("name")) if from_key else "",
                    "toSourceClubId": to_sid,
                    "toSourceClubName": s(r.get("to_club_name")),
                    "toCanonicalClubKey": to_key,
                    "toCanonicalClubName": s(club_meta.get(to_key, {}).get("name")) if to_key else "",
                    "eventType": event_type,
                    "eventTrust": trust,
                }
                transfer_events.append(ev)
                events_by_player[pid].append(ev)

        an = member(z, "appearances.csv")
        print(f"[03G.2] appearances.csv: {an}")
        with z.open(an) as fb:
            reader = csv.DictReader(io.TextIOWrapper(fb, encoding="utf-8-sig"))
            for i, r in enumerate(reader, 1):
                if i % 250000 == 0:
                    print(f"[03G.2] Appearance satiri: {i:,}")

                sid = as_int(r.get("player_id"), -1)
                ident = source_identity.get(sid)
                if not ident:
                    continue
                if norm(r.get("player_name")) != norm(ident["sourceName"]):
                    appearance_name_mismatch += 1
                    continue

                source_club_id = as_int(r.get("player_club_id"), -1)
                ci = club_source.get(source_club_id)
                if not ci or source_club_id in pseudo_ids or not ci["key"]:
                    continue
                dt = date_key(r.get("date"))
                if not dt:
                    continue

                pid = ident["primaryId"]
                key = ci["key"]
                k = (pid, key)
                b = appearance_bounds.get(k)
                if b is None:
                    appearance_bounds[k] = {
                        "firstDate": dt, "lastDate": dt, "appearances": 1,
                        "minutes": as_int(r.get("minutes_played"))
                    }
                else:
                    b["firstDate"] = min(b["firstDate"], dt)
                    b["lastDate"] = max(b["lastDate"], dt)
                    b["appearances"] += 1
                    b["minutes"] += as_int(r.get("minutes_played"))

    print(f"[03G.2] Accepted transfer event: {len(transfer_events):,}")
    print(f"[03G.2] Appearance club bounds: {len(appearance_bounds):,}")

    spells = []
    anomalies = []
    all_players = set(events_by_player)
    all_players.update(pid for pid, _ in appearance_bounds)

    # Appearance clubs grouped once to avoid scanning the full bounds table for every player.
    app_clubs_by_player = defaultdict(dict)
    for (pid, key), b in appearance_bounds.items():
        app_clubs_by_player[pid][key] = b

    for pi, pid in enumerate(sorted(all_players), 1):
        if pi % 10000 == 0:
            print(f"[03G.2] Timeline player: {pi:,}/{len(all_players):,}")

        evs = sorted(events_by_player.get(pid, []), key=lambda e: (e["transferDate"], e["eventId"]))
        player_spells = []
        open_by_club = {}
        represented = set()

        for ev in evs:
            dt = ev["transferDate"]
            fk = ev["fromCanonicalClubKey"]
            tk = ev["toCanonicalClubKey"]

            if fk:
                represented.add(fk)
                idx = open_by_club.get(fk)
                if idx is None:
                    b = appearance_bounds.get((pid, fk), {})
                    first = s(b.get("firstDate"))
                    start = first if first and first <= dt else ""
                    player_spells.append({
                        "canonicalPlayerId": pid,
                        "canonicalPlayerName": s(player_meta.get(pid, {}).get("name")),
                        "canonicalClubKey": fk,
                        "canonicalClubName": s(club_meta.get(fk, {}).get("name")),
                        "startDate": start,
                        "endDate": dt,
                        "startEvidence": "APPEARANCE_FIRST" if start else "UNKNOWN_BEFORE_TRANSFER",
                        "endEvidence": "TRANSFER_OUT",
                        "transferInEventId": "",
                        "transferOutEventId": ev["eventId"],
                    })
                else:
                    sp = player_spells[idx]
                    sp["endDate"] = dt
                    sp["endEvidence"] = "TRANSFER_OUT"
                    sp["transferOutEventId"] = ev["eventId"]
                    open_by_club.pop(fk, None)

            if tk:
                represented.add(tk)
                old_idx = open_by_club.get(tk)
                if old_idx is not None:
                    old = player_spells[old_idx]
                    if not old["endDate"]:
                        old["endDate"] = dt
                        old["endEvidence"] = "TRANSFER_REENTRY_BOUNDARY"
                    open_by_club.pop(tk, None)

                player_spells.append({
                    "canonicalPlayerId": pid,
                    "canonicalPlayerName": s(player_meta.get(pid, {}).get("name")),
                    "canonicalClubKey": tk,
                    "canonicalClubName": s(club_meta.get(tk, {}).get("name")),
                    "startDate": dt,
                    "endDate": "",
                    "startEvidence": "TRANSFER_IN",
                    "endEvidence": "",
                    "transferInEventId": ev["eventId"],
                    "transferOutEventId": "",
                })
                open_by_club[tk] = len(player_spells) - 1

        for key, idx in list(open_by_club.items()):
            sp = player_spells[idx]
            b = appearance_bounds.get((pid, key), {})
            last = s(b.get("lastDate"))
            if last and (not sp["startDate"] or last >= sp["startDate"]):
                sp["endDate"] = last
                sp["endEvidence"] = "APPEARANCE_LAST_SOURCE_WINDOW"

        for key, b in app_clubs_by_player.get(pid, {}).items():
            if key in represented:
                continue
            player_spells.append({
                "canonicalPlayerId": pid,
                "canonicalPlayerName": s(player_meta.get(pid, {}).get("name")),
                "canonicalClubKey": key,
                "canonicalClubName": s(club_meta.get(key, {}).get("name")),
                "startDate": b["firstDate"],
                "endDate": b["lastDate"],
                "startEvidence": "APPEARANCE_FIRST",
                "endEvidence": "APPEARANCE_LAST_SOURCE_WINDOW",
                "transferInEventId": "",
                "transferOutEventId": "",
            })

        player_spells.sort(key=lambda x: (x["startDate"] or "0000-00-00", x["endDate"] or "9999-99-99", x["canonicalClubKey"]))

        for seq, sp in enumerate(player_spells, 1):
            key = sp["canonicalClubKey"]
            cm = club_meta.get(key, {})
            b = appearance_bounds.get((pid, key), {})
            start, end = sp["startDate"], sp["endDate"]
            chronology_ok = not (start and end and start > end)
            if not chronology_ok:
                anomalies.append({
                    "canonicalPlayerId": pid,
                    "canonicalPlayerName": sp["canonicalPlayerName"],
                    "canonicalClubKey": key,
                    "startDate": start,
                    "endDate": end,
                    "reason": "START_AFTER_END",
                })

            transfer_boundaries = int(sp["startEvidence"] == "TRANSFER_IN") + int(sp["endEvidence"] == "TRANSFER_OUT")
            apps = as_int(b.get("appearances"))
            if chronology_ok and transfer_boundaries == 2:
                confidence = "HIGH"
            elif chronology_ok and transfer_boundaries >= 1 and apps >= 3:
                confidence = "HIGH"
            elif chronology_ok and (start or end):
                confidence = "MEDIUM"
            else:
                confidence = "LOW"

            entity = s(cm.get("entityType")).upper() or "UNRESOLVED"
            gameplay = yes(cm.get("gameplayEligible03d1")) and entity == "SENIOR"

            sp.update({
                "sequence": seq,
                "entityType": entity,
                "gameplaySenior": "YES" if gameplay else "NO",
                "spellConfidence": confidence,
                "appearanceCountSourceWindow": apps,
                "appearanceFirstDate": s(b.get("firstDate")),
                "appearanceLastDate": s(b.get("lastDate")),
            })
            spells.append(sp)

    by_player_spells = defaultdict(list)
    for sp in spells:
        by_player_spells[as_int(sp.get("canonicalPlayerId"), -1)].append(sp)

    puzzle_candidates = []
    timeline_json = {}
    for pid, spl in by_player_spells.items():
        senior = [x for x in spl if x["gameplaySenior"] == "YES" and x["spellConfidence"] in {"HIGH", "MEDIUM"}]
        clubs = {x["canonicalClubKey"] for x in senior}
        dated = [x for x in senior if x["startDate"] or x["endDate"]]
        high = [x for x in senior if x["spellConfidence"] == "HIGH"]
        pm = player_meta.get(pid, {})
        if len(clubs) >= 3 and len(dated) >= 3:
            quality = "A_TRUSTED" if len(high) >= 3 else ("B_PLAYABLE" if len(dated) >= 4 else "C_PREVIEW")
            puzzle_candidates.append({
                "playerId": pid,
                "name": s(pm.get("name")),
                "selectionRankV3": as_int(pm.get("selectionRankV3"), 999999999),
                "casualV3": s(pm.get("casualV3")),
                "normalV3": s(pm.get("normalV3")),
                "hardV3": s(pm.get("hardV3")),
                "uniqueSeniorClubCount": len(clubs),
                "datedSeniorSpellCount": len(dated),
                "highConfidenceSpellCount": len(high),
                "timelineQuality": quality,
            })
            timeline_json[str(pid)] = [
                {
                    "clubKey": x["canonicalClubKey"], "clubName": x["canonicalClubName"],
                    "from": x["startDate"], "to": x["endDate"], "confidence": x["spellConfidence"]
                } for x in senior
            ]

    puzzle_candidates.sort(key=lambda r: (r["selectionRankV3"], -r["uniqueSeniorClubCount"], r["name"].casefold()))

    transfer_detective = []
    for ev in transfer_events:
        fk, tk = ev["fromCanonicalClubKey"], ev["toCanonicalClubKey"]
        if not fk or not tk:
            continue
        fm, tm = club_meta.get(fk, {}), club_meta.get(tk, {})
        if not (yes(fm.get("gameplayEligible03d1")) and s(fm.get("entityType")).upper() == "SENIOR"):
            continue
        if not (yes(tm.get("gameplayEligible03d1")) and s(tm.get("entityType")).upper() == "SENIOR"):
            continue
        pid = as_int(ev.get("canonicalPlayerId"), -1)
        pm = player_meta.get(pid, {})
        if not (yes(pm.get("normalV3")) or yes(pm.get("hardV3"))):
            continue
        transfer_detective.append({
            "eventId": ev["eventId"],
            "playerId": pid,
            "playerName": s(pm.get("name") or ev["canonicalPlayerName"]),
            "selectionRankV3": as_int(pm.get("selectionRankV3"), 999999999),
            "transferDate": ev["transferDate"],
            "transferYear": ev["transferYear"],
            "fromClubKey": fk,
            "fromClubName": s(fm.get("name")),
            "toClubKey": tk,
            "toClubName": s(tm.get("name")),
            "eventTrust": ev["eventTrust"],
        })
    transfer_detective.sort(key=lambda r: (r["selectionRankV3"], -r["transferYear"], r["playerName"].casefold()))

    same_day = defaultdict(set)
    for ev in transfer_events:
        same_day[(ev["canonicalPlayerId"], ev["transferDate"])].add((ev["fromCanonicalClubKey"], ev["toCanonicalClubKey"]))
    for (pid, dt), pairs in same_day.items():
        if len(pairs) > 2:
            anomalies.append({
                "canonicalPlayerId": pid,
                "canonicalPlayerName": s(player_meta.get(pid, {}).get("name")),
                "canonicalClubKey": "",
                "startDate": dt,
                "endDate": dt,
                "reason": f"MULTIPLE_SAME_DAY_TRANSFER_PATHS:{len(pairs)}",
            })

    transfer_events.sort(key=lambda r: (r["canonicalPlayerId"], r["transferDate"], r["eventId"]))
    spells.sort(key=lambda r: (r["canonicalPlayerId"], r["sequence"], r["canonicalClubKey"]))

    write_csv("canonical_transfer_events.csv", transfer_events)
    write_csv("transfer_event_quarantine.csv", transfer_quarantine)
    write_csv("career_spells_candidate.csv", spells)
    write_csv("career_timeline_anomalies.csv", anomalies)
    write_csv("career_puzzle_candidates.csv", puzzle_candidates)
    write_csv("transfer_detective_events.preview.csv", transfer_detective)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "career_timeline_gameplay.preview.json").write_text(
        json.dumps({"schemaVersion": 1, "players": timeline_json}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8"
    )

    event_types = Counter(r["eventType"] for r in transfer_events)
    confidence_counts = Counter(r["spellConfidence"] for r in spells)
    gameplay_spells = [r for r in spells if r["gameplaySenior"] == "YES"]
    players_with_gameplay = len({r["canonicalPlayerId"] for r in gameplay_spells})
    trusted_puzzle = sum(1 for r in puzzle_candidates if r["timelineQuality"] == "A_TRUSTED")
    remapped_event_count = sum(1 for r in transfer_events if r["sourcePlayerId"] != r["canonicalPlayerId"])

    mode_rows = [
        {"mode":"Career Puzzle / Player Journey","status":"G2_CANDIDATE_READY","count":len(puzzle_candidates),"productionRule":"Use A_TRUSTED first; B_PLAYABLE after QA; never raw legacy careerTimeline"},
        {"mode":"Transfer Detective","status":"G2_EVENT_POOL_READY","count":len(transfer_detective),"productionRule":"Canonical from/to club IDs + dates; no market value"},
        {"mode":"Shared XI / Chain","status":"OPTIONAL_TIMELINE_ENRICHMENT","count":players_with_gameplay,"productionRule":"03D.2 remains core relation; G2 adds chronology"},
    ]
    write_csv("mode_readiness_after_g2.csv", mode_rows)

    gates = [
        {"gate":"G2-01","status":"PASS","rule":"Transfer rows require source player-name validation","detail":f"accepted={len(transfer_events):,}; quarantine={len(transfer_quarantine):,}"},
        {"gate":"G2-02","status":"PASS","rule":"03G.1.2 identity map is the only source-player -> canonical-player bridge","detail":f"cross-ID canonicalized events={remapped_event_count:,}"},
        {"gate":"G2-03","status":"PASS","rule":"Pseudo clubs can bound a career but never become career spells","detail":f"pseudoSourceIds={len(pseudo_ids):,}"},
        {"gate":"G2-04","status":"PASS","rule":"No market value or transfer fee is emitted","detail":"Identity, clubs, dates and evidence only"},
        {"gate":"G2-05","status":"PASS" if all(r["uniqueSeniorClubCount"] >= 3 and r["datedSeniorSpellCount"] >= 3 for r in puzzle_candidates) else "FAIL","rule":"Career Puzzle candidates have >=3 clean senior clubs and >=3 dated spells","detail":f"candidates={len(puzzle_candidates):,}; A_TRUSTED={trusted_puzzle:,}"},
        {"gate":"G2-06","status":"PASS","rule":"Runtime assets unchanged","detail":"Only reports/data_platform_v3/03g2 is written"},
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step":"03G.2",
        "runtimeChanged":False,
        "rawTransferRowsScanned":raw_transfer_rows,
        "canonicalTransferEvents":len(transfer_events),
        "transferQuarantineRows":len(transfer_quarantine),
        "eventTypes":dict(event_types),
        "crossIdCanonicalizedTransferEvents":remapped_event_count,
        "appearanceNameMismatchesSkipped":appearance_name_mismatch,
        "appearancePlayerClubBounds":len(appearance_bounds),
        "careerSpellCandidates":len(spells),
        "careerSpellConfidence":dict(confidence_counts),
        "seniorGameplaySpells":len(gameplay_spells),
        "playersWithSeniorGameplayTimeline":players_with_gameplay,
        "careerTimelineAnomalies":len(anomalies),
        "careerPuzzleCandidates":len(puzzle_candidates),
        "careerPuzzleATrusted":trusted_puzzle,
        "transferDetectiveEvents":len(transfer_detective),
        "nextRecommendedStep":"03G.3_DATA_QA_AND_RUNTIME_COMPILER_PREVIEW"
    }
    (OUT_DIR / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    (OUT_DIR / "README.md").write_text(
        f"""# Linkball Data Platform V3 — 03G.2

Canonical transfers and career timeline candidate layer.

- Canonical transfer events: {len(transfer_events):,}
- Career spell candidates: {len(spells):,}
- Senior gameplay timeline players: {players_with_gameplay:,}
- Career Puzzle candidates: {len(puzzle_candidates):,}
- A_TRUSTED Career Puzzle candidates: {trusted_puzzle:,}
- Transfer Detective events: {len(transfer_detective):,}
- Timeline anomalies to review: {len(anomalies):,}

Transfer fee and market value are intentionally not emitted.
Pseudo clubs are preserved only as event boundaries.
No runtime asset is modified.
""", encoding="utf-8")

    print(f"[03G.2] Canonical transfer event: {len(transfer_events):,}")
    print(f"[03G.2] Career spell: {len(spells):,}")
    print(f"[03G.2] Senior gameplay timeline player: {players_with_gameplay:,}")
    print(f"[03G.2] Career Puzzle candidate: {len(puzzle_candidates):,}")
    print(f"[03G.2] A_TRUSTED candidate: {trusted_puzzle:,}")
    print(f"[03G.2] Transfer Detective event: {len(transfer_detective):,}")
    print(f"[03G.2] Timeline anomaly: {len(anomalies):,}")
    print(f"[03G.2] Rapor: {OUT_DIR}")
    print("[03G.2] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
