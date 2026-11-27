#!/usr/bin/env python3
"""Add the reviewed well-known footballers missing from V4 (build_famous_players.py), offline.

Each player gets identity, countries, search terms, club links and year-precision
career stops from the pinned Wikipedia infobox. No club is created. A player whose
normalized name or alias already belongs to a V4 player born within a year is
refused (the same person); namesakes of other ages are allowed, as V4 already
holds them (eleven players called Paulinho). Ranks are set afterwards by
apply_pageview_ranks.py; here a new player is appended after the last rank.

Run: py -3 tools/data_platform_v4/apply_famous_players.py
"""
from contextlib import closing
import collections
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile

from apply_roster_expansion import ROOT, digest, norm, add_search

REVIEW = ROOT / 'tools/data_platform_v4/patches/famous-players-2026-11-23.json'
REVISION = 'v4-2026-11-23.1'
BASE = 'ceec4481b4cd843f17a9b04eeed45dd0f5df635ad0ac2f71d368737212b4f307'
LINK_SOURCE = 'reviewed:famous-players:2026-11-23'


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
            raise ValueError('Applied review changed; create a new reviewed revision')
        return previous
    if before != BASE:
        raise ValueError('Review base hash mismatch')
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td) / database.name
        shutil.copy2(database, output)
        with closing(sqlite3.connect(output)) as con, con:
            con.execute('PRAGMA foreign_keys=ON')
            original = {t: con.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0]
                        for t in ('players', 'player_clubs', 'clubs', 'coaches', 'career_spells', 'transfers')}
            born = dict(con.execute('SELECT player_id,birth_year FROM profiles'))
            owners = collections.defaultdict(set)
            for pid, label in con.execute('SELECT id,name FROM players UNION SELECT player_id,alias FROM player_aliases'):
                owners[norm(label).replace(' ', '')].add(pid)
            rank = con.execute('SELECT MAX(selection_rank) FROM players').fetchone()[0]
            for r in review['players']:
                labels = []
                for label in [r['name']] + r['aliases']:
                    key = norm(label).replace(' ', '')
                    if not key or any(norm(x).replace(' ', '') == key for x in labels):
                        continue
                    same = [p for p in owners[key] if r['birthYear'] and born.get(p) and abs(born[p] - r['birthYear']) <= 1]
                    if same:
                        raise ValueError(f'Review would duplicate {label} ({same[0]})')
                    labels.append(label)
                for label in labels:
                    owners[norm(label).replace(' ', '')].add(r['id'])
                born[r['id']] = r['birthYear']
                rank += 1
                con.execute('''INSERT INTO players(id,name,country,position,selection_score,
                    selection_rank,answer_eligible,playable,source)
                    VALUES(?,?,?,?,0,?,1,1,'reviewed-player')''',
                    (r['id'], r['name'], r['countries'][0], r['position'], rank))
                con.execute('''INSERT INTO profiles(player_id,birth_year,citizenship,position_group,identity_confidence)
                    VALUES(?,?,?,?,?)''', (r['id'], r['birthYear'], r['countries'][0], r['position'], 'REVIEWED_IDENTITY'))
                con.executemany('INSERT INTO player_countries VALUES(?,?,?)',
                                [(r['id'], i, c) for i, c in enumerate(r['countries'])])
                con.executemany('INSERT INTO player_tags VALUES(?,?)', [(r['id'], 'answer'), (r['id'], 'playable')])
                for i, label in enumerate(labels):
                    con.execute('INSERT INTO player_aliases VALUES(?,?,?,?)', (r['id'], i, label, norm(label)))
                    add_search(con, r['id'], label, 'name' if i == 0 else 'alias', 100 if i == 0 else 90)
                add_search(con, r['id'], norm(r['name']).split()[-1], 'surname', 60)
                for c in r['clubs']:
                    if con.execute('SELECT name FROM clubs WHERE id=?', (c['id'],)).fetchone() != (c['name'],):
                        raise ValueError('Club mapping mismatch: ' + c['name'])
                    con.execute('INSERT INTO player_clubs VALUES(?,?,2,?)', (r['id'], c['id'], LINK_SOURCE))
                linked = {c['id'] for c in r['clubs']}
                for i, s in enumerate(r['spells']):
                    if s['id'] not in linked:
                        raise ValueError('Spell club is not linked: ' + r['name'])
                    con.execute('INSERT INTO career_spells VALUES(?,?,?,?,?,?,NULL)',
                        (r['id'], i, s['id'], str(s['startYear']) if s['startYear'] else None,
                         str(s['endYear']) if s['endYear'] else None,
                         'REVIEWED_YEAR' if s['startYear'] else 'REVIEWED_UNDATED'))
            counts = {t: con.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0] for t in original}
            for table in ('clubs', 'coaches', 'transfers'):
                if counts[table] != original[table]:
                    raise ValueError('Unexpected mutation of ' + table)
            for key, value in [('player_count', counts['players']), ('player_club_rows', counts['player_clubs']),
                               ('career_spell_rows', counts['career_spells']), ('data_revision', REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
            career_players = con.execute('SELECT COUNT(DISTINCT player_id) FROM career_spells').fetchone()[0]
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, evidenceSha256=digest(review_path),
                      newPlayers=counts['players'] - original['players'],
                      newLinks=counts['player_clubs'] - original['player_clubs'],
                      newCareerSpells=counts['career_spells'] - original['career_spells'])
        manifest.setdefault('reviewedAdditions', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size, sizeMB=round(output.stat().st_size / 1024**2, 2))
        for key in ('players', 'unique_player_ids', 'players_with_clubs', 'search_players'):
            manifest['counts'][key] = counts['players']
        manifest['counts'].update(career_players=career_players)
        manifest.update(revision=REVISION, updatedUtc=review['reviewedUtc'])
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(apply(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite',
                           ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
