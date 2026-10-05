#!/usr/bin/env python3
"""Apply the reviewed avatar identities, year-precision careers and coach data."""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile

from apply_roster_expansion import ROOT, digest, norm, add_search

REVIEW = ROOT / 'tools/data_platform_v4/patches/avatar-careers-2026-10-05.json'
REVISION = 'v4-2026-10-05.1'
BASE = '7c3b5386816ec62c91fe199d8c571331cf5becb7bd124e279a1babe9d073d8cd'
LINK_SOURCE = 'reviewed:avatar-careers:2026-10-05'


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
        with sqlite3.connect(output) as con:
            con.execute('PRAGMA foreign_keys=ON')
            original = {t: con.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0]
                        for t in ('players', 'player_clubs', 'clubs', 'coaches', 'career_spells', 'transfers')}
            for c in review['newClubs']:
                con.execute('''INSERT INTO clubs(id,canonical_key,name,country,entity_type)
                    VALUES(?,?,?,?,?)''', (c['id'], c['canonicalKey'], c['name'], c['country'],
                                           'DEVELOPMENT' if c['entityType'] == 'reserve' else 'SENIOR'))
            rank = con.execute('SELECT MAX(selection_rank) FROM players').fetchone()[0]
            for r in review['players']:
                rank += 1
                eligible = int(r['playable'])
                con.execute('''INSERT INTO players(id,name,country,position,selection_score,
                    selection_rank,answer_eligible,playable,visual_priority,avatar_key,source)
                    VALUES(?,?,?,?,0,?,?,?,?,?,'reviewed-player')''',
                    (r['id'], r['name'], r['country'], r['position'], rank, eligible, eligible, 1, r['key']))
                con.execute('''INSERT INTO profiles(player_id,birth_year,citizenship,position_group,identity_confidence)
                    VALUES(?,?,?,?,?)''', (r['id'], r['birthYear'], r['country'], r['position'], 'REVIEWED_IDENTITY'))
                con.execute('INSERT INTO player_countries VALUES(?,0,?)', (r['id'], r['country']))
                if eligible:
                    con.executemany('INSERT INTO player_tags VALUES(?,?)', [(r['id'], 'answer'), (r['id'], 'playable')])
                labels = list(dict.fromkeys([r['name']] + r['aliases']))
                for i, label in enumerate(labels):
                    con.execute('INSERT INTO player_aliases VALUES(?,?,?,?)', (r['id'], i, label, norm(label)))
                    add_search(con, r['id'], label, 'name' if i == 0 else 'alias', 100 if i == 0 else 90)
                add_search(con, r['id'], norm(r['name']).split()[-1], 'surname', 60)
                for c in r['clubs']:
                    if con.execute('SELECT name FROM clubs WHERE id=?', (c['id'],)).fetchone() != (c['name'],):
                        raise ValueError('Club mapping mismatch: ' + c['name'])
                    con.execute('INSERT INTO player_clubs VALUES(?,?,2,?)', (r['id'], c['id'], LINK_SOURCE))
                for i, s in enumerate(r['spells']):
                    con.execute('INSERT INTO career_spells VALUES(?,?,?,?,?,?,NULL)',
                        (r['id'], i, s['id'], str(s['startYear']) if s['startYear'] else None,
                         str(s['endYear']) if s['endYear'] else None, 'REVIEWED_YEAR' if s['startYear'] else 'REVIEWED_UNDATED'))
            existing = {json.loads(payload)['id']: id for id, payload in con.execute('SELECT id,payload_json FROM coaches')}
            next_coach = min(existing.values()) - 1
            fields = ('id', 'name', 'countries', 'clubIds', 'aliases', 'avatarKey', 'rating')
            for c in review['coaches']:
                for cid in dict.fromkeys(c['legacyIds'] + [c['id']]):
                    if cid.startswith('seed_') or (cid not in existing and cid != c['id']):
                        continue
                    payload = {k: c[k] for k in fields}
                    payload['id'] = cid
                    body = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
                    if cid in existing:
                        con.execute('UPDATE coaches SET name=?,normalized_name=?,payload_json=? WHERE id=?',
                                    (c['name'], norm(c['name']), body, existing[cid]))
                    else:
                        con.execute('INSERT INTO coaches VALUES(?,?,?,?)', (next_coach, c['name'], norm(c['name']), body))
                        existing[cid] = next_coach
                        next_coach -= 1
            counts = {t: con.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0] for t in original}
            if counts['transfers'] != original['transfers']:
                raise ValueError('Unexpected transfer mutation')
            for key, value in [('player_count', counts['players']), ('player_club_rows', counts['player_clubs']),
                               ('club_count', counts['clubs']), ('coach_count', counts['coaches']), ('data_revision', REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
            career_players = con.execute('SELECT COUNT(DISTINCT player_id) FROM career_spells').fetchone()[0]
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, evidenceSha256=digest(review_path),
                      newPlayers=counts['players'] - original['players'], newLinks=counts['player_clubs'] - original['player_clubs'],
                      newClubs=counts['clubs'] - original['clubs'], newCoaches=counts['coaches'] - original['coaches'],
                      newCareerSpells=counts['career_spells'] - original['career_spells'])
        manifest.setdefault('reviewedAdditions', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size, sizeMB=round(output.stat().st_size / 1024**2, 2))
        for key in ('players', 'unique_player_ids', 'players_with_clubs', 'search_players'):
            manifest['counts'][key] = counts['players']
        manifest['counts'].update(clubs=counts['clubs'], coaches=counts['coaches'], career_players=career_players)
        manifest.update(revision=REVISION, updatedUtc=review['reviewedUtc'])
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(apply(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite',
                           ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
