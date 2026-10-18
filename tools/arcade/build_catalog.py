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
def cid(i): return i-1000000000 if i >= 1000000000 and i-1000000000 in rawclubs else i
clubs = {str(cid(i)): {'id':str(cid(i)), 'name':r['name'], 'badgeKey':r['badge_key'], 'popularity':r['popularity_seed'] or 0} for i,r in rawclubs.items() if cid(i)==i and r['entity_type']=='SENIOR' and r['gameplay_eligible']}
links = collections.defaultdict(set)
for r in c.execute('select * from player_clubs where trust>=2'):
    if str(cid(r['club_id'])) in clubs: links[str(r['player_id'])].add(str(cid(r['club_id'])))
players = {}
for r in c.execute('select * from players where answer_eligible=1'):
    i = str(r['id'])
    if not links[i]: continue
    country = (r['country'] or '').strip()
    aliases={'turkiye':'Turkey','turkey':'Turkey','czechia':'Czech Republic','czechrepublic':'Czech Republic',
      'unitedstates':'USA','unitedstatesofamerica':'USA','usa':'USA','korearepublic':'South Korea',
      'koreasouth':'South Korea','southkorea':'South Korea','cotedivoire':"Côte d'Ivoire",'ivorycoast':"Côte d'Ivoire",
      'bosniaherzegovina':'Bosnia and Herzegovina','holland':'Netherlands','thenetherlands':'Netherlands'}
    country=aliases.get(key(country),country)
    if key(country) in {'unknown','na','none','korea'}:country=''
    players[i] = {'id':i,'name':r['name'],'country':country, 'countryId':key(country), 'clubs':sorted(links[i]), 'rank':r['selection_rank'] or 999999, 'avatarKey':r['avatar_key'] or '', 'aliases':[]}
for r in c.execute('select * from player_aliases'):
    if str(r['player_id']) in players: players[str(r['player_id'])]['aliases'].append(r['alias'])
# Query labels can collide; resolved IDs still work. A puzzle needs >=6 uniquely named answers.
labels = collections.Counter(key(p['name']) for p in players.values())
pairs = collections.defaultdict(list)
for i,p in players.items():
    if labels[key(p['name'])] != 1: continue
    for a,b in itertools.combinations(p['clubs'],2): pairs['clubClub:'+a+':'+b].append(i)
    if p['countryId'] and p['countryId'] not in {'unknown','na','none'}:
        for a in p['clubs']: pairs['clubCountry:'+a+':'+p['countryId']].append(i)
burst = []
for k,ids in sorted(pairs.items()):
    if len(ids)<6: continue
    typ,a,b=k.split(':'); ranks=sorted(players[i]['rank'] for i in ids)
    tier = 'easy' if ranks[2]<500 else 'normal' if ranks[2]<1800 else 'hard' if ranks[2]<6000 else 'legend'
    burst.append({'id':k,'pairType':typ,'left':clubs[a]['name'],'right':clubs[b]['name'] if typ=='clubClub' else players[ids[0]]['country'], 'answers':sorted(ids),'difficulty':tier})
# Matching: include all uncertain career links as exclusions, never infer completeness.
fc = json.loads((ROOT/'functions/config/fake_club_catalog.json').read_text())
careers=[]
for p in fc['careers']:
    i=str(p['playerId'])
    if i not in players or p['coverage']!='REVIEWED_COMPLETE_RETIRED': continue
    careers.append({'playerId':i,'clubs':[str(x) for x in p['seniorClubIds'] if str(x) in clubs], 'excluded':[str(x) for x in p['excludedClubIds']], 'sources':p['sources'], 'reviewedAt':p['reviewedAt'], 'coverage':p['coverage']})
# Pyramid positive graph: recognisable ranked players + explicitly reviewed legends.
selected=sorted(players.values(),key=lambda p:(p['rank'],p['id']))[:220]
selected += [players[p['playerId']] for p in careers if players[p['playerId']] not in selected]
entities={}
for p in selected: entities['p'+p['id']]={'id':'p'+p['id'],'type':'player','name':p['name'],'playerId':p['id'],'clubs':p['clubs'],'countryId':p['countryId']}
for ci in sorted(set(x for p in selected for x in p['clubs'])): entities['c'+ci]={'id':'c'+ci,'type':'club','name':clubs[ci]['name'],'clubs':[ci]}
for p in selected:
    if p['countryId']: entities['n'+p['countryId']]={'id':'n'+p['countryId'],'type':'country','name':p['country'],'countryId':p['countryId'],'clubs':[]}
def evidence(a,b):
    if a['type']=='player' and b['type']=='player':
        shared=sorted(set(a['clubs']) & set(b['clubs']))
        return {'type':'sharedClub','clubId':shared[0]} if shared else None
    if b['type']=='player': a,b=b,a
    if a['type']!='player': return None
    if b['type']=='club' and b['clubs'][0] in a['clubs']: return {'type':'seniorClub','clubId':b['clubs'][0]}
    if b['type']=='country' and a['countryId']==b['countryId']: return {'type':'nationality','countryId':b['countryId']}
    return None
adj={i:set() for i in entities}; edges={}
for a,b in itertools.combinations(entities,2):
    ev=evidence(entities[a],entities[b])
    if ev:
        adj[a].add(b);adj[b].add(a); edges['|'.join(sorted([a,b]))]=ev

def full_board(n):
    """Construct all slots top-down, each child linked to its one/two parents."""
    for attempt in range(500):
        chosen=[rng.choice(list(entities))]; rows=[[chosen[0]]]; ok=True
        for row in range(1,n):
            current=[]
            for col in range(row+1):
                parents=rows[-1][max(0,col-1):min(col+1,row)]
                choices=set.intersection(*(adj[p] for p in parents))-set(chosen)
                if not choices:ok=False;break
                # Prefer mixed relation witnesses, not a single club clique.
                options=sorted(choices);rng.shuffle(options)
                value=options[0];chosen.append(value);current.append(value)
            if not ok: break
            rows.append(current)
        if not ok: continue
        common=set(entities[chosen[0]]['clubs'])
        for i in chosen[1:]: common &= set(entities[i]['clubs'])
        witnesses=set()
        for r in range(n-1):
            for j,a in enumerate(rows[r]):
                for b in rows[r+1][j:j+2]:
                    ev=edges['|'.join(sorted([a,b]))]; witnesses.add(ev.get('clubId','n:'+ev.get('countryId','')))
        interior=[i for row in rows[1:-1] for i in row]
        interior_common=set(entities[interior[0]]['clubs'])
        for i in interior[1:]:interior_common &= set(entities[i]['clubs'])
        if common or interior_common or len(witnesses)<3:continue
        return rows
    raise RuntimeError('No diverse certified triangle within budget')
boards=[]
for diff,n in [('easy',4),('normal',5),('hard',5)]:
    for number in range(16):
        rows=full_board(n); slots=[];solution={};initial={};i=0
        for r,row in enumerate(rows):
            for j,entity in enumerate(row):
                slots.append({'id':str(i),'row':r,'column':j,'supports':[str((r+1)*(r+2)//2+j),str((r+1)*(r+2)//2+j+1)] if r<n-1 else []})
                solution[str(i)]=entity
                if r in [0,n-1]:initial[str(i)]=entity
                i+=1
        boards.append({'id':f'pyramid:{diff}:{number+1}','difficulty':diff,'levels':n,'slots':slots,'initial':initial,'certificate':solution})
five=[b for b in boards if b['levels']==5]
def complexity(b):
    ids=list(b['certificate'].values())
    witness={json.dumps(edges['|'.join(sorted([b['certificate'][s['id']],b['certificate'][n]]))],sort_keys=True) for s in b['slots'] for n in s['supports']}
    return len(witness)*100-sum(len(adj[i]) for i in ids)/len(ids)
five.sort(key=lambda b:(complexity(b),b['id']))
for index,b in enumerate(five):
    diff='normal' if index<16 else 'hard'; b['difficulty']=diff;b['id']=f'pyramid:{diff}:{index%16+1}'
    b['complexity']=round(complexity(b),2)
catalog={'schema':1,'databaseSha256':hashlib.sha256(DB.read_bytes()).hexdigest(),'players':players,'clubs':clubs,'burst':burst,'careers':careers,'entities':entities,'edges':edges,'pyramids':boards,'policy':{'matchingPairs':{'easy':6,'normal':8,'hard':12},'stars':{'threePerPair':2,'twoPerPair':3,'calibration':'provisional; requires device playtest'},'maxPickAttempts':40}}
body=json.dumps(catalog,ensure_ascii=False,sort_keys=True,separators=(',',':'))
catalog['version']='arcade-v1-'+hashlib.sha256(body.encode()).hexdigest()[:16]
out=ROOT/'functions/config/arcade_catalog.json'; text=json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n'
if '--check' in sys.argv:
    assert out.read_text()==text, 'Arcade catalog drift; run tools/arcade/build_catalog.py'
else: out.write_text(text)
print(json.dumps({'version':catalog['version'],'players':len(players),'burst':len(burst),'burstTiers':dict(collections.Counter(x['pairType']+'/'+x['difficulty'] for x in burst)),'completeCareers':len(careers),'pyramidEntities':len(entities),'pyramidBoards':len(boards),'bytes':out.stat().st_size},indent=2))
