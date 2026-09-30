#!/usr/bin/env python3
"""Build an additive reviewed patch from a reviewed roster identity snapshot.

Roster membership qualifies for Grid by user policy (2026-09-29). Does not
invent transfer dates, appearances, career spells, players or clubs.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sqlite3


def load_snapshot(path):
    path = Path(path)
    evidence = json.loads(path.read_text(encoding="utf-8"))
    evidence["rows"] = [r for name in evidence["rowFiles"] for r in json.loads((path.parent/name).read_text(encoding="utf-8"))]
    return evidence


def build(database, snapshot, output):
    evidence = load_snapshot(snapshot)
    rows = evidence['rows']
    if evidence['baseDatabaseSha256'] != hashlib.sha256(Path(database).read_bytes()).hexdigest():
        raise ValueError('Snapshot database hash mismatch')
    patch = {'id': evidence['revision'], 'reviewedUtc': evidence['reviewedUtc'],
        'baseSha256': hashlib.sha256(Path(database).read_bytes()).hexdigest(),
        'scope': 'Add missing player_clubs only; roster membership accepted for Grid; preserve every existing row.',
        'evidence': str(snapshot), 'preconditions': [], 'operations': [], 'postconditions': []}
    con = sqlite3.connect(Path(database).resolve().as_uri()+'?mode=ro', uri=True)
    additions = set()
    source = 'roster:worldcup26:2026-09-29'
    for row in rows:
        if row['status'] != 'add':
            continue
        pid, cid = row['playerId'], row['clubId']
        if (pid, cid) in additions:
            continue
        name, year = con.execute('SELECT p.name,pr.birth_year FROM players p JOIN profiles pr ON pr.player_id=p.id WHERE p.id=?', (pid,)).fetchone()
        if name != row['canonicalName'] or year != row['birthYear'] or not year:
            raise ValueError('Player evidence no longer matches database')
        club = con.execute('SELECT name FROM clubs WHERE id=?', (cid,)).fetchone()
        if not club or club[0] != row['club']:
            raise ValueError('Club evidence mismatch')
        if con.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?',(pid,cid)).fetchone():
            raise ValueError('Expected missing link already exists')
        additions.add((pid,cid))
        patch['preconditions'].append({'sql':'SELECT name FROM players WHERE id=?','args':[pid],'rows':[[name]]})
        patch['preconditions'].append({'sql':'SELECT club_id FROM player_clubs WHERE player_id=? AND club_id=?','args':[pid,cid],'rows':[]})
        patch['operations'].append({'sql':'INSERT INTO player_clubs(player_id,club_id,trust,source) VALUES(?,?,?,?)','args':[pid,cid,2,source],'changes':1})
        patch['postconditions'].append({'sql':'SELECT trust,source FROM player_clubs WHERE player_id=? AND club_id=?','args':[pid,cid],'rows':[[2,source]]})
    before = con.execute('SELECT COUNT(*) FROM player_clubs').fetchone()[0]
    patch['preconditions'].append({'sql':'SELECT COUNT(*) FROM player_clubs','rows':[[before]]})
    patch['postconditions'].append({'sql':'SELECT COUNT(*) FROM player_clubs','rows':[[before+len(additions)]]})
    # Metadata follows the package revision; historical import counts stay historical.
    patch['operations'].append({'sql':"INSERT OR REPLACE INTO metadata(key,value) VALUES('data_revision',?)",'args':[evidence['revision']],'changes':1})
    patch['operations'].append({'sql':"UPDATE metadata SET value=? WHERE key='player_club_rows'",'args':[str(before+len(additions))],'changes':1})
    con.close()
    Path(output).write_text(json.dumps(patch,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Additions:',len(additions), 'Evidence:',dict(Counter(r['status'] for r in rows)))
    return patch


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('database');p.add_argument('snapshot');p.add_argument('output')
    a=p.parse_args();build(a.database,a.snapshot,a.output)
