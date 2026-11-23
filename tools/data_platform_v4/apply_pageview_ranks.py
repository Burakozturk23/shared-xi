#!/usr/bin/env python3
"""Place players without a measured rank by their English Wikipedia pageviews, offline.

selection_rank orders players from best known (1). V4 computed it for its own
players; every later addition (reviewed legends, the World Cup roster, the famous
players) was appended after the last rank, so Hagi or Maldini ranked as the least
known players and difficulty tiers (rank <= 2000 / 3000 / 6000 / 12000) and bots
treated them as obscure. 33 V4 players had no rank at all.

Evidence: patches/pageviews-2026-11-23.json (English Wikipedia views of the last 60
days per article), pageviews-tr-2026-11-23.json (the same on the Turkish Wikipedia for
Türkiye players, added: this game's audience reads it, the English one understates
them), famous-players-matched-2026-11-23.json and rank-articles-2026-11-23.json
(article -> V4 player), plus the famous-players patch (its own articles).

Anchors are V4-ranked players with an article: their rank stays the reference. A
player to place (non-V4 source, or no rank) with an article gets the median rank
of the 25 anchors whose views are closest (log scale), then every player is
renumbered 1..N in that order (anchors keep their relative order). Players to
place without an article keep their relative order after all ranked ones.

Run: py -3 tools/data_platform_v4/apply_pageview_ranks.py
"""
from contextlib import closing
import bisect
import json
import math
import os
from pathlib import Path
import shutil
import sqlite3
import statistics
import tempfile

from apply_roster_expansion import ROOT, digest

PATCHES = ROOT / 'tools/data_platform_v4/patches'
PAGEVIEWS = PATCHES / 'pageviews-2026-11-23.json'
MATCHED = PATCHES / 'famous-players-matched-2026-11-23.json'
FAMOUS = PATCHES / 'famous-players-2026-11-23.json'
ARTICLES = PATCHES / 'rank-articles-2026-11-23.json'
TR_PAGEVIEWS = PATCHES / 'pageviews-tr-2026-11-23.json'
REVISION = 'v4-2026-11-23.2'
BASE_REVISION = 'v4-2026-11-23.1'
NEIGHBOURS = 25


def evidence_digest():
    import hashlib
    h = hashlib.sha256()
    for p in (PAGEVIEWS, TR_PAGEVIEWS, MATCHED, FAMOUS, ARTICLES):
        h.update(p.read_bytes())
    return h.hexdigest()


def placements(con):
    english = json.loads(PAGEVIEWS.read_text(encoding='utf-8'))
    turkish = json.loads(TR_PAGEVIEWS.read_text(encoding='utf-8'))
    views = {t: v + (turkish.get(t) or 0) for t, v in english.items() if v is not None}
    article = {pid: t for t, pid in json.loads(MATCHED.read_text(encoding='utf-8')).items()}
    article.update({int(i): t for i, t in json.loads(ARTICLES.read_text(encoding='utf-8')).items()})
    article.update({p['id']: p['source']['title'] for p in json.loads(FAMOUS.read_text(encoding='utf-8'))['players']})
    rows = con.execute('SELECT id,source,selection_rank FROM players').fetchall()
    def seen(pid):
        v = views.get(article.get(pid))
        return math.log10(v + 1) if v is not None else None
    anchors = sorted((seen(i), r) for i, s, r in rows if s == 'v4' and r is not None and seen(i) is not None)
    keys = [v for v, _ in anchors]
    def estimate(v):
        at = bisect.bisect_left(keys, v)
        lo, hi = max(0, at - NEIGHBOURS), min(len(anchors), at + NEIGHBOURS)
        near = sorted(anchors[lo:hi], key=lambda a: abs(a[0] - v))[:NEIGHBOURS]
        return statistics.median(r for _, r in near)
    out = {}
    for i, src, r in rows:
        if src == 'v4' and r is not None:
            continue  # V4's own ranks keep their numbers: every rank threshold keeps its meaning.
        if seen(i) is not None:
            out[i] = max(1, round(estimate(seen(i))))
    return out, len(anchors)


def apply(database, manifest_path):
    database, manifest_path = Path(database), Path(manifest_path)
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    before = digest(database)
    if before != manifest['database']['sha256']:
        raise ValueError('Manifest hash mismatch')
    previous = next((r for r in manifest.get('reviewedAdditions', []) if r['id'] == REVISION), None)
    if previous:
        if previous['evidenceSha256'] != evidence_digest():
            raise ValueError('Applied evidence changed; create a new reviewed revision')
        return previous
    if manifest['revision'] != BASE_REVISION:
        raise ValueError('Expected base revision ' + BASE_REVISION)
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td) / database.name
        shutil.copy2(database, output)
        with closing(sqlite3.connect(output)) as con, con:
            ranks, anchors = placements(con)
            old = dict(con.execute('SELECT id,selection_rank FROM players'))
            con.executemany('UPDATE players SET selection_rank=? WHERE id=?', [(n, i) for i, n in ranks.items()])
            moved = sum(1 for i, n in ranks.items() if old[i] != n)
            con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', ('data_revision', REVISION))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError('Integrity failure')
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, evidenceSha256=evidence_digest(),
                      anchors=anchors, ranked=len(ranks), changed=moved)
        manifest.setdefault('reviewedAdditions', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size, sizeMB=round(output.stat().st_size / 1024**2, 2))
        manifest.update(revision=REVISION)
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(apply(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite',
                           ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
