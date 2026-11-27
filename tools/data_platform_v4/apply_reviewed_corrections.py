#!/usr/bin/env python3
"""Apply a reviewed correction file (build_wikipedia_moves.py) to the game database offline.

The file lists, per player, explicit row operations, each checked before it runs:
- addSpell {clubId, start, end, confidence}: a new career stop (sequence = max + 1);
- updateSpell {clubId, start, set:{start_date|end_date|club_id|confidence}}: the one
  stop at that club and start date;
- removeSpell {clubId, start}: that stop;
- addTransfer {eventId, fromClubId, toClubId, date, trust} / removeTransfer {eventId};
- addPlayerClub {clubId, source} / removePlayerClub {clubId};
- addClub {clubId, canonicalKey, name, country}: a senior club the database lacks
  (popularity 0, not in the gameplay pools, no badge), before the stops that use it.
An operation whose row is missing (or, for an add, already there) stops the whole
run. Players never change; clubs only through addClub. Hash-pinned to the manifest and idempotent per
revision, like apply_current_clubs.py.

Run: py -3 tools/data_platform_v4/apply_reviewed_corrections.py tools/data_platform_v4/patches/<file>.json
"""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import sys
import tempfile

from apply_roster_expansion import ROOT, digest

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'
SPELL_FIELDS = {'start_date', 'end_date', 'club_id', 'confidence'}


def spell(con, pid, op):
    rows = con.execute('SELECT sequence FROM career_spells WHERE player_id=? AND club_id=? AND IFNULL(start_date,"")=?',
                       (pid, op['clubId'], op['start'] or '')).fetchall()
    if len(rows) != 1:
        raise ValueError(f'{pid}: expected one spell at {op["clubId"]} from {op["start"]}, found {len(rows)}')
    return rows[0][0]


def run(con, pid, op):
    kind = op['op']
    if kind == 'addSpell':
        if con.execute('SELECT 1 FROM career_spells WHERE player_id=? AND club_id=? AND IFNULL(start_date,"")=?',
                       (pid, op['clubId'], op['start'] or '')).fetchone():
            raise ValueError(f'{pid}: spell already there {op}')
        sequence = con.execute('SELECT IFNULL(MAX(sequence),0) FROM career_spells WHERE player_id=?', (pid,)).fetchone()[0]
        con.execute('INSERT INTO career_spells VALUES(?,?,?,?,?,?,NULL)',
                    (pid, sequence + 1, op['clubId'], op['start'], op['end'], op['confidence']))
    elif kind == 'updateSpell':
        if not op['set'] or set(op['set']) - SPELL_FIELDS:
            raise ValueError(f'{pid}: bad update {op}')
        sequence = spell(con, pid, op)
        for field, value in op['set'].items():
            con.execute(f'UPDATE career_spells SET {field}=? WHERE player_id=? AND sequence=?', (value, pid, sequence))
    elif kind == 'removeSpell':
        con.execute('DELETE FROM career_spells WHERE player_id=? AND sequence=?', (pid, spell(con, pid, op)))
    elif kind == 'addTransfer':
        con.execute('INSERT INTO transfers VALUES(?,?,?,?,?,?,?,NULL)',
                    (op['eventId'], pid, op['date'], int(op['date'][:4]), op['fromClubId'], op['toClubId'], op['trust']))
    elif kind == 'removeTransfer':
        if con.execute('DELETE FROM transfers WHERE event_id=? AND player_id=?', (op['eventId'], pid)).rowcount != 1:
            raise ValueError(f'{pid}: no transfer {op["eventId"]}')
    elif kind == 'addClub':
        con.execute('INSERT INTO clubs(id,canonical_key,name,country,competition,entity_type,popularity_seed,'
                    'gameplay_eligible,gameplay_pool,badge_key,color) VALUES(?,?,?,?,NULL,"SENIOR",0,0,0,NULL,NULL)',
                    (op['clubId'], op['canonicalKey'], op['name'], op['country']))
    elif kind == 'addPlayerClub':
        con.execute('INSERT INTO player_clubs VALUES(?,?,2,?)', (pid, op['clubId'], op['source']))
    elif kind == 'removePlayerClub':
        row = con.execute('SELECT source FROM player_clubs WHERE player_id=? AND club_id=?', (pid, op['clubId'])).fetchone()
        if not row:
            raise ValueError(f'{pid}: no player_clubs row at {op["clubId"]}')
        con.execute('DELETE FROM player_clubs WHERE player_id=? AND club_id=?', (pid, op['clubId']))
        return row[0]
    else:
        raise ValueError('Unknown operation ' + kind)


def apply(path, database=DB, manifest_path=MANIFEST):
    path, database, manifest_path = Path(path), Path(database), Path(manifest_path)
    review = json.loads(path.read_text(encoding='utf-8'))
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    revision = review['id']
    before = digest(database)
    if before != manifest['database']['sha256']:
        raise ValueError('Manifest hash mismatch')
    previous = next((r for r in manifest.get('reviewedAdditions', []) if r['id'] == revision), None)
    if previous:
        if previous['evidenceSha256'] != digest(path):
            raise ValueError('Applied review changed; create a new reviewed revision')
        return previous
    if review.get('baseRevision') != manifest.get('revision'):
        raise ValueError('Review was built on another revision')
    counts, base_links = {}, 0
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td) / database.name
        shutil.copy2(database, output)
        con = sqlite3.connect(output)
        try:
            con.execute('PRAGMA foreign_keys=ON')
            identity = [con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in ('players', 'clubs')]
            # New clubs first: another player's stop may use one.
            for clubs_first in (True, False):
                for player in review['players']:
                    for op in player['ops']:
                        if (op['op'] == 'addClub') == clubs_first:
                            source = run(con, player['playerId'], op)
                            counts[op['op']] = counts.get(op['op'], 0) + 1
                            if source and not source.startswith(('roster:', 'reviewed:')):
                                base_links += 1
            identity[1] += counts.get('addClub', 0)
            if identity != [con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in ('players', 'clubs')]:
                raise ValueError('Unexpected identity mutation')
            spells = con.execute('SELECT COUNT(*) FROM career_spells').fetchone()[0]
            transfers = con.execute('SELECT COUNT(*) FROM transfers').fetchone()[0]
            for key, value in [('career_spell_rows', spells), ('transfer_rows', transfers), ('data_revision', revision)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
            career_players = con.execute('SELECT COUNT(DISTINCT player_id) FROM career_spells').fetchone()[0]
            transfer_players = con.execute('SELECT COUNT(DISTINCT player_id) FROM transfers').fetchone()[0]
            con.commit()
        finally:
            con.close()
        after = digest(output)
        result = dict(id=revision, baseSha256=before, outputSha256=after, evidenceSha256=digest(path),
                      operations=dict(sorted(counts.items())), newClubs=counts.get('addClub', 0),
                      # Base (v3) links removed, e.g. an id collision; test_roster_patch counts them.
                      removedBaseLinks=base_links,
                      # Net change, so tests that sum newCareerSpells over revisions stay exact.
                      newCareerSpells=counts.get('addSpell', 0) - counts.get('removeSpell', 0))
        manifest.setdefault('reviewedAdditions', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size,
                                    sizeMB=round(output.stat().st_size / 1024**2, 2))
        manifest['counts'].update(career_players=career_players, transfer_players=transfer_players, transfers=transfers)
        manifest.update(revision=revision, updatedUtc=review['builtUtc'])
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(apply(sys.argv[1]), indent=2))
