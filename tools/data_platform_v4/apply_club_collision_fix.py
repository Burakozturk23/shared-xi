#!/usr/bin/env python3
"""Move Transfermarkt-club players off the older club that shares their id.

Transfermarkt club ids are stored as 1000000000 + TM id. For 35 of them the
plain id belongs to a different, older club row (club_offset_mismatch.json,
reviewed by name 2026-11-11): TM 208 is CSKA Sofia, row 208 is Haras El Hodood.
The V3 import resolved the TM id to the plain row, so CSKA's players (Berbatov,
Manchev) were linked to Haras El Hodood, Dinamo Tbilisi's (Kvaratskhelia) to
Chaves, Qarabağ's (Begović) to Antwerp. Those imported links carry trust 1; the
row's own players carry trust 2 (Luuk de Jong at De Graafschap, Stuani at
Albacete). Every trust-1 link on such a plain id moves to the TM club id.
"""
import json
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path

from apply_roster_expansion import ROOT, digest

REVISION = 'v4-2026-11-12.2'
MISMATCH = ROOT / 'tools/data_platform_v4/club_offset_mismatch.json'


def pairs():
    return [(x['notSameAs'], x['id']) for x in json.loads(MISMATCH.read_text(encoding='utf-8'))['ids']]


def move_links(con, collisions):
    """Returns links moved per plain club and how many were already on the TM club."""
    moved, merged = {}, 0
    for plain, tm in collisions:
        if not con.execute('SELECT 1 FROM clubs WHERE id=?', (tm,)).fetchone():
            raise ValueError(f'Missing TM club {tm}')
        rows = con.execute('SELECT player_id, source FROM player_clubs WHERE club_id=? AND trust=1',
                           (plain,)).fetchall()
        for player, source in rows:
            if not con.execute('INSERT OR IGNORE INTO player_clubs VALUES(?,?,1,?)', (player, tm, source)).rowcount:
                merged += 1
            con.execute('DELETE FROM player_clubs WHERE player_id=? AND club_id=?', (player, plain))
        if rows:
            moved[str(plain)] = len(rows)
    return moved, merged


def fix_database(database, manifest_path):
    database, manifest_path = Path(database), Path(manifest_path)
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    before = digest(database)
    if before != manifest['database']['sha256']:
        raise ValueError('Manifest hash mismatch')
    previous = next((c for c in manifest.get('corrections', []) if c['id'] == REVISION), None)
    if previous:
        return previous
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td) / database.name
        shutil.copy2(database, output)
        con = sqlite3.connect(output)
        try:
            con.execute('PRAGMA foreign_keys=ON')
            with_clubs = con.execute('SELECT COUNT(DISTINCT player_id) FROM player_clubs').fetchone()[0]
            moved, merged = move_links(con, pairs())
            if con.execute('SELECT COUNT(DISTINCT player_id) FROM player_clubs').fetchone()[0] != with_clubs:
                raise ValueError('A player would be left without any club')
            rows = con.execute('SELECT COUNT(*) FROM player_clubs').fetchone()[0]
            for key, value in [('player_club_rows', rows), ('data_revision', REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or \
                    con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
            con.commit()
            con.execute('VACUUM')
        finally:
            con.close()
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, policy='club_id_collisions_v1',
                      movedLinks=sum(moved.values()), removedLinks=merged, byPlainClub=moved)
        manifest.setdefault('corrections', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size,
                                    sizeMB=round(output.stat().st_size / 1024 ** 2, 2))
        manifest.update(revision=REVISION, updatedUtc='2026-11-12')
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n',
                                 encoding='utf-8', newline='\n')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(fix_database(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite',
                                  ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
