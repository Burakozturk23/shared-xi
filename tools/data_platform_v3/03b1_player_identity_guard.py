from __future__ import annotations

import csv
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "data"
OUT = ROOT / "reports" / "data_platform_v3" / "03b1"
POLICY_PATH = Path(__file__).resolve().parent / "config" / "player_identity_policy.json"


def status(message):
    print(f"[03B.1] {message}", flush=True)


def load_json(path: Path, default=None):
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f)


def as_list(v):
    return v if isinstance(v, list) else []


def ntext(v):
    if v is None:
        return ""
    s = unicodedata.normalize("NFKD", str(v)).encode("ascii", "ignore").decode("ascii")
    s = s.casefold().replace("’", "'")
    s = re.sub(r"\([^)]*\)", " ", s)
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def tokens(name):
    return [t for t in ntext(name).split() if t]


def surname(name):
    t = tokens(name)
    return t[-1] if t else ""


def first_initial(name):
    t = tokens(name)
    return t[0][0] if t and t[0] else ""


def name_relation(a, b):
    na, nb = ntext(a), ntext(b)
    if not na or not nb:
        return "none"
    if na == nb:
        return "exact"
    ta, tb = tokens(a), tokens(b)
    if ta and tb and ta[-1] == tb[-1] and ta[0][0] == tb[0][0]:
        return "initial_surname"
    if ta and tb and ta[-1] == tb[-1]:
        return "surname"
    return "none"


def norm_country_set(p):
    vals = []
    for key in ("countries", "nationalities", "country"):
        v = p.get(key)
        if isinstance(v, list):
            vals.extend(v)
        elif isinstance(v, str) and v.strip():
            vals.append(v)
    return {ntext(x) for x in vals if ntext(x)}


def pos_group(v):
    s = ntext(v)
    if not s:
        return ""
    if "goal" in s or s in {"gk", "keeper"}:
        return "gk"
    if "def" in s or "back" in s:
        return "def"
    if "mid" in s:
        return "mid"
    if "attack" in s or "forward" in s or "winger" in s or "striker" in s:
        return "att"
    return s


def player_pos(p):
    return pos_group(p.get("position") or p.get("positionGroup") or p.get("detailedPosition") or p.get("subPosition"))


def identity_score(m, f):
    rel = name_relation(m.get("name"), f.get("name"))
    score = {"exact": 78, "initial_surname": 64, "surname": 38, "none": 0}[rel]
    mc, fc = norm_country_set(m), norm_country_set(f)
    if mc and fc:
        if mc & fc:
            score += 14
        else:
            score -= 30
    mp, fp = player_pos(m), player_pos(f)
    if mp and fp:
        if mp == fp:
            score += 8
        else:
            score -= 12
    # Exact name is strong even if one metadata field is noisy.
    if rel == "exact" and score < 88:
        score = 88
    return max(0, min(100, score)), rel


def index_rows(rows):
    out = {}
    for r in rows or []:
        if not isinstance(r, dict):
            continue
        try:
            pid = int(r.get("id"))
        except Exception:
            continue
        out[pid] = r
    return out


def write_csv(name, headers, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / name).open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=headers, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def useful(v):
    if v is None:
        return False
    if isinstance(v, str):
        return bool(v.strip())
    if isinstance(v, (list, dict)):
        return bool(v)
    if isinstance(v, (int, float)):
        return v != 0
    return True


def same_value(a, b):
    return a == b and useful(a) and useful(b)


def main():
    status("Policy yukleniyor...")
    policy = load_json(POLICY_PATH, {}) or {}
    high = int(policy.get("highConfidenceThreshold", 90))
    margin_needed = int(policy.get("minimumMargin", 8))

    status("players_min.json yukleniyor (buyuk dosyada biraz surebilir)...")
    pmin = load_json(DATA / "players_min.json", []) or []
    status(f"players_min.json tamam: {len(pmin):,} kayit")
    status("players.json yukleniyor (buyuk dosyada biraz surebilir)...")
    pfull = load_json(DATA / "players.json", []) or []
    status(f"players.json tamam: {len(pfull):,} kayit")
    im, iff = index_rows(pmin), index_rows(pfull)
    if not im or not iff:
        raise RuntimeError("assets/data/players_min.json ve players.json gerekli.")

    min_ids, full_ids = set(im), set(iff)
    overlap = min_ids & full_ids

    status("Oyuncu kimlik indeksleri olusturuluyor...")
    surname_index = defaultdict(list)
    exact_name_index = defaultdict(list)
    for mid, m in im.items():
        sn = surname(m.get("name"))
        if sn:
            surname_index[sn].append(mid)
        nn = ntext(m.get("name"))
        if nn:
            exact_name_index[nn].append(mid)

    same_id_safe = []
    collisions = []
    safe_map = {}
    collision_ids = set()

    status(f"Ayni sayisal ID kullanan {len(overlap):,} kayit dogrulaniyor...")
    for idx, pid in enumerate(sorted(overlap), 1):
        if idx % 25000 == 0:
            status(f"Same-ID kontrolu: {idx:,}/{len(overlap):,}")
        m, f = im[pid], iff[pid]
        score, rel = identity_score(m, f)
        row = {
            "numericId": pid,
            "minName": m.get("name", ""),
            "fullName": f.get("name", ""),
            "nameRelation": rel,
            "score": score,
            "minCountries": "|".join(sorted(norm_country_set(m))),
            "fullCountries": "|".join(sorted(norm_country_set(f))),
            "minPosition": player_pos(m),
            "fullPosition": player_pos(f),
        }
        # Same numeric ID may only enrich when identity evidence is strong.
        if score >= high and rel in {"exact", "initial_surname"}:
            row["status"] = "SAFE_SAME_ID"
            same_id_safe.append(row)
            safe_map[pid] = pid
        else:
            row["status"] = "ID_COLLISION_OR_AMBIGUOUS"
            collisions.append(row)
            collision_ids.add(pid)

    status(f"Same-ID kontrolu tamam: {len(same_id_safe):,} guvenli, {len(collisions):,} karantina")

    # Try to remap collided and full-only enrichment rows to the canonical min player.
    proposal_rows = []
    source_map_rows = []
    full_need_mapping = sorted(collision_ids | (full_ids - min_ids))
    auto_alt = 0
    review_alt = 0
    unresolved_alt = 0

    status(f"Alternatif full->min eslesmeleri araniyor: {len(full_need_mapping):,} kayit")
    for map_idx, fid in enumerate(full_need_mapping, 1):
        if map_idx % 10000 == 0:
            status(f"Alternatif esleme: {map_idx:,}/{len(full_need_mapping):,}")
        f = iff[fid]
        candidates = set(exact_name_index.get(ntext(f.get("name")), []))
        sn = surname(f.get("name"))
        candidates.update(surname_index.get(sn, []))
        ranked = []
        for mid in candidates:
            sc, rel = identity_score(im[mid], f)
            if rel == "none":
                continue
            ranked.append((sc, mid, rel))
        ranked.sort(reverse=True)
        best = ranked[0] if ranked else None
        second = ranked[1] if len(ranked) > 1 else None
        if best:
            bscore, bmid, brel = best
            margin = bscore - (second[0] if second else 0)
        else:
            bscore, bmid, brel, margin = 0, "", "none", 0

        if best and bscore >= high and margin >= margin_needed and brel in {"exact", "initial_surname"}:
            match_status = "AUTO_MAP_HIGH"
            auto_alt += 1
        elif best and bscore >= 78:
            match_status = "REVIEW_CANDIDATE"
            review_alt += 1
        else:
            match_status = "UNRESOLVED"
            unresolved_alt += 1

        proposal_rows.append({
            "fullSourceId": fid,
            "fullName": f.get("name", ""),
            "candidateMinId": bmid,
            "candidateMinName": im[bmid].get("name", "") if bmid != "" else "",
            "score": bscore,
            "margin": margin,
            "nameRelation": brel,
            "status": match_status,
        })
        source_map_rows.append({
            "sourceNamespace": "players_full",
            "sourcePlayerId": fid,
            "canonicalMinPlayerId": bmid if match_status == "AUTO_MAP_HIGH" else "",
            "method": "identity_match" if best else "none",
            "confidence": bscore,
            "status": match_status,
        })

    # IMPORTANT: score lookup must be O(1). The previous implementation scanned
    # same_id_safe for every player and became O(n^2) on ~100k records.
    safe_score_by_id = {r["numericId"]: r["score"] for r in same_id_safe}
    status(f"Guvenli source map yazimi hazirlaniyor: {len(safe_map):,} kayit")
    for idx, pid in enumerate(sorted(safe_map), 1):
        if idx % 25000 == 0:
            status(f"Source map: {idx:,}/{len(safe_map):,}")
        source_map_rows.append({
            "sourceNamespace": "players_full",
            "sourcePlayerId": pid,
            "canonicalMinPlayerId": pid,
            "method": "safe_same_id",
            "confidence": safe_score_by_id.get(pid, 100),
            "status": "AUTO_MAP_HIGH",
        })

    status("Alan kontaminasyon riski hesaplaniyor...")

    # Contamination risk: enrichment-looking fields copied by numeric ID where identity collided.
    fields = ["aliases", "careerTimeline", "careerGoals", "marketValue", "peakMarketValue", "nationalTeams", "detailedPosition"]
    contamination = []
    for field in fields:
        min_use = 0
        full_use = 0
        same_on_collision = 0
        min_name_contains_full = 0
        for pid in collision_ids:
            m, f = im[pid], iff[pid]
            a, b = m.get(field), f.get(field)
            min_use += int(useful(a))
            full_use += int(useful(b))
            same_on_collision += int(same_value(a, b))
            if field == "aliases" and isinstance(a, list):
                fn = ntext(f.get("name"))
                if fn and any(ntext(x) == fn for x in a):
                    min_name_contains_full += 1
        risk = "HIGH" if same_on_collision > max(25, len(collision_ids) * 0.15) or min_name_contains_full > max(25, len(collision_ids) * 0.15) else "REVIEW"
        contamination.append({
            "field": field,
            "collisionIds": len(collision_ids),
            "minUsefulOnCollisions": min_use,
            "fullUsefulOnCollisions": full_use,
            "sameValueOnCollisions": same_on_collision,
            "aliasesContainingWrongFullName": min_name_contains_full if field == "aliases" else "",
            "risk": risk,
            "action": "DO_NOT_TRUST_UNTIL_SOURCE_REMAP" if risk == "HIGH" else "VALIDATE_BEFORE_CANONICAL_EXPORT",
        })

    # Numeric club IDs also have namespace collision risk. Example detection uses TM source only in 03C,
    # but freeze the rule here so no later step assumes integer equality across sources.
    gates = [
        {"gate": "P01", "rule": "Same numeric player ID must pass identity validation before enrichment", "status": "PASS", "detail": f"{len(same_id_safe):,} safe / {len(collisions):,} collision-or-ambiguous overlapping IDs"},
        {"gate": "P02", "rule": "Collision IDs cannot donate rich fields by numeric ID", "status": "PASS", "detail": f"{len(collisions):,} IDs quarantined"},
        {"gate": "P03", "rule": "Alternative full->min matches require high confidence and margin", "status": "PASS", "detail": f"{auto_alt:,} auto proposals; {review_alt:,} review; {unresolved_alt:,} unresolved"},
        {"gate": "P04", "rule": "Aliases are not identity evidence during migration", "status": "PASS", "detail": "Aliases may already contain same-ID contamination"},
        {"gate": "P05", "rule": "Source namespace is mandatory for all external player/club IDs", "status": "DESIGN_READY", "detail": "03C will use namespace-qualified club refs"},
    ]

    status("CSV ve ozet raporlari yaziliyor...")
    write_csv("safe_same_id_enrichment.csv", list(same_id_safe[0].keys()) if same_id_safe else ["numericId"], same_id_safe)
    write_csv("player_id_collisions.csv", list(collisions[0].keys()) if collisions else ["numericId"], collisions)
    write_csv("full_to_min_match_proposals.csv", list(proposal_rows[0].keys()) if proposal_rows else ["fullSourceId"], proposal_rows)
    write_csv("player_source_map.csv", ["sourceNamespace", "sourcePlayerId", "canonicalMinPlayerId", "method", "confidence", "status"], source_map_rows)
    write_csv("field_contamination_risk.csv", list(contamination[0].keys()), contamination)
    write_csv("migration_gates.csv", ["gate", "rule", "status", "detail"], gates)

    summary = {
        "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
        "step": "03B.1",
        "runtimeChanged": False,
        "playersMin": len(im),
        "playersFull": len(iff),
        "numericIdOverlap": len(overlap),
        "safeSameIdEnrichment": len(same_id_safe),
        "collisionOrAmbiguousSameId": len(collisions),
        "fullOnly": len(full_ids - min_ids),
        "alternativeAutoMapHigh": auto_alt,
        "alternativeReview": review_alt,
        "alternativeUnresolved": unresolved_alt,
        "decision": "Do not merge players_full into players_min by numeric ID unless identity guard passes. External IDs are namespace-qualified."
    }
    with (OUT / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    high_risk = [r["field"] for r in contamination if r["risk"] == "HIGH"]
    md = f"""# Linkball Data Platform v3 — Step 03B.1 Player Identity Guard

Generated: `{summary['generatedAtUtc']}`

## Why this corrective step exists

03B correctly identified the club namespace problem, but its first draft still treated overlapping numeric player IDs as if they proved identity. They do not. `players_min.json` and `players.json` can contain different source namespaces that reuse the same integer.

This step is **read-only** and does not change runtime data.

## Results

- Canonical/min players: **{len(im):,}**
- Enrichment/full players: **{len(iff):,}**
- Numeric ID overlap: **{len(overlap):,}**
- Safe same-ID enrichment: **{len(same_id_safe):,}**
- Collision / ambiguous same-ID records: **{len(collisions):,}**
- Full-only records: **{len(full_ids-min_ids):,}**
- Alternative high-confidence mapping proposals: **{auto_alt:,}**
- Review candidates: **{review_alt:,}**
- Unresolved enrichment identities: **{unresolved_alt:,}**

## Frozen rule

A raw integer such as `515` is never enough to identify a player or club across different source datasets. Future mappings use `(sourceNamespace, sourceId) -> canonicalId`.

## Fields with high contamination risk

{', '.join(high_risk) if high_risk else 'None automatically classified as HIGH; review the CSV.'}

Any field marked `DO_NOT_TRUST_UNTIL_SOURCE_REMAP` must not enter the new canonical production database until the correct source player has been mapped.

## Next

Send this whole `reports/data_platform_v3/03b1/` folder back. Step 03C will then resolve club identities with the same namespace-qualified rule and will explicitly classify pseudo-clubs such as Retired / Without Club / Career break rather than turning them into visible clubs.
"""
    (OUT / "README.md").write_text(md, encoding="utf-8")

    print("\n03B.1 Player Identity Guard complete.")
    print(f"Report: {OUT}")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
