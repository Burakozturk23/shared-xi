#!/usr/bin/env python3
"""Remove the Transfermarkt "without club" placeholder from player careers.

Transfermarkt id 515 is "vereinslos" (without club). The V3 import resolved it
to the club row 515 "Ajman", so 11,135 players looked like Ajman players and
any two of them looked like former team-mates (Squad Challenge, Çinko, chains
and every shared-club query). The placeholder is not a club: its player_clubs
links are removed, the row is renamed and taken out of gameplay pools. Dated
"without club" spells and transfers stay as history under the corrected name.

Also strips the id from the Squad Challenge catalog, whose players were built
from the same links, and gives that catalog a new version.
"""
import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path

from apply_roster_expansion import ROOT, digest

REVISION = 'v4-2026-10-30.1'
PLACEHOLDER_CLUBS = {515: 'Kulüpsüz'}
SQUAD_CATALOGS = [ROOT / 'assets/data/squad_challenge_catalog.json',
                  ROOT / 'functions/data/squad_challenge_catalog.json']


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
            players = con.execute('SELECT COUNT(*) FROM players').fetchone()[0]
            with_clubs = con.execute('SELECT COUNT(DISTINCT player_id) FROM player_clubs').fetchone()[0]
            removed = 0
            for club_id, name in PLACEHOLDER_CLUBS.items():
                removed += con.execute('DELETE FROM player_clubs WHERE club_id=?', (club_id,)).rowcount
                con.execute('''UPDATE clubs SET name=?, country='', competition='', gameplay_eligible=0,
                               gameplay_pool=0 WHERE id=?''', (name, club_id))
            # No player may lose every club: the freeze checks every player has one.
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
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, policy='placeholder_clubs_v1',
                      clubs=sorted(PLACEHOLDER_CLUBS), removedLinks=removed, players=players)
        manifest.setdefault('corrections', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size,
                                    sizeMB=round(output.stat().st_size / 1024 ** 2, 2))
        manifest.update(revision=REVISION, updatedUtc='2026-10-30')
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n',
                                 encoding='utf-8', newline='\n')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


def fix_squad_catalog(path, database=ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'):
    catalog = json.loads(Path(path).read_text(encoding='utf-8'))
    for player in catalog['players']:
        player['clubIds'] = [c for c in player['clubIds'] if c not in PLACEHOLDER_CLUBS]
    # Club names let the game say which club a link runs through and which
    # club has already credited its maximum.
    used = sorted({c for p in catalog['players'] for c in p['clubIds']})
    con = sqlite3.connect(database)
    try:
        names = dict(con.execute('SELECT id, name FROM clubs WHERE id IN (%s)' % ','.join('?' * len(used)), used))
    finally:
        con.close()
    catalog['clubNames'] = {str(c): names[c].strip() for c in used if names.get(c, '').strip()}
    body = {k: v for k, v in catalog.items() if k != 'version'}
    stamp = hashlib.sha256(json.dumps(body, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
    catalog['version'] = 'squad-v2-' + stamp
    Path(path).write_text(json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n',
                          encoding='utf-8', newline='\n')
    return catalog['version']


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--skip-db', action='store_true')
    args = ap.parse_args()
    if not args.skip_db:
        print(json.dumps(fix_database(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite',
                                      ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
    print([fix_squad_catalog(p) for p in SQUAD_CATALOGS])
