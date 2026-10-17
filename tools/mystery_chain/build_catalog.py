"""Conservative dated V4 clues and exact club graph; deterministic offline export."""
import argparse
from collections import Counter, defaultdict, deque
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'functions/config/mystery_chain_catalog.json'

def build():
    ct = json.loads((ROOT/'functions/config/career_transfer_catalog.json').read_text())
    people = json.loads((ROOT/'functions/config/three_modes_catalog.json').read_text())['players']
    players = {p['id']: p for p in people}
    clubs = {c['id']: c for c in ct['clubs']}
    con = sqlite3.connect(f"file:{ROOT/'assets/runtime/linkball_game_data_v4.sqlite'}?mode=ro", uri=True)
    popular = {i for i, in con.execute('select id from clubs where popularity_seed >= 10 and entity_type="SENIOR" and gameplay_eligible=1')}
    positions = {'GK': 'Kaleci', 'DEF': 'Defans', 'MID': 'Orta saha', 'FWD': 'Forvet'}
    groups = defaultdict(list)
    for p in people:
        if p['rank'] <= 5000: groups[(p['country'],p['position'])].append(p['id'])
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
                 dict(id='period',text=f"Seçili kariyer dönemi: {b['start'][:4]} – {(b['end'] or 'devam')[:4]}"),
                 dict(id='club_'+str(b['clubId']),text='Bir başka kulübü: '+clubs[b['clubId']]['name']),
                 teammate or dict(id='club_'+str(c['clubId']),text=f"{clubs[c['clubId']]['name']} kariyeri {c['start'][:4]} yılında başladı."),
                 dict(id='letter',text='Adının ilk harfi: '+next(ch for ch in p['name'] if ch.isalpha()))]
        mystery.append(dict(id=str(p['id']),playerId=p['id'],country=p['country'],position=positions[p['position']],
            hints=hints,options=options,onlineClubId=a['clubId'],source=career['source']))
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
    selected = {k: sorted(v,key=lambda p:hashlib.sha256(p['id'].encode()).hexdigest())[:300] for k,v in pairs.items()}
    data = dict(schema=1,sourceVersion=ct['version'],databaseSha256=ct['databaseSha256'],mystery=mystery,
        clubs=[clubs[i] for i in sorted(adjacency)],graph=memberships,
        mastery=[p for k in (2,3,4) for p in selected.get(k,[])],
        sprint=[p for k in (1,2) for p in selected.get(k,[])],
        quality=dict(mystery=len(mystery),teammateClues=sum(p['hints'][3]['id']=='teammate' for p in mystery),
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
