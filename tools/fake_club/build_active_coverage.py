#!/usr/bin/env python3
"""Active players for Fake Club: careers checked against English Wikipedia.

The first catalog used only closed careers (retired legends and coaches), so
every round showed a legend. Active stars make the early rounds; their careers
are still open, so a club is shown as real only when the database career and
the Wikipedia infobox (tools/fake_club/wikipedia-active-2026-11-12.json, saved
by tools/data_platform_v4/fetch_wikipedia_careers.py) both have it, and any
infobox club the database does not link is kept as a name the fake can never be.

Read-only on the database. Writes tools/fake_club/active_coverage.json.
Run: py -3 tools/fake_club/build_active_coverage.py [--check]
"""
import argparse
import json
import re
from pathlib import Path
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/data_platform_v4'))
from build_current_club_review import YOUTH, norm, same_club  # noqa: E402

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
WIKI = ROOT / 'tools/fake_club/wikipedia-active-2026-11-12.json'
OUT = ROOT / 'tools/fake_club/active_coverage.json'
REVIEWED_AT = '2026-11-12'
MAX_RANK = 2000  # Well-known players only; tiers by rank are set in build_catalog.py.


def reserve(label):
    n = norm(label)
    return bool(YOUTH.search(n)) or n.startswith('jong ') or n.endswith(' ii') or n.endswith(' b')


def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    clubs = {r['id']: r for r in con.execute('select id,name from clubs')}
    wiki = json.loads(WIKI.read_text(encoding='utf-8'))
    players, rejected = [], {}
    for w in wiki['players']:
        pid = w['playerId']
        person = con.execute('select name,selection_rank from players where id=?', (pid,)).fetchone()
        all_rows = w.get('senior') or []
        rows = [r for r in all_rows if not reserve(r['label'])]
        # A reserve side's first team is never the fake either (Lewandowski: Legia II).
        parents = sorted({re.sub(r'\s+(ii|b|2|u\d\d|reserves?)$', '', x, flags=re.I).strip()
                          for r in all_rows if reserve(r['label']) for x in (r['title'], r['label']) if x})
        if not person or not rows or (person['selection_rank'] or 10**9) > MAX_RANK:
            rejected['no_infobox_or_rank'] = rejected.get('no_infobox_or_rank', 0) + 1
            continue
        linked = {r[0] for r in con.execute('select club_id from player_clubs where player_id=? union '
                                            'select club_id from career_spells where player_id=?', (pid, pid))}
        confirmed, unlinked = set(), []
        for r in rows:
            names = [x for x in (r['title'], r['label']) if x]
            hit = {i for i in linked if i in clubs and any(same_club(clubs[i]['name'], x) for x in names)}
            if hit:
                confirmed |= hit
            else:
                unlinked.append(r['title'] or r['label'])
        if len(confirmed) < 3:
            rejected['fewer_than_three_confirmed_clubs'] = rejected.get('fewer_than_three_confirmed_clubs', 0) + 1
            continue
        players.append(dict(playerId=pid, name=person['name'], rank=person['selection_rank'],
                            seniorClubIds=sorted(confirmed), unlinkedClubNames=sorted(set(unlinked) | set(parents)),
                            sources=['https://en.wikipedia.org/wiki/' + w['title'].replace(' ', '_')],
                            wiki=dict(title=w['title'], revid=w['revid']),
                            coverage='REVIEWED_WIKIPEDIA_CURRENT', reviewedAt=REVIEWED_AT))
    players.sort(key=lambda p: (p['rank'], p['playerId']))
    return dict(schema=1, policy='active careers: a real club is in both the database career and the '
                                 'Wikipedia infobox; infobox clubs the database lacks are never the fake',
                evidence='tools/fake_club/' + WIKI.name, fetchedUtc=wiki['fetchedUtc'],
                counts=dict(players=len(players), rejected=rejected), players=players)


def encode(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    if args.check:
        assert OUT.read_text(encoding='utf-8') == encode(data), 'Active coverage drift'
    else:
        OUT.write_text(encode(data), encoding='utf-8', newline='\n')
    print(json.dumps(data['counts'], ensure_ascii=False))
