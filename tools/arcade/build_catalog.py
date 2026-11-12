#!/usr/bin/env python3
"""Deterministic positive-edge V4 catalog; negative evidence ONLY reviewed complete careers."""
import sys, collections, hashlib, itertools, json, pathlib, random, sqlite3, unicodedata
ROOT = pathlib.Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
rng = random.Random(418310)
def key(s):
    s = s.translate(str.maketrans({'ı':'i','İ':'i','ß':'ss','æ':'ae','œ':'oe','ø':'o','ł':'l','đ':'d','ð':'d'}))
    return ''.join(x for x in unicodedata.normalize('NFKD', s.lower()) if x.isalnum())
c = sqlite3.connect(DB); c.row_factory = sqlite3.Row
rawclubs = {r['id']: dict(r) for r in c.execute('select * from clubs')}
# TM ids that collide with a different club keep their own id (reviewed list).
OFFSET_MISMATCH = {x['id'] for x in __import__('json').loads((__import__('pathlib').Path(__file__).resolve().parents[2] / 'tools/data_platform_v4/club_offset_mismatch.json').read_text(encoding='utf-8'))['ids']}
def cid(i): return i-1000000000 if i >= 1000000000 and i not in OFFSET_MISMATCH and i-1000000000 in rawclubs else i
clubs = {str(cid(i)): {'id':str(cid(i)), 'name':r['name'], 'badgeKey':r['badge_key'], 'popularity':r['popularity_seed'] or 0} for i,r in rawclubs.items() if cid(i)==i and r['entity_type']=='SENIOR' and r['gameplay_eligible']}
links = collections.defaultdict(set)
for r in c.execute('select * from player_clubs where trust>=2'):
    if str(cid(r['club_id'])) in clubs: links[str(r['player_id'])].add(str(cid(r['club_id'])))
# Every canonical senior club a player had (all trust levels, after the club-id
# collision fix): a Burst answer is judged by these, so a real answer is not wrong.
every_link = collections.defaultdict(set)
for r in c.execute('select player_id, club_id from player_clubs'):
    if str(cid(r['club_id'])) in clubs: every_link[str(r['player_id'])].add(str(cid(r['club_id'])))
import gzip
_pv = json.loads(gzip.decompress((ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))
known_rating = {k: v['rating'] for k, v in _pv['players'].items()}
KNOWN_CLUBS = {k.split(':')[1] for k in _pv['gridClubs'] + _pv['clubOptions']}
players = {}
for r in c.execute('select * from players where answer_eligible=1'):
    i = str(r['id'])
    # The answer pool: players with reviewed links, and every player rated 60+.
    if not every_link[i] or (not links[i] and known_rating.get(i, 0) < 60): continue
    country = (r['country'] or '').strip()
    aliases={'turkiye':'Turkey','turkey':'Turkey','czechia':'Czech Republic','czechrepublic':'Czech Republic',
      'unitedstates':'USA','unitedstatesofamerica':'USA','usa':'USA','korearepublic':'South Korea',
      'koreasouth':'South Korea','southkorea':'South Korea','cotedivoire':"Côte d'Ivoire",'ivorycoast':"Côte d'Ivoire",
      'bosniaherzegovina':'Bosnia and Herzegovina','holland':'Netherlands','thenetherlands':'Netherlands'}
    country=aliases.get(key(country),country)
    if key(country) in {'unknown','na','none','korea'}:country=''
    players[i] = {'id':i,'name':r['name'],'country':country, 'countryId':key(country), 'clubs':sorted(every_link[i]), 'rank':r['selection_rank'] or 999999, 'avatarKey':r['avatar_key'] or '', 'aliases':[]}
for r in c.execute('select * from player_aliases'):
    if str(r['player_id']) in players: players[str(r['player_id'])]['aliases'].append(r['alias'])
# Query labels can collide; resolved IDs still work. A puzzle needs >=6 uniquely named answers.
# A name counts as unique only if no other player's name or alias reads the same.
labels = collections.Counter(k for p in players.values() for k in {key(p['name']), *(key(x) for x in p['aliases'])})
# Burst asks about the 90 known clubs only (no youth side, no Raith Rovers), and countries
# with two or more players rated 75+. Levels follow how known the third-best answer is
# (gameplay rating): 84+ easy, 81+ normal, 78+ hard, the rest legend.
nations = collections.Counter(p['countryId'] for i, p in players.items() if known_rating.get(i, 0) >= 75)
pairs = collections.defaultdict(list)
for i,p in players.items():
    if labels[key(p['name'])] != 1: continue
    mine = [k for k in p['clubs'] if k in KNOWN_CLUBS]
    for a,b in itertools.combinations(mine,2): pairs['clubClub:'+a+':'+b].append(i)
    if p['countryId'] and p['countryId'] not in {'unknown','na','none'} and nations[p['countryId']] >= 2:
        for a in mine: pairs['clubCountry:'+a+':'+p['countryId']].append(i)
burst = []
for k,ids in sorted(pairs.items()):
    if len(ids)<6: continue
    typ,a,b=k.split(':'); third=sorted((known_rating.get(i, 0) for i in ids), reverse=True)[2]
    tier = 'easy' if third>=84 else 'normal' if third>=81 else 'hard' if third>=78 else 'legend'
    burst.append({'id':k,'pairType':typ,'left':clubs[a]['name'],'right':clubs[b]['name'] if typ=='clubClub' else players[ids[0]]['country'], 'answers':sorted(ids),'difficulty':tier})
# Matching: include all uncertain career links as exclusions, never infer completeness.
fc = json.loads((ROOT/'functions/config/fake_club_catalog.json').read_text())
careers=[]
for p in fc['careers']:
    i=str(p['playerId'])
    if i not in players or p['coverage']!='REVIEWED_COMPLETE_RETIRED': continue
    careers.append({'playerId':i,'clubs':[str(x) for x in p['seniorClubIds'] if str(x) in clubs], 'excluded':[str(x) for x in p['excludedClubIds']], 'sources':p['sources'], 'reviewedAt':p['reviewedAt'], 'coverage':p['coverage']})
# Pyramid. Answers: every known player (gameplay rating 68+, the online modes'
# scale; the selection rank misses many stars), every senior club he played for
# and his country (English name shown for the flag, Turkish name accepted:
# "Arjantin"). Links are computed by the server from these entities. Boards are
# built from a smaller, better-known core per level, so Kolay never puts Miami FC
# at the top: easy uses rating 80+ players, the 50 grid clubs and countries;
# normal 76+ and the 90 known clubs; hard 72+ with the same clubs, the tighter half.
import gzip
spec = __import__('importlib.util').util.spec_from_file_location('mc', ROOT / 'tools/mystery_chain/build_catalog.py')
mc = __import__('importlib.util').util.module_from_spec(spec); spec.loader.exec_module(mc)
COUNTRY_TR = {key(k): v for k, v in mc.COUNTRY_TR.items()}
COUNTRY_TR.update({'turkey': 'Türkiye', 'usa': 'ABD', 'southkorea': 'Güney Kore',
                   'bosniaandherzegovina': 'Bosna-Hersek', 'cotedivoire': 'Fildişi Sahili'})
pv = json.loads(gzip.decompress((ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))
rating = {k: v['rating'] for k, v in pv['players'].items()}
GRID = {k.split(':')[1] for k in pv['gridClubs']}
KNOWN = GRID | {k.split(':')[1] for k in pv['clubOptions']}
ANSWER_RATING = 68
all_links = collections.defaultdict(set)
for r in c.execute('select player_id, club_id from player_clubs'):
    k = str(cid(r['club_id']))
    if k in clubs: all_links[str(r['player_id'])].add(k)
legends = {p['playerId'] for p in careers}
pool = []
for r in c.execute('select * from players where answer_eligible=1'):
    i = str(r['id'])
    if not all_links[i] or (rating.get(i, 0) < ANSWER_RATING and i not in legends): continue
    base = players.get(i)
    country = base['country'] if base else ''
    if not base:
        raw = (r['country'] or '').strip(); country = {'turkiye': 'Turkey', 'czechia': 'Czech Republic',
            'unitedstates': 'USA', 'korearepublic': 'South Korea', 'holland': 'Netherlands'}.get(key(raw), raw)
        if key(country) in {'unknown', 'na', 'none', 'korea'}: country = ''
    pool.append({'id': i, 'name': r['name'], 'country': country, 'countryId': key(country),
                 'clubs': sorted(all_links[i]), 'rating': rating.get(i, 0),
                 'aliases': sorted({a for (a,) in c.execute('select alias from player_aliases where player_id=?', (r['id'],))})})
pool.sort(key=lambda p: (-p['rating'], p['id']))
entities = {}
for n, p in enumerate(pool):
    entities['p' + p['id']] = {'id': 'p' + p['id'], 'type': 'player', 'name': p['name'], 'playerId': p['id'],
                               'clubs': p['clubs'], 'countryId': p['countryId'], 'rank': n + 1,
                               **({'aliases': p['aliases']} if p['aliases'] else {})}
club_fans = collections.Counter(k for p in pool for k in p['clubs'])
for k in sorted(club_fans, key=lambda k: (-(clubs[k]['popularity'] or 0), k)):
    entities['c' + k] = {'id': 'c' + k, 'type': 'club', 'name': clubs[k]['name'], 'clubs': [k],
                         'rank': 100000 + len(entities)}
for p in pool:
    if p['countryId'] and 'n' + p['countryId'] not in entities:
        tr = COUNTRY_TR.get(p['countryId'])
        entities['n' + p['countryId']] = {'id': 'n' + p['countryId'], 'type': 'country', 'name': p['country'],
                                          'countryId': p['countryId'], 'clubs': [], 'rank': 50000 + len(entities),
                                          **({'aliases': [tr]} if tr and key(tr) != p['countryId'] else {})}
def evidence(a, b):
    if a['type'] == 'player' and b['type'] == 'player':
        shared = sorted(set(a['clubs']) & set(b['clubs']))
        return {'type': 'sharedClub', 'clubId': shared[0]} if shared else None
    if b['type'] == 'player': a, b = b, a
    if a['type'] != 'player': return None
    if b['type'] == 'club' and b['clubs'][0] in a['clubs']: return {'type': 'seniorClub', 'clubId': b['clubs'][0]}
    if b['type'] == 'country' and a['countryId'] == b['countryId']: return {'type': 'nationality', 'countryId': b['countryId']}
    return None
# Adjacency over every answer, from club and country indexes (the server does the same).
by_club = collections.defaultdict(set); by_country = collections.defaultdict(set)
for e in entities.values():
    if e['type'] == 'player':
        for k in e['clubs']: by_club[k].add(e['id'])
        if e['countryId']: by_country[e['countryId']].add(e['id'])
adj = {}
for i, e in entities.items():
    if e['type'] == 'player':
        s = set().union(*(by_club[k] for k in e['clubs'])) | {'c' + k for k in e['clubs'] if 'c' + k in entities}
        if e['countryId'] and 'n' + e['countryId'] in entities: s.add('n' + e['countryId'])
    elif e['type'] == 'club': s = set(by_club[e['clubs'][0]])
    else: s = set(by_country[e['countryId']])
    s.discard(i); adj[i] = s
edge_of = lambda a, b: evidence(entities[a], entities[b])
LEVELS = {'easy': (80, GRID), 'normal': (76, KNOWN), 'hard': (72, KNOWN)}
def core(level):
    least, known_clubs = LEVELS[level]
    ids = {i for i, e in entities.items() if e['type'] == 'player' and rating.get(e['playerId'], 0) >= least}
    ids |= {'c' + k for k in known_clubs if 'c' + k in entities}
    ids |= {i for i, e in entities.items() if e['type'] == 'country' and
            sum(1 for p in by_country[e['countryId']] if p in ids) >= 3}
    return ids
uses = collections.Counter(); USE_CAP = 4
def full_board(n, allowed, level):
    """All slots top-down, each child linked to its one/two parents, inside the level's core."""
    tops = sorted(i for i in allowed if level != 'easy' or entities[i]['type'] != 'player')
    for attempt in range(800):
        chosen = [rng.choice(tops)]; rows = [[chosen[0]]]; ok = True
        for row in range(1, n):
            current = []
            for col in range(row + 1):
                parents = rows[-1][max(0, col - 1):min(col + 1, row)]
                choices = set.intersection(*(adj[p] for p in parents)) & allowed - set(chosen)
                if not choices: ok = False; break
                options = sorted(choices); rng.shuffle(options)
                mixed = rng.random() < 0.35
                options.sort(key=lambda x: (uses[x] >= USE_CAP, mixed and entities[x]['type'] == 'player'))
                value = options[0]; chosen.append(value); current.append(value)
            if not ok: break
            rows.append(current)
        if not ok: continue
        common = set(entities[chosen[0]]['clubs'])
        for i in chosen[1:]: common &= set(entities[i]['clubs'])
        witnesses = set()
        for r in range(n - 1):
            for j, a in enumerate(rows[r]):
                for b in rows[r + 1][j:j + 2]:
                    ev = edge_of(a, b); witnesses.add(ev.get('clubId', 'n:' + ev.get('countryId', '')))
        interior = [i for row in rows[1:-1] for i in row]
        interior_common = set(entities[interior[0]]['clubs'])
        for i in interior[1:]: interior_common &= set(entities[i]['clubs'])
        if common or interior_common or len(witnesses) < 3: continue
        return rows
    raise RuntimeError('No diverse certified triangle within budget')
def board(level, n, number, rows):
    uses.update(x for row in rows for x in row); slots = []; solution = {}; initial = {}; i = 0
    for r, row in enumerate(rows):
        for j, entity in enumerate(row):
            slots.append({'id': str(i), 'row': r, 'column': j,
                          'supports': [str((r + 1) * (r + 2) // 2 + j), str((r + 1) * (r + 2) // 2 + j + 1)] if r < n - 1 else []})
            solution[str(i)] = entity
            if r in [0, n - 1]: initial[str(i)] = entity
            i += 1
    return {'id': f'pyramid:{level}:{number}', 'difficulty': level, 'levels': n, 'slots': slots,
            'initial': initial, 'certificate': solution}
def looseness(b):
    """Mean number of answers that link every required neighbour of an empty
    cell (given the certified neighbours): fewer candidates, harder cell."""
    cert = b['certificate']; counts = []
    for s in b['slots']:
        if s['id'] in b['initial'] or not s['supports']: continue
        need = [cert[x] for x in s['supports']] + ([cert['0']] if s['row'] == 1 else [])
        counts.append(len(set.intersection(*(adj[x] for x in need))))
    return sum(counts) / len(counts)
def complexity(b):
    ids = list(b['certificate'].values())
    witness = {json.dumps(edge_of(b['certificate'][s['id']], b['certificate'][n]), sort_keys=True)
               for s in b['slots'] for n in s['supports']}
    return len(witness) * 100 - sum(len(adj[i]) for i in ids) / len(ids)
boards = []
easy_core, normal_core, hard_core = core('easy'), core('normal'), core('hard')
for number in range(50):
    boards.append(board('easy', 4, number + 1, full_board(4, easy_core, 'easy')))
for number in range(50):
    boards.append(board('normal', 5, number + 1, full_board(5, normal_core, 'normal')))
# Hard: the tighter half of 100 boards built from the wider core.
hard = [board('hard', 5, 0, full_board(5, hard_core, 'hard')) for _ in range(100)]
hard.sort(key=lambda b: (looseness(b), json.dumps(b['certificate'], sort_keys=True)))
for number, b in enumerate(hard[:50]):
    b['id'] = f'pyramid:hard:{number + 1}'; boards.append(b)
for b in boards:
    b['looseness'] = round(looseness(b), 2)
    if b['levels'] == 5: b['complexity'] = round(complexity(b), 2)
# Matching: a known player and a known club he played for. A board must have
# exactly one right club per player, so every club he ever played for (all
# canonical senior player_clubs rows) is kept to rule out a second match. Levels
# follow the Pyramid's: easy 80+ with the 50 grid clubs, normal 76+ and hard 72+
# with the 90 known clubs. Same-named players are left out (the card shows a name).
# Time at each club (career spells; an open spell counts at most a year, as
# open ends are often stale): a card shows a club he is known for. Easy: his
# longest stay or three years at a grid club; normal: a year or one of his two
# longest; hard: any known club (Alaba is Bayern's and Real Madrid's before Udinese's).
from datetime import date as _date
tenure = collections.defaultdict(collections.Counter)
for r in c.execute('select player_id, club_id, start_date, end_date from career_spells where start_date is not null'):
    try:
        a_ = _date.fromisoformat(r['start_date'][:10])
        days = (_date.fromisoformat(r['end_date'][:10]) - a_).days if r['end_date'] else             min(365, (_date(2026, 11, 1) - a_).days)
    except ValueError: continue
    tenure[str(r['player_id'])][str(cid(r['club_id']))] += max(0, days)
def longest(i, n):
    stays = tenure.get(i, {})
    return {k for k, _ in sorted(stays.items(), key=lambda kv: (-kv[1], kv[0]))[:n]}
matching = []; matching_clubs = {}
for i, p in players.items():
    if labels[key(p['name'])] != 1 or i not in all_links: continue
    r = rating.get(i, 0)
    level = 'easy' if r >= 80 else 'normal' if r >= 76 else 'hard' if r >= 72 else None
    if not level: continue
    top1, top2, days = longest(i, 1), longest(i, 2), tenure.get(i, {})
    for k in sorted(all_links[i]):
        if k not in KNOWN: continue
        tier = level
        # A level is kept only for a club he is known for; otherwise the pair drops a level.
        if tier == 'easy' and not (k in GRID and (k in top1 or days.get(k, 0) >= 3 * 365)): tier = 'normal'
        if tier == 'normal' and not (k in top2 or days.get(k, 0) >= 365): tier = 'hard'
        matching.append({'playerId': i, 'clubId': k, 'tier': tier})
        matching_clubs[i] = sorted(all_links[i])
catalog={'schema':1,'databaseSha256':hashlib.sha256(DB.read_bytes()).hexdigest(),'players':players,'clubs':clubs,'burst':burst,'careers':careers,'entities':entities,'pyramids':boards,'matching':matching,'matchingClubs':matching_clubs,'policy':{'matchingPairs':{'easy':8,'normal':8,'hard':8},'stars':{'threePerPair':1.75,'twoPerPair':2.5,'calibration':'tightened from 2/3 pairs: perfect-memory play needs about 1.6 moves per pair; recalibrate with device telemetry'},'maxPickAttempts':40}}
body=json.dumps(catalog,ensure_ascii=False,sort_keys=True,separators=(',',':'))
catalog['version']='arcade-v1-'+hashlib.sha256(body.encode()).hexdigest()[:16]
out=ROOT/'functions/config/arcade_catalog.json'; text=json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n'
if '--check' in sys.argv:
    assert out.read_text()==text, 'Arcade catalog drift; run tools/arcade/build_catalog.py'
else: out.write_text(text,encoding='utf-8',newline=chr(10))
print(json.dumps({'version':catalog['version'],'players':len(players),'burst':len(burst),'burstTiers':dict(collections.Counter(x['pairType']+'/'+x['difficulty'] for x in burst)),'completeCareers':len(careers),'pyramidEntities':len(entities),'pyramidBoards':len(boards),'pyramidLooseness':{d:round(sum(b['looseness'] for b in boards if b['difficulty']==d)/max(1,sum(b['difficulty']==d for b in boards)),1) for d in ['easy','normal','hard']},'maxEntityBoards':max(uses.values()),'bytes':out.stat().st_size},indent=2))
