#!/usr/bin/env python3
"""Private multiplayer snapshot from the same V4 relations as the solo bridge.

No API calls, inferred careers, or client-provided scoring evidence. Ratings are
gameplay ratings (ManagerRatingService), not externally verified player statistics.
"""
import collections, gzip, hashlib, itertools, json, math, pathlib, random, re, sqlite3, sys, unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
YEAR = 2026  # Versioned rating snapshot; never the client clock.
def key(s):
    s = str(s or '').lower().translate(str.maketrans({'ı':'i','ß':'ss','ø':'o','ł':'l','đ':'d'}))
    return ''.join(x for x in unicodedata.normalize('NFKD', s) if x.isalnum())
def clamp(v,a,b): return min(b,max(a,v))
def league_score(s):
    s=s.lower()
    for words,score in [('premier league,la liga,laliga,serie a,bundesliga,ligue 1',95),
      ('championship,eredivisie,primeira,liga portugal,süper lig,super lig,superlig',72),
      ('belgian,jupiler,scottish,austrian,swiss,russian premier,russia,liga mx,mls,brasileirao,argentina',58)]:
        if any(w in s for w in words.split(',')): return score
    return 42 if s.strip() else 25
def build():
    c=sqlite3.connect(f'file:{DB}?mode=ro',uri=True);c.row_factory=sqlite3.Row
    clubs={str(r['id']):dict(id=str(r['id']),name=r['name'],league=r['competition'] or '',
      country=r['country'] or '',badgeKey=r['badge_key'] or '',rank=r['popularity_seed'],
      selectable=r['entity_type']=='SENIOR' and bool(r['gameplay_eligible'])) for r in c.execute('select * from clubs')}
    links=collections.defaultdict(set);countries=collections.defaultdict(list);aliases=collections.defaultdict(list);spells=collections.defaultdict(list)
    for r in c.execute('select * from player_clubs'): links[r['player_id']].add(str(r['club_id']))
    for r in c.execute('select * from player_countries order by player_id,ord'): countries[r['player_id']].append(r['country'])
    for r in c.execute('select * from player_aliases order by player_id,ord'): aliases[r['player_id']].append(r['alias'])
    for r in c.execute('select * from career_spells order by player_id,sequence'):
        start=re.search(r'\d{4}',r['start_date'] or '');end=re.search(r'\d{4}',r['end_date'] or '')
        if start: spells[r['player_id']].append((str(r['club_id']),int(start[0]),int(end[0]) if end else YEAR))
    players={}
    for r in c.execute('select * from players order by id'):
        if r['id'] in [34601,111961]: continue  # Same canonical shadow remaps as the V4 bridge.
        i=r['id'];ids=sorted(links[i]);ns=countries[i] or ([r['country']] if r['country'] else [])
        peak=r['peak_market_value'] or 0
        leagues={clubs[x]['league'].strip().lower() for x in ids if x in clubs and clubs[x]['league'].strip()}
        if spells[i]:
            lig=[(league_score(clubs.get(x,{}).get('league','')),max(1,b-a+1)) for x,a,b in spells[i]]
            cs=clamp(max(sum(v*w for v,w in lig)/sum(w for _,w in lig),.85*max(v for v,_ in lig)),10,100)
            length=clamp((max(b for _,_,b in spells[i])-min(a for _,a,_ in spells[i]))*5,10,100)
        else:
            cs=clamp(sum(league_score(clubs.get(x,{}).get('league','')) for x in ids)/len(ids),10,100) if ids else 25
            length=clamp(len(ids)*8,10,100)
        national=15 if not ns else 70+20*clamp((peak-20e6)/80e6,0,1) if peak>=20e6 else 45+20*clamp(peak/20e6,0,1)
        all_ids=set(ids)|{x for x,_,_ in spells[i]}
        all_leagues={clubs[x]['league'].strip().lower() for x in all_ids if x in clubs and clubs[x]['league'].strip()}
        rating=.35*cs+.2*national+.15*length+.2*(clamp(12*math.log10(peak+1),5,100) if peak>0 else 5)+.1*clamp(len(all_ids)*12+len(all_leagues)*8,10,100)
        players[str(i)]={'id':str(i),'name':r['name'],'aliases':sorted(set(aliases[i])), 'clubs':ids,
          'countries':ns,'countryKeys':sorted({key(n) for n in ns}), 'leagues':sorted(leagues),
          'position':{'Goalkeeper':'GK','Defender':'DEF','Midfield':'MID','Attack':'ATT'}.get(r['position'],''),
          'rank':r['selection_rank'] or 999999,'rating':round(rating,1),'cost':18 if rating>=90 else 14 if rating>=80 else 10 if rating>=65 else 6,
          'linkClubs':sorted(all_ids),'linkLeagues':sorted(all_leagues)}
    criteria={};members=collections.defaultdict(set)
    for i,p in players.items():
        for x in p['clubs']:
            if x in clubs and clubs[x]['selectable']:
                k='club:'+x;members[k].add(i);criteria[k]={'id':k,'type':'club','value':x,'label':clubs[x]['name']}
        for n in p['countries']:
            k='country:'+key(n)
            if key(n) in ['unknown','na','none','']: continue
            members[k].add(i);criteria[k]={'id':k,'type':'country','value':key(n),'label':n}
        for league in p['leagues']:
            k='league:'+key(league);members[k].add(i);criteria[k]={'id':k,'type':'league','value':league,'label':league}
    club_keys=sorted((k for k in criteria if k.startswith('club:') and len(members[k])>=20),key=lambda k:(-clubs[k[5:]]['rank'],k))[:90]
    country_keys=sorted((k for k in criteria if k.startswith('country:') and len(members[k])>=40),key=lambda k:(-len(members[k]),k))[:45]
    league_keys=sorted((k for k in criteria if k.startswith('league:') and len(members[k])>=50),key=lambda k:(-len(members[k]),k))[:30]
    pairs=[]
    for a,b in list(itertools.combinations(club_keys,2))+list(itertools.product(club_keys,country_keys)):
        ids=members[a]&members[b]
        if len(ids)>=6: pairs.append({'id':a+'|'+b,'criteria':[a,b],'answers':sorted(ids)})
    rng=random.Random(191026);grids=[]
    for attempt in range(20000):
        rows=rng.sample(club_keys,3)
        viable=[k for k in country_keys+club_keys if k not in rows and all(len(members[k]&members[a])>=3 for a in rows)]
        if len(viable)<3:continue
        cols=rng.sample(viable,3)
        answers=[sorted(members[a]&members[b]) for a in rows for b in cols]
        if min(map(len,answers))<3:continue
        used=set();witness=[]
        for ids in answers:
            options=sorted(set(ids)-used,key=lambda i:(players[i]['rank'],i))
            if not options:break
            witness.append(options[0]);used.add(options[0])
        if len(witness)!=9:continue
        grids.append({'id':'grid'+str(len(grids)), 'rows':rows,'cols':cols,'answers':answers,'witness':witness})
        if len(grids)==60:break
    assert len(grids)==60,'Insufficient solvable 3x3 boards'
    cinko=[];loto=[]
    for n in range(40):
        ks=rng.sample(club_keys,15)+rng.sample(country_keys,5)+rng.sample(league_keys,5);rng.shuffle(ks)
        cinko.append({'id':'cinko'+str(n),'criteria':ks})
        ks=rng.sample(club_keys,8)+rng.sample(country_keys,4)+rng.sample(league_keys,4);rng.shuffle(ks)
        ids=[]
        for k in ks:
            opts=sorted(members[k]-set(ids),key=lambda i:(players[i]['rank'],i))[:80]
            assert opts;ids.append(rng.choice(opts))
        loto.append({'id':'loto'+str(n),'criteria':ks,'players':ids})
    data={'schema':1,'databaseSha256':hashlib.sha256(DB.read_bytes()).hexdigest(),'ratingYear':YEAR,
      'players':players,'clubs':clubs,'criteria':criteria,'pairs':pairs,'grids':grids,'cinko':cinko,'loto':loto,
      'clubOptions':club_keys,'countryOptions':country_keys,'shadowIds':{'34601':'631002','111961':'1650'}}
    body=json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
    data['version']='pvp-v1-'+hashlib.sha256(body).hexdigest()[:16]
    body=json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
    output=ROOT/'functions/config/pvp_catalog.json.gz';packed=gzip.compress(body,mtime=0)
    report={'version':data['version'],'databaseSha256':data['databaseSha256'],'players':len(players),
      'pairs':len(pairs),'grids':len(grids),'cinko':len(cinko),'loto':len(loto),
      'relationPolicy':'Same player_clubs/countries as V4 solo bridge, no inferred negative careers',
      'trustCounts':dict(c.execute('select trust,count(*) from player_clubs group by trust').fetchall()),
      'sourceReview':'Canonical snapshot parity is not an independent external source audit.'}
    audit=ROOT/'docs/pvp/data-audit.json';report_text=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:
        assert gzip.decompress(output.read_bytes())==body,'PvP catalog drift'
        assert audit.read_text()==report_text,'PvP audit drift'
    else: output.write_bytes(packed);audit.write_text(report_text)
    print(report_text, 'Compressed bytes:',len(packed))
if __name__=='__main__':build()
