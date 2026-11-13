"""Deterministic, conservative V4 export. Never invent dates, fees or loan types."""
import argparse
from collections import Counter, defaultdict
import gzip
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
    # Career levels: how known the player (the online modes' gameplay rating) and his
    # clubs (the 50 grid and 90 known clubs) are. beginner: 82+, three in five cards at
    # known clubs, up to six cards; normal: 77+, two in five; legend: 72+. Below that a
    # career is `obscure`: kept for the archive, never asked.
    pv = json.loads(gzip.decompress((ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))
    rating = {int(k): v['rating'] for k, v in pv['players'].items()}
    known_clubs = {int(k.split(':')[1]) for k in pv['gridClubs'] + pv['clubOptions']}
    def days(s):
        return (date.fromisoformat(s['end']) - date.fromisoformat(s['start'])).days if s['end'] else 10**6
    puzzles = []
    for pid, stops in sorted(careers.items()):
        stops = list({s['id']: s for s in stops}.values())
        if any(a['start'] == b['start'] or a['end'] is None or a['end'] > b['start']
               for a,b in zip(stops, stops[1:])):
            rejected['overlapping_career'] += 1; continue
        # Loans are not career moves: spells of three years or less between two spells
        # at the same club go (Martínez's Sheffield Wednesday, Wolves, Getafe, Reading).
        changed = True
        while changed:
            changed = False
            cards = []
            for s in stops:
                if cards and cards[-1][-1]['clubId'] == s['clubId']: cards[-1].append(s)
                else: cards.append([s])
            # One loan or a chain of them (Palermo -> Cremonese -> Ancona -> Palermo):
            # every spell between two spells at one club, three years or less in all.
            for i in range(len(cards)):
                j = next((j for j in range(i + 2, len(cards)) if cards[j][0]['clubId'] == cards[i][0]['clubId']), None)
                if j is not None and sum(days(s) for c in cards[i + 1:j] for s in c) <= 1100:
                    drop = {s['id'] for c in cards[i + 1:j] for s in c}
                    stops = [s for s in stops if s['id'] not in drop]
                    rejected['loan_spells'] += len(drop); changed = True; break
        cards = []
        for s in stops:
            if not cards or cards[-1] != s['clubId']: cards.append(s['clubId'])
        if len(cards) < 3: continue
        r = rating.get(pid, 0); share = sum(1 for k in cards if k in known_clubs) / len(cards)
        difficulty = 'beginner' if r >= 82 and share >= .6 and len(cards) <= 6 else \
            'normal' if r >= 77 and share >= .4 else 'legend'
        puzzles.append(dict(id=str(pid), playerId=pid, difficulty=difficulty, stops=stops[:12],
            **({'obscure': True} if r < 72 else {}),
            source='V4 career_spells: HIGH / REVIEWED_YEAR / REVIEWED_SEASON; selected periods'))
    # Loans: the database has no loan flag, but a loan leaves a trace. A return to the
    # club he just left, dated at a season's end (30 June, 31 May, 31 December, as
    # Transfermarkt books loan ends) within three years, is a loan's end, and the move
    # before it the loan (De Bruyne Chelsea -> Werder 2012 and back 2013). A buy after a
    # loan (Salah Chelsea -> Roma 2016) or a move later loaned back (Lukaku Inter ->
    # Chelsea 2021) is not a return and stays a transfer. Loans recalled mid-season
    # (Coquelin at Charlton) are missed.
    loans, moves = set(), defaultdict(list)
    for r in con.execute('select event_id,player_id,transfer_date,from_club_id,to_club_id from transfers '
                         'where transfer_date is not null order by player_id,transfer_date,event_id'):
        moves[r['player_id']].append((r['transfer_date'], cid(r['from_club_id']), cid(r['to_club_id']), r['event_id']))
    for history in moves.values():
        for (d1, a1, b1, e1), (d2, a2, b2, e2) in zip(history, history[1:]):
            if a1 == b2 and b1 == a2 and a1 != b1 and d2[5:] in ('06-30', '05-31', '12-31') and                     valid_date(d1) and valid_date(d2) and 0 < (date.fromisoformat(d2) - date.fromisoformat(d1)).days <= 1100:
                loans.update((e1, e2))
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
            **({'precision': 'season'} if r['trust'] == 'REVIEWED_SEASON' else {}),
            **({'loan': True} if r['event_id'] in loans else {}))
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
    # Solo levels: how known the player (the online modes' gameplay rating) and both clubs
    # are (the 50 grid clubs and the 90 known ones). easy: 82+ between two grid clubs,
    # 2008 on; medium: 78+, a grid club and a known one, 2003 on; hard: 74+ between two
    # known clubs, or a star (80+) with one known club. Anything else, and a reserve side's promotion (Barcelona Atlètic ->
    # Barcelona), is `obscure`: kept for the archive, never asked.
    pv = json.loads(gzip.decompress((ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))
    rating = {int(k): v['rating'] for k, v in pv['players'].items()}
    best = {int(k.split(':')[1]) for k in pv['gridClubs']}
    known = best | {int(k.split(':')[1]) for k in pv['clubOptions']}
    reserve_words = (' b', ' ii', ' u19', ' u21', ' u23', 'atlètic', 'atletic', 'castilla', 'youth', 'reserves',
                     'jong ', 'primavera', ' b team', 'promesas')
    def reserve(a, b):
        x, y = clubs[a]['name'].lower(), clubs[b]['name'].lower()
        short, long_ = sorted((x, y), key=len)
        return short.split(' ')[0] in long_ and (short in long_ or any(w in long_ for w in reserve_words))
    for e in events:
        also = sorted(movers[(e['fromClubId'],e['toClubId'],e['year'])] - {e['playerId']})
        if also: e['alsoPlayerIds'] = also
        r, a, b, y = rating.get(e['playerId'], 0), e['fromClubId'], e['toClubId'], e['year']
        if reserve(a, b): level = None
        elif r >= 82 and a in best and b in best and y >= 2008: level = 'easy'
        elif r >= 78 and y >= 2003 and (a in best or b in best) and a in known and b in known: level = 'medium'
        elif r >= 74 and a in known and b in known or r >= 80 and (a in known or b in known): level = 'hard'
        else: level = None
        e['difficulty'] = level or 'hard'
        if level is None: e['obscure'] = True
        pr = profiles.get(e['playerId'])
        if pr and pr['birth_year'] and 15 <= e['year'] - pr['birth_year'] <= 45:
            e['age'] = e['year'] - pr['birth_year']
        if pr and pr['detailed_position']: e['detailedPosition'] = pr['detailed_position']
    result = dict(schema=1, databaseSha256=hashlib.sha256(DB.read_bytes()).hexdigest(),
        careers=puzzles, transfers=sorted(events,key=lambda e:e['id']), clubs=list(clubs.values()),
        quality=dict(careers=dict(Counter(p['difficulty'] for p in puzzles)), transfers=len(events),
                     transferLevels=dict(Counter(e['difficulty'] for e in events)),
                     sharedTransfers=sum(1 for e in events if 'alsoPlayerIds' in e),
                     loans=sum(1 for e in events if e.get('loan')),
                     askedLevels=dict(Counter(e['difficulty'] for e in events if not e.get('loan') and not e.get('obscure'))),
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
    else: OUT.write_text(encoded,encoding='utf-8',newline='\n')
    print(json.dumps(data['quality'],ensure_ascii=False))
