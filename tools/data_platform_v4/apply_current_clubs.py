#!/usr/bin/env python3
"""Apply the reviewed summer-2026 moves (build_current_club_review.py) offline.

Per reviewed player, except excludedPlayerIds:
- a new final career stop at the club joined, from 2026-07-01 (season
  precision, confidence REVIEWED_SEASON);
- closeLastStop: the open last stop ends at 2026-07-01;
- transfer: one move club left -> club joined, 2026-07-01, trust REVIEWED_SEASON.
No other row changes. Hash-pinned to the manifest and idempotent per revision.

Run: py -3 tools/data_platform_v4/apply_current_clubs.py
"""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile

from apply_roster_expansion import ROOT, digest

REVIEW = ROOT / 'tools/data_platform_v4/patches/current-clubs-2026-11-11.json'
REVISION = 'v4-2026-11-11.1'
SEASON = 'REVIEWED_SEASON'


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
    if review['id'] != REVISION:
        raise ValueError('Review revision mismatch')
    start = review['seasonStart']
    excluded = set(review['excludedPlayerIds'])
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output = Path(td) / database.name
        shutil.copy2(database, output)
        with sqlite3.connect(output) as con:
            con.execute('PRAGMA foreign_keys=ON')
            original = {t: con.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0]
                        for t in ('players', 'player_clubs', 'clubs', 'career_spells', 'transfers')}
            stops = closed = moves = 0
            for r in review['players']:
                pid = r['playerId']
                if pid in excluded:
                    continue
                last = con.execute('''SELECT sequence,club_id,end_date FROM career_spells WHERE player_id=?
                    ORDER BY start_date DESC, sequence DESC LIMIT 1''', (pid,)).fetchone()
                if not last or last[1] != r['fromClubId'] or (last[2] or None) != r['fromEnd']:
                    raise ValueError(f"Career changed since review: {r['name']}")
                for club in (r['fromClubId'], r['toClubId']):
                    if not con.execute('SELECT 1 FROM clubs WHERE id=?', (club,)).fetchone():
                        raise ValueError('Unknown club ' + str(club))
                if r['closeLastStop']:
                    con.execute('UPDATE career_spells SET end_date=? WHERE player_id=? AND sequence=?',
                                (start, pid, last[0]))
                    closed += 1
                sequence = con.execute('SELECT MAX(sequence) FROM career_spells WHERE player_id=?', (pid,)).fetchone()[0]
                con.execute('INSERT INTO career_spells VALUES(?,?,?,?,NULL,?,NULL)',
                            (pid, sequence + 1, r['toClubId'], start, SEASON))
                stops += 1
                if r['transfer']:
                    con.execute('INSERT INTO transfers VALUES(?,?,?,?,?,?,?,NULL)',
                                (f"season:{pid}:2026:{r['fromClubId']}:{r['toClubId']}", pid, start,
                                 int(start[:4]), r['fromClubId'], r['toClubId'], SEASON))
                    moves += 1
            counts = {t: con.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0] for t in original}
            if any(counts[t] != original[t] for t in ('players', 'player_clubs', 'clubs')):
                raise ValueError('Unexpected identity mutation')
            for key, value in [('career_spell_rows', counts['career_spells']), ('transfer_rows', counts['transfers']),
                               ('data_revision', REVISION)]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', (key, str(value)))
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Integrity failure')
            career_players = con.execute('SELECT COUNT(DISTINCT player_id) FROM career_spells').fetchone()[0]
            transfer_players = con.execute('SELECT COUNT(DISTINCT player_id) FROM transfers').fetchone()[0]
        con.close()
        after = digest(output)
        result = dict(id=REVISION, baseSha256=before, outputSha256=after, evidenceSha256=digest(review_path),
                      newCareerSpells=stops, closedLastStops=closed, newTransfers=moves)
        manifest.setdefault('reviewedAdditions', []).append(result)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size,
                                    sizeMB=round(output.stat().st_size / 1024**2, 2))
        manifest['counts'].update(career_players=career_players, transfer_players=transfer_players,
                                  transfers=counts['transfers'])
        manifest.update(revision=REVISION, updatedUtc=review['sources']['sporx']['fetchedUtc'])
        next_manifest = Path(td) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    return result


if __name__ == '__main__':
    print(json.dumps(apply(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite',
                           ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'), indent=2))
