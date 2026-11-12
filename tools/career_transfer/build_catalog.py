"""Deterministic, conservative V4 export. Never invent dates, fees or loan types."""
import argparse
from collections import Counter, defaultdict
from datetime import date
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
OUT = ROOT / 'functions/config/career_transfer_catalog.json'

def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    source = json.loads((ROOT/'functions/config/three_modes_catalog.json').read_text())
    players = {p['id']: p for p in source['players']}
    rawclubs = {r['id']: dict(r) for r in con.execute('select * from clubs')}
    # TM ids that collide with a different club keep their own id (reviewed list).
    OFFSET_MISMATCH = {x['id'] for x in __import__('json').loads((__import__('pathlib').Path(__file__).resolve().parents[2] / 'tools/data_platform_v4/club_offset_mismatch.json').read_text(encoding='utf-8'))['ids']}

    def cid(i):
        # Exposed V4 TM identifiers use the same TM ID with a namespace offset.
        original = i - 1000000000
        return original if i >= 1000000000 and i not in OFFSET_MISMATCH and original in rawclubs else i
    clubs = {cid(i): dict(id=cid(i), name=rawclubs[cid(i)]['name'],
             badgeKey=rawclubs[cid(i)]['badge_key']) for i in rawclubs
             if rawclubs[cid(i)]['entity_type'] == 'SENIOR' and rawclubs[cid(i)]['gameplay_eligible']}
    def valid_date(s):
        try:
            return bool(s and len(s) == 10 and date.fromisoformat(s) <= date(2026, 10, 16))
        except ValueError:
            return False
    def eligible(pid):
        p = players.get(pid)
        return p and p['rank'] <= 5000 and p['country'] and p['position']
    careers = defaultdict(list)
    rejected = Counter()
    for r in con.execute('select * from career_spells order by player_id,start_date,sequence'):
        club = cid(r['club_id'])
        if not eligible(r['player_id']) or club not in clubs: continue
        if r['confidence'] not in ('HIGH', 'REVIEWED_YEAR', 'REVIEWED_SEASON') or not valid_date(r['start_date']):
            rejected['uncertain_career_period'] += 1; continue
        end = r['end_date'] or None
        if end and (not valid_date(end) or end < r['start_date']):
            rejected['invalid_career_end'] += 1; continue
        identity = hashlib.sha256(f"{r['player_id']}|{club}|{r['start_date']}|{end}".encode()).hexdigest()[:24]
        careers[r['player_id']].append(dict(id=identity, clubId=club, start=r['start_date'], end=end,
            precision={'REVIEWED_YEAR': 'year', 'REVIEWED_SEASON': 'season'}.get(r['confidence'], 'date')))
    puzzles = []
    for pid, stops in sorted(careers.items()):
        stops = list({s['id']: s for s in stops}.values())
        if any(a['start'] == b['start'] or a['end'] is None or a['end'] > b['start']
               for a,b in zip(stops, stops[1:])):
            rejected['overlapping_career'] += 1; continue
        if len(stops) < 3: continue
        difficulty = 'beginner' if len(stops) < 5 else 'normal' if len(stops) < 8 else 'legend'
        puzzles.append(dict(id=str(pid), playerId=pid, difficulty=difficulty, stops=stops[:12],
            source='V4 career_spells: HIGH / REVIEWED_YEAR / REVIEWED_SEASON; selected periods'))
    events = {}
    for r in con.execute('select * from transfers order by event_id'):
        a,b = cid(r['from_club_id']),cid(r['to_club_id'])
        if not eligible(r['player_id']) or a not in clubs or b not in clubs or a == b: continue
        # REVIEWED_SEASON: a summer-2026 move known to the season, not the day.
        if r['trust'] not in ('HIGH', 'REVIEWED_SEASON') or not valid_date(r['transfer_date']) or int(r['transfer_date'][:4]) != r['transfer_year']:
            rejected['invalid_transfer'] += 1; continue
        if max(rawclubs[a]['popularity_seed'],rawclubs[b]['popularity_seed']) < 10: continue
        key = hashlib.sha256(f"{r['player_id']}|{a}|{b}|{r['transfer_date']}".encode()).hexdigest()[:24]
        events[key] = dict(id=key, playerId=r['player_id'], fromClubId=a, toClubId=b,
            date=r['transfer_date'], year=r['transfer_year'], source='V4 transfers / ' + r['trust'], sourceEventId=r['event_id'],
            **({'precision': 'season'} if r['trust'] == 'REVIEWED_SEASON' else {}))
    # Visible clues must have exactly one answer among catalog events.
    clue_counts = Counter((e['fromClubId'],e['toClubId'],e['year']) for e in events.values())
    events = [e for e in events.values() if clue_counts[(e['fromClubId'],e['toClubId'],e['year'])] == 1]
    # Any V4 player (not only puzzle-eligible ones) who made the same move in the
    # same year is a correct answer too: the screen shows only clubs and year.
    movers = defaultdict(set)
    for r in con.execute('select player_id,from_club_id,to_club_id,transfer_year from transfers'):
        movers[(cid(r['from_club_id']),cid(r['to_club_id']),r['transfer_year'])].add(r['player_id'])
    profiles = {r['player_id']: r for r in con.execute(
        "select * from profiles where identity_confidence like 'HIGH%'")}
    for e in events:
        also = sorted(movers[(e['fromClubId'],e['toClubId'],e['year'])] - {e['playerId']})
        if also: e['alsoPlayerIds'] = also
        rank = players[e['playerId']]['rank']
        e['difficulty'] = 'easy' if rank <= 800 else 'medium' if rank <= 2500 else 'hard'
        pr = profiles.get(e['playerId'])
        if pr and pr['birth_year'] and 15 <= e['year'] - pr['birth_year'] <= 45:
            e['age'] = e['year'] - pr['birth_year']
        if pr and pr['detailed_position']: e['detailedPosition'] = pr['detailed_position']
    result = dict(schema=1, databaseSha256=hashlib.sha256(DB.read_bytes()).hexdigest(),
        careers=puzzles, transfers=sorted(events,key=lambda e:e['id']), clubs=list(clubs.values()),
        quality=dict(careers=dict(Counter(p['difficulty'] for p in puzzles)), transfers=len(events),
                     transferLevels=dict(Counter(e['difficulty'] for e in events)),
                     sharedTransfers=sum(1 for e in events if 'alsoPlayerIds' in e),
                     rejected=dict(rejected)))
    result['version'] = 'ct-v1-' + hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest()[:16]
    assert all(result['quality']['careers'].get(d,0) >= 20 for d in ['beginner','normal','legend'])
    assert len(events) >= 100
    return result

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data=build(); encoded=json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
    if args.check:
        assert OUT.read_text(encoding='utf-8') == encoded, 'Catalog drift'
    else: OUT.write_text(encoded,encoding='utf-8')
    print(json.dumps(data['quality'],ensure_ascii=False))
