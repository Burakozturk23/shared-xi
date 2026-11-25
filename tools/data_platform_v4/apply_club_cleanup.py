#!/usr/bin/env python3
"""Reviewed club cleanup the twin merge (v4-2026-11-23.3) could not detect, offline.

Found in the Ortak Oyuncu Keşfi club list (2026-11-26):
- DUPLICATES: one club under two names or country spellings ("Albacete" beside
  "Albacete Balompié", "Inter Miami" USA beside "Inter Miami CF" United States).
- SUCCESSORS: a dissolved club ("KSC Lokeren (-2020)") and the club that carries
  it on. Players treat them as one club; the current row stays, the old one merges.
- RESERVES: reserve and affiliate sides the app's name filter misses ("Bilbao
  Athletic", "Sevilla Atlético", "Milan Futuro"). They become entity_type RESERVE,
  which the app, the server and every catalog builder already leave out.
- COUNTRIES: Nacional (Suárez, Muslera, Coates) is Club Nacional de Football.

Every pair is listed by hand (id and the name expected at that id). A merge moves
links, career stops, transfers and per-club stats to the kept row exactly like
apply_club_twins.merge, and the merged row leaves the gameplay pools.

Run: py -3 tools/data_platform_v4/apply_club_cleanup.py
"""
from contextlib import closing
import collections
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile

from apply_roster_expansion import ROOT, digest
from apply_club_twins import merge

REVISION = 'v4-2026-11-26.1'
BASE_REVISION = 'v4-2026-11-24.1'

# (merged id, its name) -> (kept id, its name)
DUPLICATES = [
    ((24971, 'Albacete'), (1532, 'Albacete Balompié')),
    ((10625, 'Antwerp'), (1096, 'Royal Antwerp FC')),
    ((663, 'Chaves'), (3325, 'GD Chaves')),
    ((22220, 'Dynamo Dresden'), (129, 'SG Dynamo Dresden')),
    ((6105, 'De Graafschap'), (642, 'De Graafschap Doetinchem')),
    ((15758, 'Valenciennes'), (1423, 'Valenciennes FC')),
    ((23287, 'Inter Miami'), (69261, 'Inter Miami CF')),
    ((27221, 'Al-Fateh Club'), (2729, 'Al-Fateh')),
]
SUCCESSORS = [
    ((19, 'Brescia Calcio (- 2025)'), (132806, 'Union Brescia')),
    ((204, 'Lierse SK (-2018)'), (28107, 'K Lierse SK')),
    ((498, 'KSC Lokeren (-2020)'), (7773, 'KSC Lokeren')),
    ((566, 'Beerschot AC (-2013)'), (41274, 'Beerschot VA')),
    ((718, 'KFC Lommel SK (- 2003)'), (5026, 'Lommel SK')),
    ((779, 'FC VSS Kosice (2005 - 2017)'), (51316, 'FC Kosice')),
    ((1073, 'KSK Beveren (-2010)'), (28643, 'SK Beveren')),
    ((1749, 'KFC Verbroedering Geel (-2008)'), (9681, 'AS Verbroedering Geel')),
    ((2180, 'RAA La Louviere (- 2009)'), (3901, 'RAAL La Louvière')),
    ((2477, 'Karpaty Lviv (-2021)'), (85465, 'Karpaty Lviv')),
    ((2742, 'Obolon Kyiv (-2012)'), (39097, 'Obolon Kyiv')),
    ((3172, 'CS Visé (-2015)'), (64501, 'URSL Visé')),
    ((3549, 'Bourges 18 (- 2021)'), (91662, 'Bourges Foot 18')),
    ((51515, 'Bourges Foot (- 2021)'), (91662, 'Bourges Foot 18')),
    ((3898, 'RWDM Brussels FC (-2014)'), (54189, 'RWDM Brussels')),
    ((4786, 'Dukla Banska Bystrica (1965 - 2017)'), (20758, 'MFK Dukla Banska Bystrica')),
    ((4787, 'Dunaújváros FC (-2019)'), (27165, 'Dunaújváros FC')),
    ((6414, 'Metalist Kharkiv (- 2016)'), (83678, 'Metalist Kharkiv')),
    ((6464, 'FK AS Pardubice (1919 - 2011)'), (1496, 'FK Pardubice')),
    ((6994, 'Metalurg Zaporizhya (-2016)'), (36256, 'Metalurh Zaporizhya')),
    ((57930, 'Marignane Gignac FC (-2022)'), (100739, 'Marignane-Gignac-Côte-Bleue FC')),
]
RESERVES = [
    (935, 'LASK Amateure OÖ'), (2464, 'FC Barcelona Atlètic'), (3679, 'Atlético Madrileño'),
    (6688, 'Bilbao Athletic'), (8516, 'CA Osasuna Promesas'), (8519, 'Sevilla Atlético'),
    (28185, 'CD Cruz Azul Hidalgo'), (41101, 'Juventus Next Gen'), (41107, 'Milan Futuro'),
    (80822, 'Tigres UANL B (- 2009)'), (94230, 'CF Pachuca Juniors'),
]
COUNTRIES = [((1000000866, 'Nacional'), 'Uruguay')]


def name_of(con, cid):
    row = con.execute('SELECT name FROM clubs WHERE id=?', (cid,)).fetchone()
    return row and row[0]


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
            for cid, name in [x for pair in DUPLICATES + SUCCESSORS for x in pair] + RESERVES + [x for x, _ in COUNTRIES]:
                if name_of(con, cid) != name:
                    raise ValueError(f'Club {cid} is not {name!r}')
            collapsed, moved = collections.Counter(), 0
            for (old, _), (kept, _) in DUPLICATES + SUCCESSORS:
                moved += con.execute('SELECT COUNT(*) FROM player_clubs WHERE club_id=?', (old,)).fetchone()[0]
                merge(con, old, kept, collapsed)
            for cid, _ in RESERVES:
                con.execute("UPDATE clubs SET entity_type='RESERVE', gameplay_eligible=0 WHERE id=?", (cid,))
            for (cid, _), country in COUNTRIES:
                con.execute('UPDATE clubs SET country=? WHERE id=?', (country, cid))
            links = con.execute('SELECT COUNT(*) FROM player_clubs').fetchone()[0]
            for key, value in [('player_club_rows', links), ('data_revision', REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, duplicates=len(DUPLICATES),
                      successors=len(SUCCESSORS), reserves=len(RESERVES), countries=len(COUNTRIES),
                      movedLinks=moved, collapsedLinksBySource=dict(sorted(collapsed.items())))
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
