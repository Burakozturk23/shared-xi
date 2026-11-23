#!/usr/bin/env python3
"""Merge the clubs V4 records twice into one, offline.

V4 holds some clubs as two rows ("SSC Napoli" and "Napoli", "Paris Saint-Germain"
and "PSG", an offset copy 1000000000+id), with players split between them: 95
Napoli players (Osimhen, Politano, Fabián Ruiz) were linked only to the second
row, so a Napoli grid cell or Club x Club pair missed them. The twin groups are the
ones the PvP builder already detects (tools/pvp/fetch_coach_tenures.primaries:
the offset copy, or the same folded name in the same country); the primary is the
row with most player links.

For every twin: its player links, career stops, transfers and per-club stats move
to the primary (a link both rows had keeps the higher trust; stats keep the larger
value per field), and the twin row stays but leaves the gameplay pools
(gameplay_eligible=0) so club pickers stop offering the same club twice. The
Argentine "Arsenal FC" (Arsenal de Sarandí) gets its own name.

Run: py -3 tools/data_platform_v4/apply_club_twins.py
"""
from contextlib import closing
import collections
import json
import os
from pathlib import Path
import shutil
import sqlite3
import sys
import tempfile

from apply_roster_expansion import ROOT, digest

sys.path.insert(0, str(ROOT / 'tools/pvp'))
import fetch_coach_tenures as tenures  # noqa: E402

REVISION = 'v4-2026-11-23.3'
BASE_REVISION = 'v4-2026-11-23.2'
RENAMES = {4673: ('Arsenal FC', 'Arsenal de Sarandí')}  # id: (old name, new name)


def groups(con):
    links = collections.Counter(r[0] for r in con.execute('SELECT club_id FROM player_clubs'))
    clubs = {str(i): dict(id=str(i), name=n, country=c or '', links=links[i])
             for i, n, c in con.execute('SELECT id,name,country FROM clubs')}
    return {int(k): [int(x) for x in v] for k, v in tenures.club_twins(clubs).items()}


def canonical(database):
    """{twin club id: primary id} of a database: older reviews name a twin row that now has no links."""
    with closing(sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)) as con:
        return {t: p for p, rows in groups(con).items() for t in rows}


def merge(con, twin, primary, collapsed):
    for pid, trust, source in con.execute('SELECT player_id,trust,source FROM player_clubs WHERE club_id=?', (twin,)).fetchall():
        have = con.execute('SELECT trust FROM player_clubs WHERE player_id=? AND club_id=?', (pid, primary)).fetchone()
        if have:
            collapsed[source] += 1  # The player had both rows: one link remains (the primary's).
            con.execute('UPDATE player_clubs SET trust=? WHERE player_id=? AND club_id=?', (max(trust, have[0]), pid, primary))
        else:
            con.execute('INSERT INTO player_clubs VALUES(?,?,?,?)', (pid, primary, trust, source))
    con.execute('DELETE FROM player_clubs WHERE club_id=?', (twin,))
    con.execute('UPDATE career_spells SET club_id=? WHERE club_id=?', (primary, twin))
    con.execute('UPDATE transfers SET from_club_id=? WHERE from_club_id=?', (primary, twin))
    con.execute('UPDATE transfers SET to_club_id=? WHERE to_club_id=?', (primary, twin))
    cols = ('appearances', 'goals', 'assists', 'minutes')
    for row in con.execute('SELECT player_id,' + ','.join(cols) + ' FROM player_club_stats WHERE club_id=?', (twin,)).fetchall():
        have = con.execute('SELECT ' + ','.join(cols) + ' FROM player_club_stats WHERE player_id=? AND club_id=?',
                           (row[0], primary)).fetchone()
        if have:
            best = [max((x for x in (a, b) if x is not None), default=None) for a, b in zip(row[1:], have)]
            con.execute('UPDATE player_club_stats SET ' + ','.join(c + '=?' for c in cols) + ' WHERE player_id=? AND club_id=?',
                        (*best, row[0], primary))
        else:
            con.execute('INSERT INTO player_club_stats(player_id,club_id,' + ','.join(cols) + ') VALUES(?,?,?,?,?,?)',
                        (row[0], primary, *row[1:]))
    con.execute('DELETE FROM player_club_stats WHERE club_id=?', (twin,))
    con.execute('UPDATE clubs SET gameplay_eligible=0 WHERE id=?', (twin,))


def apply(database, manifest_path):
    database, manifest_path = Path(database), Path(manifest_path)
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    before = digest(database)
    if before != manifest['database']['sha256']:
        raise ValueError('Manifest hash mismatch')
    previous = next((r for r in manifest.get('reviewedAdditions', []) if r['id'] == REVISION), None)
    if previous:
        return previous
    if manifest['revision'] != BASE_REVISION:
        raise ValueError('Expected base revision ' + BASE_REVISION)
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td) / database.name
        shutil.copy2(database, output)
        with closing(sqlite3.connect(output)) as con, con:
            con.execute('PRAGMA foreign_keys=ON')
            twins = groups(con)
            moved = con.execute('SELECT COUNT(*) FROM player_clubs WHERE club_id IN (%s)' %
                                ','.join(str(t) for v in twins.values() for t in v)).fetchone()[0]
            collapsed = collections.Counter()
            for primary, rows in sorted(twins.items()):
                for twin in rows:
                    merge(con, twin, primary, collapsed)
            for cid, (old, new) in RENAMES.items():
                if con.execute('SELECT name FROM clubs WHERE id=?', (cid,)).fetchone() != (old,):
                    raise ValueError('Unexpected club name for %d' % cid)
                con.execute('UPDATE clubs SET name=? WHERE id=?', (new, cid))
            links = con.execute('SELECT COUNT(*) FROM player_clubs').fetchone()[0]
            for key, value in [('player_club_rows', links), ('data_revision', REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, twinGroups=len(twins),
                      twins=sum(len(v) for v in twins.values()), movedLinks=moved, renamed=len(RENAMES),
                      collapsedLinksBySource=dict(sorted(collapsed.items())))
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
