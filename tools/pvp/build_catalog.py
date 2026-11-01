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
from functools import lru_cache
@lru_cache(maxsize=None)
def country(raw):
    # Same display aliases as CountryNames; cross-runtime vectors verify every alias.
    source=(ROOT/'lib/utils/country_names.dart').read_text(encoding='utf-8')
    block=source.split('_aliases = {',1)[1].split('};',1)[0]
    aliases={m.group(2):m.group(4) for m in re.finditer(r"(['\"])(.*?)\1\s*:\s*(['\"])(.*?)\3",block)}
    t=str(raw or '').strip();return aliases.get(t.lower().replace('ı','i'),t)
def position_group(pos,det):
    pos=(pos or '').strip().lower();det=(det or pos).strip().lower();raw=pos+' '+det
    if any(k in raw for k in ['goal','keeper','kaleci']) or pos in ['g','gk']:return 'GK'
    if any(k in raw for k in ['midfield','midfielder','orta saha','orta-saha']) or any(k in det for k in ['cdm','cam','cm','dm','am']) or pos in ['m','mf','mid']:return 'MID'
    if ' mid' in raw or raw.startswith('mid') or 'orta' in raw:return 'MID'
    if any(k in raw for k in ['strik','forw','forvet','second striker']) or any(k in det for k in ['cf','st']) or pos in ['f','fw','a','att']:return 'ATT'
    if ('wing' in raw and 'back' not in raw and 'wingback' not in raw and 'wing-back' not in raw) or 'winger' in raw or det in ['lw','rw']:return 'ATT'
    if 'attack' in raw and 'midfield' not in raw:return 'ATT'
    if any(k in raw for k in ['defen','centre-back','center-back','center back','centre back','full-back','fullback','full back','wing-back','wingback','wing back','stoper','bek','stopper']) or any(k in det for k in ['cb','lb','rb','lwb','rwb']) or pos in ['d','df','def']:return 'DEF'
    if 'back' in raw and 'mid' not in raw:return 'DEF'
    return 'MID'
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
    for r in c.execute('select p.*,pr.detailed_position from players p left join profiles pr on pr.player_id=p.id order by p.id'):
        if r['id'] in [34601,111961]: continue  # Same canonical shadow remaps as the V4 bridge.
        i=r['id'];ids=sorted(links[i]|{x for x,_,_ in spells[i]})
        ns=list(dict.fromkeys(country(n) for n in (countries[i] or ([r['country']] if r['country'] else [])) if country(n)))
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
          'position':position_group(r['position'],r['detailed_position']),
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
    # Grid: 300 boards; every cell has 3+ answers and one of them among the 3000 best-known players.
    rng=random.Random(191026);grids=[];seen=set()
    known=lambda ids:any(players[i]['rank']<=3000 for i in ids)
    for attempt in range(200000):
        rows=rng.sample(club_keys,3)
        viable=[k for k in country_keys+club_keys if k not in rows and all(len(members[k]&members[a])>=3 for a in rows)]
        if len(viable)<3:continue
        cols=rng.sample(viable,3)
        answers=[sorted(members[a]&members[b]) for a in rows for b in cols]
        if min(map(len,answers))<3 or not all(map(known,answers)):continue
        sig=(tuple(sorted(rows)),tuple(sorted(cols)))
        if sig in seen:continue
        used=set();witness=[]
        for ids in answers:
            options=sorted(set(ids)-used,key=lambda i:(players[i]['rank'],i))
            if not options:break
            witness.append(options[0]);used.add(options[0])
        if len(witness)!=9:continue
        seen.add(sig)
        grids.append({'id':'grid'+str(len(grids)), 'rows':rows,'cols':cols,'answers':answers,'witness':witness})
        if len(grids)==300:break
    assert len(grids)==300,'Insufficient solvable 3x3 boards'
    # Football Loto: 300 boards, 100 per tier. League cells come only from
    # well-known leagues; the tier sets how known the 16 players are; players
    # are stored shuffled, never aligned with the cell they answer.
    known_leagues=[k for k in ('league:'+key(x) for x in ['premier league','laliga','serie a','bundesliga',
        'ligue 1','süper lig','eredivisie','liga portugal','1.lig']) if k in criteria]
    assert len(known_leagues)>=8,known_leagues
    # Exactly pvp_engine.matches: a league cell matches only its stored value
    # ("la liga" and "laliga" share an id, but the engine checks one spelling).
    def fits(i,k):
        cr=criteria[k];p=players[i]
        return cr['value'] in (p['clubs'] if cr['type']=='club' else p['countryKeys'] if cr['type']=='country' else p['leagues'])
    # Futbol Çinko: 200 boards. Each has 1-2 well-known league cells, 5 country
    # cells, 4 scarce cells (clubs or countries with 20-60 players, at least 3 of
    # them among the 12000 best known) and well-known clubs for the rest. Every
    # cell can be filled with a different player, like the bot board.
    known=lambda k:sum(1 for i in members[k] if players[i]['rank']<=12000)
    scarce_keys=sorted(k for k in criteria if (k.startswith('club:') or k.startswith('country:')) and
        20<=len(members[k])<=60 and known(k)>=3 and k not in club_keys)
    def distinct(ks):
        owner={}
        def place(cell,seen):
            for i in sorted(members[ks[cell]]):
                if i in seen or not fits(i,ks[cell]):continue
                seen.add(i)
                if i not in owner or place(owner[i],seen):
                    owner[i]=cell;return True
            return False
        return all(place(cell,set()) for cell in range(len(ks)))
    crng=random.Random(311027);cinko=[]
    while len(cinko)<200:
        nl=crng.choice([1,2])
        ks=crng.sample(known_leagues,nl)+crng.sample(country_keys,5)+crng.sample(scarce_keys,4)
        ks+=crng.sample([k for k in club_keys if k not in ks],25-len(ks));crng.shuffle(ks)
        if len(set(ks))==25 and distinct(ks):cinko.append({'id':'cinko'+str(len(cinko)),'criteria':ks})
    lrng=random.Random(311026);loto=[]
    for tier,limit in [('easy',1500),('medium',4000),('hard',12000)]:
        made=0
        while made<100:
            ks=lrng.sample(club_keys,8)+lrng.sample(country_keys,4)+lrng.sample(known_leagues,4);lrng.shuffle(ks)
            ids=[]
            for k in ks:
                opts=sorted(i for i in members[k]-set(ids) if players[i]['rank']<=limit and fits(i,k))
                if not opts:break
                ids.append(lrng.choice(opts))
            if len(ids)!=16:continue
            fit=[sum(fits(i,k) for k in ks) for i in ids]
            loto.append({'id':f'loto-{tier}-{made}','tier':tier,'criteria':ks,
                'players':sorted(ids,key=lambda i:hashlib.sha256((tier+str(made)+i).encode()).hexdigest()),
                'validCellsPerPlayer':round(sum(fit)/16,2)})
            made+=1
    # Random Five: 300 checked boards of 5 clubs. Each has a player who played
    # for 4 of them, at least 4 players with 3+ and 20 with 2+ (random sets of
    # 5 clubs rarely have anyone above 2).
    keyset=set(club_keys)
    seed_players=sorted(i for i,p in players.items() if len({'club:'+x for x in p['clubs']}&keyset)>=4)
    frng=random.Random(11126);five=[];seen=set()
    def five_counts(ks):
        n=collections.Counter()
        for k in ks:
            for i in members[k]:n[i]+=1
        return n
    while len(five)<300:
        own=sorted({'club:'+x for x in players[frng.choice(seed_players)]['clubs']}&keyset)
        ks=frng.sample(own,4);base=five_counts(ks)
        gain=sorted(((sum(1 for i in members[k] if base[i]),k) for k in club_keys if k not in ks),reverse=True)[:5]
        ks.append(frng.choice(gain)[1]);frng.shuffle(ks)
        n=five_counts(ks);top=max(n.values())
        if tuple(sorted(ks)) in seen or top<4 or sum(v>=3 for v in n.values())<4 or sum(v>=2 for v in n.values())<20:
            continue
        seen.add(tuple(sorted(ks)));five.append({'id':'five'+str(len(five)),'clubs':ks})
    data={'schema':1,'databaseSha256':hashlib.sha256(DB.read_bytes()).hexdigest(),'ratingYear':YEAR,
      'players':players,'clubs':clubs,'criteria':criteria,'pairs':pairs,'grids':grids,'cinko':cinko,'loto':loto,'five':five,
      'clubOptions':club_keys,'countryOptions':country_keys,'shadowIds':{'34601':'631002','111961':'1650'}}
    body=json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
    data['version']='pvp-v1-'+hashlib.sha256(body).hexdigest()[:16]
    body=json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
    output=ROOT/'functions/config/pvp_catalog.json.gz';packed=gzip.compress(body,mtime=0)
    report={'version':data['version'],'databaseSha256':data['databaseSha256'],'players':len(players),
      'pairs':len(pairs),'grids':len(grids),'cinko':len(cinko),'loto':len(loto),
      'five':len(five),
      'cinkoScarceCellsPerBoard':4,'cinkoScarceKeys':len(scarce_keys),
      'lotoValidCellsPerPlayer':{t:round(sum(b['validCellsPerPlayer'] for b in loto if b['tier']==t)/100,2)
        for t in ['easy','medium','hard']},
      'relationPolicy':'Same player_clubs/countries as V4 solo bridge, no inferred negative careers',
      'trustCounts':dict(c.execute('select trust,count(*) from player_clubs group by trust').fetchall()),
      'sourceReview':'Canonical snapshot parity is not an independent external source audit.'}
    audit=ROOT/'docs/pvp/data-audit.json';report_text=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:
        assert gzip.decompress(output.read_bytes())==body,'PvP catalog drift'
        assert audit.read_text(encoding='utf-8')==report_text,'PvP audit drift'
    else: output.write_bytes(packed);audit.write_text(report_text,encoding='utf-8',newline='\n')
    print(report_text, 'Compressed bytes:',len(packed))
if __name__=='__main__':build()
