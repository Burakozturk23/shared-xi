"""Conservative dated V4 clues and exact club graph; deterministic offline export."""
import argparse
from collections import Counter, defaultdict, deque
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'functions/config/mystery_chain_catalog.json'
# Shown on the card next to the Turkish position, so the clue reads in one language.
COUNTRY_TR = {
    'Algeria': 'Cezayir', 'Argentina': 'Arjantin', 'Austria': 'Avusturya', 'Belgium': 'Belçika',
    'Brazil': 'Brezilya', 'Cameroon': 'Kamerun', 'Colombia': 'Kolombiya', "Cote d'Ivoire": 'Fildişi Sahili',
    'Croatia': 'Hırvatistan', 'DR Congo': 'Kongo DC', 'Denmark': 'Danimarka', 'England': 'İngiltere',
    'France': 'Fransa', 'Germany': 'Almanya', 'Ghana': 'Gana', 'Greece': 'Yunanistan', 'Italy': 'İtalya',
    'Japan': 'Japonya', 'Mexico': 'Meksika', 'Morocco': 'Fas', 'Netherlands': 'Hollanda', 'Nigeria': 'Nijerya',
    'Norway': 'Norveç', 'Poland': 'Polonya', 'Portugal': 'Portekiz', 'Russia': 'Rusya', 'Scotland': 'İskoçya',
    'Senegal': 'Senegal', 'Serbia': 'Sırbistan', 'Slovakia': 'Slovakya', 'Spain': 'İspanya', 'Sweden': 'İsveç',
    'Switzerland': 'İsviçre', 'Türkiye': 'Türkiye', 'Ukraine': 'Ukrayna', 'Uruguay': 'Uruguay',
    'Wales': 'Galler', 'United States': 'ABD', 'Chile': 'Şili', 'Ireland': 'İrlanda', 'Egypt': 'Mısır',
    'Czech Republic': 'Çekya', 'Mali': 'Mali', 'Ecuador': 'Ekvador', 'Paraguay': 'Paraguay',
    'Peru': 'Peru', 'Venezuela': 'Venezuela', 'Korea, South': 'Güney Kore', 'Australia': 'Avustralya',
    'Bosnia-Herzegovina': 'Bosna-Hersek', 'Slovenia': 'Slovenya', 'Hungary': 'Macaristan', 'Romania': 'Romanya',
    'Bulgaria': 'Bulgaristan', 'Albania': 'Arnavutluk', 'Georgia': 'Gürcistan', 'Iceland': 'İzlanda',
    'Finland': 'Finlandiya', 'Tunisia': 'Tunus', 'Gabon': 'Gabon', 'Guinea': 'Gine', 'Montenegro': 'Karadağ',
    'North Macedonia': 'Kuzey Makedonya', 'Kosovo': 'Kosova', 'Israel': 'İsrail', 'Iran': 'İran',
    'Canada': 'Kanada', 'Costa Rica': 'Kosta Rika', 'Jamaica': 'Jamaika', 'Burkina Faso': 'Burkina Faso',
}
FOOT_TR = {'right': 'sağ ayaklı', 'left': 'sol ayaklı', 'both': 'iki ayağını da kullanıyor'}

def build():
    ct = json.loads((ROOT/'functions/config/career_transfer_catalog.json').read_text())
    people = json.loads((ROOT/'functions/config/three_modes_catalog.json').read_text())['players']
    players = {p['id']: p for p in people}
    clubs = {c['id']: dict(c) for c in ct['clubs']}
    con = sqlite3.connect(f"file:{ROOT/'assets/runtime/linkball_game_data_v4.sqlite'}?mode=ro", uri=True)
    countries = dict(con.execute('select id, country from clubs'))
    seeds = dict(con.execute('select id, popularity_seed from clubs'))
    names = defaultdict(list)
    for c in clubs.values(): names[c['name']].append(c['id'])
    # The best-known club keeps its plain name; the others get their country.
    plain = {max(ids, key=lambda i: (seeds.get(i) or 0, -i)) for ids in names.values()}
    for c in clubs.values():
        if len(names[c['name']]) > 1 and c['id'] not in plain and countries.get(c['id']):
            c['name'] = f"{c['name']} ({COUNTRY_TR.get(countries[c['id']], countries[c['id']])})"
    popular = {i for i, in con.execute('select id from clubs where popularity_seed >= 10 and entity_type="SENIOR" and gameplay_eligible=1')}
    positions = {'GK': 'Kaleci', 'DEF': 'Defans', 'MID': 'Orta saha', 'FWD': 'Forvet'}
    raw_ids = {i for i, in con.execute('select id from clubs')}
    cid = lambda i: i - 1000000000 if i >= 1000000000 and i - 1000000000 in raw_ids else i
    # Every V4 club record of a player, dated or not: a looser match than the
    # puzzle data, so more possible answers are accepted rather than fewer.
    spells = defaultdict(set)
    for pid, club in con.execute('select player_id, club_id from career_spells'):
        spells[pid].add(cid(club))
    for pid, a, b in con.execute('select player_id, from_club_id, to_club_id from transfers'):
        spells[pid].update((cid(a), cid(b)))
    for p in people: spells[p['id']].update(p['clubs'])
    profiles = {r[0]: r for r in con.execute(
        "select player_id,height_cm,foot,international_caps from profiles where identity_confidence like 'HIGH%'")}
    groups = defaultdict(list); groups_all = defaultdict(list)
    for p in people:
        if p['rank'] <= 5000: groups[(p['country'],p['position'])].append(p['id'])
        groups_all[(p['country'],p['position'])].append(p['id'])
    mystery = []
    for career in ct['careers']:
        p = players[career['playerId']]
        stops = list({s['clubId']: s for s in career['stops']}.values())
        if len(stops) < 3 or len(groups[(p['country'],p['position'])]) < 4: continue
        a,b,c = stops[:3]
        options = [p['id']] + [i for i in groups[(p['country'],p['position'])]
            if i != p['id'] and len(players[i]['clubs']) >= 2 and a['clubId'] not in players[i]['clubs']]
        if len(options) < 4: continue
        # Teammates require exact known dates in both records and a non-empty overlap.
        teammate = None
        for other in ct['careers']:
            if other['playerId'] == p['id']: continue
            for x in career['stops']:
                for y in other['stops']:
                    if x['clubId'] == y['clubId'] and x['precision'] == y['precision'] == 'date' and x['end'] and y['end']:
                        start,end = max(x['start'],y['start']),min(x['end'],y['end'])
                        if start < end:
                            teammate = dict(id='teammate',text=f"{players[other['playerId']]['name']} ile {clubs[x['clubId']]['name']} kadrosunda aynı dönemdeydi ({start} – {end}).", playerId=other['playerId'],clubId=x['clubId'],start=start,end=end)
                            break
                if teammate: break
            if teammate: break
        hints = [dict(id='club_'+str(a['clubId']),text='Oynadığı kulüp: '+clubs[a['clubId']]['name']),
                 dict(id='period',text=f"Seçili kariyer dönemi: {b['start'][:4]} – {b['end'][:4] if b['end'] else 'devam'}"),
                 dict(id='club_'+str(b['clubId']),text='Bir başka kulübü: '+clubs[b['clubId']]['name']),
                 teammate or dict(id='club_'+str(c['clubId']),text=f"{clubs[c['clubId']]['name']} kariyeri {c['start'][:4]} yılında başladı."),
                 dict(id='letter',text='Adının ilk harfi: '+next(ch for ch in p['name'] if ch.isalpha()))]
        # Layout 2: the first club is on the card from the start, the period
        # names its club, and the profile is a third optional clue.
        pr = profiles.get(p['id'])
        bits = [f"{pr[1]} cm" if pr and pr[1] else None, FOOT_TR.get(pr[2]) if pr else None,
                # V4 stores unknown caps as 0, so only a positive count is a clue.
                f"{pr[3]} milli maç" if pr and pr[3] else None]
        profile = dict(id='profile', text='Profil: ' + ' · '.join(b for b in bits if b)) if any(bits) else None
        third = teammate
        if not third and len(stops) > 3:
            d = stops[3]
            third = dict(id='club_'+str(d['clubId']), text='Bir başka kulübü daha: '+clubs[d['clubId']]['name'])
        if not third:
            third = dict(id='club_'+str(c['clubId'])+'_year',
                         text=f"{clubs[c['clubId']]['name']} kariyeri {c['start'][:4]} yılında başladı.")
        hints2 = [dict(id='club_'+str(a['clubId']), text='Oynadığı kulüp: '+clubs[a['clubId']]['name']),
                  dict(id='period', text=f"Bir dönemi: {clubs[b['clubId']]['name']}, "
                       f"{b['start'][:4]} – {b['end'][:4] if b['end'] else 'devam'}"),
                  dict(id='club_'+str(c['clubId']), text='Bir başka kulübü: '+clubs[c['clubId']]['name']),
                  third] + ([profile] if profile else []) + [hints[4]]
        # Same nationality, position and these three clubs: also a right answer.
        shown = {a['clubId'], b['clubId'], c['clubId']}
        also = sorted(i for i in groups_all[(p['country'], p['position'])]
                      if i != p['id'] and shown <= spells[i])
        rank = p['rank']
        entry = dict(id=str(p['id']),playerId=p['id'],country=p['country'],
            countryLabel=COUNTRY_TR.get(p['country'], p['country']),position=positions[p['position']],
            hints=hints2,layout=2,optional=list(range(3, len(hints2))),
            difficulty='easy' if rank <= 300 else 'medium' if rank <= 1500 else 'hard',
            options=options,onlineClubId=a['clubId'],source=career['source'])
        if also: entry['alsoPlayerIds'] = also
        mystery.append(entry)
    memberships = []
    for p in ct['careers']:
        ids = sorted({s['clubId'] for s in p['stops']} & popular)
        if len(ids) >= 2: memberships.append(dict(id=p['playerId'],clubs=ids,player={k:players[p['playerId']][k] for k in ('id','name','country','position','rank','search')}))
    adjacency = defaultdict(dict)
    for p in memberships:
        for a in p['clubs']:
            for b in p['clubs']:
                if a != b: adjacency[a].setdefault(b,p['id'])
    pairs = defaultdict(list)
    for start in sorted(adjacency):
        paths = {start: []}; queue = deque([start])
        while queue:
            at = queue.popleft()
            if len(paths[at]) == 4: continue
            for to,pid in sorted(adjacency[at].items()):
                if to in paths: continue
                paths[to] = paths[at] + [dict(playerId=pid,clubId=to)]
                queue.append(to)
        for target,path in sorted(paths.items()):
            if target <= start or not path: continue
            assert len({x['playerId'] for x in path}) == len(path)
            pairs[len(path)].append(dict(id=f'{start}_{target}',start=start,target=target,par=len(path),solution=path))
    # Stable hash sampling avoids alphabetical/club-ID bias; all catalog paths retain exact PAR.
    # Pair quality: both ends need several connecting players, a PAR-1 pair
    # more than one shared player and a PAR-2 pair more than one route, so the
    # puzzle tests football knowledge instead of one obscure link. The bar is
    # lowered step by step only when a PAR level would otherwise run short.
    deg = Counter(c for p in memberships for c in p['clubs'])
    by_club = defaultdict(set)
    for p in memberships:
        for c in p['clubs']: by_club[c].add(p['id'])
    clubs_of = {p['id']: set(p['clubs']) for p in memberships}
    def routes2(a, b):
        return sum(1 for x in by_club[a] for c in clubs_of[x] if c not in (a, b)
                   for y in by_club[c] & by_club[b] if y != x)
    def good(p, need):
        if min(deg[p['start']], deg[p['target']]) < need: return False
        if p['par'] == 1: return len(by_club[p['start']] & by_club[p['target']]) >= 2
        if p['par'] == 2: return routes2(p['start'], p['target']) >= 2
        return True
    def pick(k, n, salt):
        ordered = sorted(pairs.get(k, []), key=lambda p: hashlib.sha256((salt + p['id']).encode()).hexdigest())
        for need in (3, 2):
            chosen = [p for p in ordered if good(p, need)]
            if len(chosen) >= n: return chosen[:n]
        chosen = [p for p in ordered if good(p, 1)]
        return (chosen + [p for p in ordered if p not in chosen])[:n]
    # PAR 4 pairs sit between remote clubs by nature: keep only those whose
    # both ends have at least two connectors and give the rest to PAR 3.
    par4 = [p for p in sorted(pairs.get(4, []), key=lambda p: hashlib.sha256(p['id'].encode()).hexdigest())
            if good(p, 2)][:300]
    selected = {2: pick(2, 300, ''), 3: pick(3, 600 - len(par4), ''), 4: par4}
    sprint = pick(1, 200, 'sprint') + pick(2, 400, 'sprint')
    data = dict(schema=1,sourceVersion=ct['version'],databaseSha256=ct['databaseSha256'],mystery=mystery,
        clubs=[clubs[i] for i in sorted(adjacency)],graph=memberships,
        mastery=[p for k in (2,3,4) for p in selected.get(k,[])],
        sprint=sprint,
        quality=dict(mystery=len(mystery),teammateClues=sum(p['hints'][3]['id']=='teammate' for p in mystery),
            profileClues=sum(any(h['id']=='profile' for h in p['hints']) for p in mystery),
            sharedAnswers=sum('alsoPlayerIds' in p for p in mystery),
            untranslated=sorted({p['country'] for p in mystery if p['country'] not in COUNTRY_TR}),
            levels=dict(Counter(p['difficulty'] for p in mystery)),
            pairEnds={k: Counter(min(3, deg[p['start']], deg[p['target']]) for p in v) for k, v in
                      [('mastery', [p for k in (2,3,4) for p in selected[k]]), ('sprint', sprint)]},
            graphPlayers=len(memberships),clubs=len(adjacency),availablePairs={k:len(v) for k,v in pairs.items()}))
    data['version']='mc-v1-'+hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()[:16]
    assert len(mystery)>100 and len(data['mastery'])>=100 and len(data['sprint'])>=100
    return data

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data=build();encoded=json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n'
    if args.check: assert OUT.read_text(encoding='utf-8')==encoded, 'Catalog drift'
    else: OUT.write_text(encoded,encoding='utf-8')
    print(json.dumps(data['quality'],ensure_ascii=False))
