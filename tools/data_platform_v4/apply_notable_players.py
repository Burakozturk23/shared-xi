#!/usr/bin/env python3
"""Apply the reviewed identities and partial senior-club histories offline."""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile
from apply_roster_expansion import ROOT, digest, norm, add_search

REVIEW = ROOT/'tools/data_platform_v4/patches/notable-players-2026-09-30.json'
REVISION = 'v4-2026-09-30.1'
BASE = '1a5ce8f113133cd7f87bc1249339f17329190edd2b475ff28bf637e5bd621655'
SOURCE = 'reviewed-player'
LINK_SOURCE = 'reviewed:notable:2026-09-30'


def apply(database, manifest_path, review_path=REVIEW):
    database, manifest_path = Path(database), Path(manifest_path)
    review = json.loads(Path(review_path).read_text(encoding='utf-8'))
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    before = digest(database)
    if before != manifest['database']['sha256']:
        raise ValueError('Manifest hash mismatch')
    previous = next((r for r in manifest.get('reviewedAdditions', []) if r['id'] == REVISION), None)
    if previous:
        if previous['evidenceSha256'] != digest(review_path):
            raise ValueError('Applied review evidence changed; create a new reviewed revision')
        return previous
    if before != BASE:
        raise ValueError('Review base hash mismatch')
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td)/database.name
        shutil.copy2(database, output)
        with sqlite3.connect(output) as con:
            con.execute('PRAGMA foreign_keys=ON')
            original = {t: con.execute('SELECT COUNT(*) FROM '+t).fetchone()[0]
                        for t in ('players', 'player_clubs', 'clubs', 'transfers', 'career_spells')}
            identities = {norm(n).replace(' ', '') for (n,) in con.execute(
                'SELECT name FROM players UNION SELECT alias FROM player_aliases')}
            rank = con.execute('SELECT MAX(selection_rank) FROM players').fetchone()[0]
            for r in review['players']:
                key = norm(r['name']).replace(' ', '')
                if key in identities:
                    raise ValueError('Review would duplicate an identity: '+r['name'])
                identities.add(key)
                rank += 1
                con.execute('''INSERT INTO players(id,name,country,position,selection_score,selection_rank,
                    answer_eligible,playable,source) VALUES(?,?,?,?,0,?,1,1,?)''',
                    (r['id'], r['name'], r['country'], r['position'], rank, SOURCE))
                con.execute('''INSERT INTO profiles(player_id,birth_year,citizenship,position_group,identity_confidence)
                    VALUES(?,?,?,?,?)''', (r['id'], r['birthYear'], r['country'], r['position'], 'REVIEWED_IDENTITY'))
                con.execute('INSERT INTO player_countries VALUES(?,0,?)', (r['id'], r['country']))
                con.executemany('INSERT INTO player_tags VALUES(?,?)', [(r['id'],'answer'),(r['id'],'playable')])
            for r in review['players'] + review['corrections']:
                old = con.execute('SELECT name FROM players WHERE id=?', (r['id'],)).fetchone()
                if not old:
                    raise ValueError('Missing correction identity')
                con.execute('UPDATE players SET name=? WHERE id=?', (r['name'], r['id']))
                add_search(con, r['id'], r['name'], 'name', 100)
                add_search(con, r['id'], norm(r['name']).split()[-1], 'surname', 60)
                aliases = set(r.get('aliases', [])) | {r['name'], old[0]}
                existing = {x[0] for x in con.execute('SELECT alias FROM player_aliases WHERE player_id=?', (r['id'],))}
                order = con.execute('SELECT COALESCE(MAX(ord),-1)+1 FROM player_aliases WHERE player_id=?', (r['id'],)).fetchone()[0]
                for label in sorted(aliases - existing):
                    con.execute('INSERT INTO player_aliases VALUES(?,?,?,?)', (r['id'], order, label, norm(label)))
                    order += 1
                    add_search(con, r['id'], label, 'alias', 80)
                for club in r['clubs']:
                    if con.execute('SELECT name FROM clubs WHERE id=?', (club['id'],)).fetchone() != (club['name'],):
                        raise ValueError('Club mapping mismatch')
                    con.execute('INSERT OR IGNORE INTO player_clubs VALUES(?,?,2,?)', (r['id'], club['id'], LINK_SOURCE))
            # Source abbreviations must follow the application's existing position contract.
            for raw, canonical in {'GK':'Goalkeeper','DF':'Defender','MF':'Midfield','FW':'Attack'}.items():
                con.execute('UPDATE players SET position=? WHERE source=? AND position=?', (canonical,'worldcup26-roster',raw))
                con.execute('''UPDATE profiles SET position_group=? WHERE position_group=? AND player_id IN
                    (SELECT id FROM players WHERE source='worldcup26-roster')''', (canonical,raw))
            total = original['players'] + len(review['players'])
            for table in ('clubs','transfers','career_spells'):
                if con.execute('SELECT COUNT(*) FROM '+table).fetchone()[0] != original[table]:
                    raise ValueError('Unexpected history mutation')
            for sql in ('SELECT COUNT(*) FROM players','SELECT COUNT(DISTINCT player_id) FROM player_clubs',
                        'SELECT COUNT(DISTINCT player_id) FROM player_search_terms'):
                if con.execute(sql).fetchone()[0] != total:
                    raise ValueError('Incomplete added player')
            links = con.execute('SELECT COUNT(*) FROM player_clubs').fetchone()[0]
            for key, value in [('player_count',str(total)),('player_club_rows',str(links)),('data_revision',REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)',(key,value))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, evidenceSha256=digest(review_path),
                      newPlayers=len(review['players']), newLinks=links-original['player_clubs'])
        manifest.setdefault('reviewedAdditions', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size, sizeMB=round(output.stat().st_size/1024**2,2))
        for key in ('players','unique_player_ids','players_with_clubs','search_players'):
            manifest['counts'][key] = total
        manifest['revision'] = REVISION
        manifest['updatedUtc'] = review['reviewedUtc']
        next_manifest = Path(td)/manifest_path.name
        next_manifest.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(apply(ROOT/'assets/runtime/linkball_game_data_v4.sqlite',
                           ROOT/'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
