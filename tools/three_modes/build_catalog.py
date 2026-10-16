"""Compile source-bound Hoca 11, Harf 11 and Kadro Kasası content, offline."""
import argparse
from collections import Counter, defaultdict
import hashlib
from itertools import combinations
import json
from pathlib import Path
import random
import re
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT/'assets/runtime/linkball_game_data_v4.sqlite'
HERE = Path(__file__).parent
FORMATIONS = {'433':['FWD']*3+['MID']*3+['DEF']*4+['GK'],
              '442':['FWD']*2+['MID']*4+['DEF']*4+['GK'],
              '352':['FWD']*2+['MID']*5+['DEF']*3+['GK'],
              '4231':['FWD']+['MID']*5+['DEF']*4+['GK'],
              '451':['FWD']+['MID']*5+['DEF']*4+['GK']}
GROUP = {'Goalkeeper':'GK','Defender':'DEF','Midfield':'MID','Attack':'FWD'}
LETTERS = list('ABCÇDEFGHIİJKLMNOÖPRSŞTUÜVYZ')
COACHES = {
 'Jürgen Klopp':('Jürgen Klopp','coach_portrait_jurgen_klopp','persona_jurgen_klopp'),
 'Zinédine Zidane':('Zinedine Zidane','coach_portrait_zinedine_zidane','persona_zinedine_zidane_coach'),
 'Alex Ferguson':('Alex Ferguson','coach_portrait_alex_ferguson','persona_alex_ferguson'),
 'Josep Guardiola i Sala':('Pep Guardiola','coach_0','persona_pep_guardiola'),
 'Massimiliano Allegri':('Massimiliano Allegri','coach_72','persona_massimiliano_allegri'),
 'Luis Enrique Martínez García':('Luis Enrique','coach_5','persona_luis_enrique'),
 'Mauricio Roberto Pochettino Trossero':('Mauricio Pochettino',None,None),
}

def norm(s):
    s=s.casefold().translate(str.maketrans({'ı':'i','ø':'o','ł':'l','ß':'ss','đ':'d'}))
    return re.sub(r'[^a-z0-9]+',' ',''.join(c for c in unicodedata.normalize('NFKD',s) if not unicodedata.combining(c))).strip()

def initials(names):
    result=set()
    for name in names:
        for token in re.split(r'[\s-]+',name.strip()):
            if not token: continue
            ch=token[0]
            if ch in 'iİ': ch='İ'
            elif ch in 'Iı': ch='I'
            elif ch.upper() not in 'ÇĞÖŞÜ': ch=norm(ch).upper()[:1]
            else: ch=ch.upper()
            if ch in LETTERS: result.add(ch)
    return sorted(result)

def viable(ids, players):
    counts=Counter(players[i]['position'] for i in ids)
    return [f for f,slots in FORMATIONS.items() if all(counts[p]>=n for p,n in Counter(slots).items())]

def build():
    sha=hashlib.sha256(DB.read_bytes()).hexdigest()
    evidence=json.loads((HERE/'coach_match_evidence.json').read_text(encoding='utf-8'))
    if sha!=evidence['baseDatabaseSha256']: raise ValueError('Review coach canonical IDs against new base')
    c=sqlite3.connect(f'file:{DB}?mode=ro',uri=True);c.row_factory=sqlite3.Row
    aliases=defaultdict(list)
    for r in c.execute('select player_id,alias from player_aliases'): aliases[r['player_id']].append(r['alias'])
    players={r['id']:dict(id=r['id'],name=r['name'],country=r['country'],position=GROUP.get(r['position'],''),
             rank=r['selection_rank'] or 999999,aliases=sorted(set(aliases[r['id']])),
             letters=initials([r['name']]+aliases[r['id']]),search=norm(' '.join([r['name']]+aliases[r['id']])))
             for r in c.execute('select * from players')}
    clubs={r['id']:dict(id=r['id'],name=r['name'],country=r['country'],league=r['competition'],
            badgeKey=r['badge_key'],search=norm(r['name'])) for r in c.execute("select * from clubs where entity_type='SENIOR'")}
    # Existing canonical relations only; positive club appearances are required
    # for vault generation. A career club list alone cannot prove a coach link.
    club_players=defaultdict(set)
    for r in c.execute('select player_id,club_id from player_club_stats where appearances>0'):
        if r['player_id'] in players and r['club_id'] in clubs:
            club_players[r['club_id']].add(r['player_id'])
    for player in players.values():
        player['clubs']=[]
    for cid,ids in club_players.items():
        for pid in ids: players[pid]['clubs'].append(cid)
    for player in players.values(): player['clubs'].sort()
    coach_links=defaultdict(dict)
    for a in evidence['appearances']:
        pid=a['playerId']
        if pid is None or not a['participated'] or not a['positions']: continue
        if pid not in players or a['clubId'] not in clubs: raise ValueError('Invalid match identity')
        club_players[a['clubId']].add(pid)
        coach_links[a['coachKey']].setdefault(str(pid),[]).append(dict(
            clubId=a['clubId'],date=a['date'],matchId=a['matchId'],sources=a['sources']))
    offers={o['itemId']:o for o in json.loads((ROOT/'functions/config/store_collection.json').read_text())['offers']}
    coaches=[]
    for coach in evidence['coaches']:
        if coach['name'] not in COACHES: continue
        name,portrait,avatar=COACHES[coach['name']]
        links=coach_links[coach['key']]
        forms=viable(map(int,links),players)
        if not forms: continue
        # Fixed release snapshot, not a runtime sale price.
        if avatar and (avatar not in offers or offers[avatar]['itemType']!='avatar'): raise ValueError('Unknown avatar')
        cid=coach['key'].replace(':','_')
        coaches.append(dict(id=cid,name=name,portraitId=portrait,avatarId=avatar,
            avatarCoins=offers[avatar]['priceCoins'] if avatar else 0,links=links,formations=forms,
            difficulty='easy' if len(links)>=15 else 'medium',coverage='verified_match_subset'))
    letters=[]
    for letter in LETTERS:
        ids=[p['id'] for p in players.values() if letter in p['letters'] and p['position'] and p['rank']<=12000]
        forms=viable(ids,players)
        if forms:
            letters.append(dict(id=f'L{ord(letter)}',letter=letter,formations=forms,count=len(ids),
                difficulty='easy' if len(ids)>=500 else 'medium' if len(ids)>=100 else 'hard'))
    league_map={'Premier League':('England','Premier League'),'LaLiga':('Spain','La Liga'),
       'Serie A':('Italy','Serie A'),'Bundesliga':('Germany','Bundesliga'),'Süper Lig':('Turkey','Süper Lig'),
       'Ligue 1':('France','Ligue 1'),'Liga Portugal':('Portugal','Liga Portugal'),
       'Eredivisie':('Netherlands','Eredivisie')}
    pools={}
    for cid,ids in club_players.items():
        club=clubs[cid];group=league_map.get(club['league'])
        nation=norm(club['country']).replace('turkiye','turkey')
        if not group or nation!=norm(group[0]): continue
        ids={i for i in ids if players[i]['rank']<=12000 and players[i]['country'] and players[i]['position']}
        if len(ids)<16 or '433' not in viable(ids,players): continue
        pools[cid]=sorted(ids,key=lambda i:(players[i]['rank'],i))
    # Reject uninformative triples and trivially unique triples within the
    # release universe. Country counts are matched per position, with duplicates.
    signatures={cid:Counter((players[i]['position'],players[i]['country']) for i in ids) for cid,ids in pools.items()}
    puzzles=[]
    for cid,ids in sorted(pools.items()):
        rng=random.Random(cid)
        for variant in range(3):
            groups={pos:[i for i in ids if players[i]['position']==pos][:24] for pos in GROUP.values()}
            for g in groups.values(): rng.shuffle(g)
            chosen=[groups[pos].pop() for pos in FORMATIONS['433']]
            if len({players[i]['country'] for i in chosen})<4: continue
            options=[]
            for triple in combinations(range(11),3):
                sig=Counter((players[chosen[i]]['position'],players[chosen[i]]['country']) for i in triple)
                compatible=[k for k,v in signatures.items() if all(v[p]>=n for p,n in sig.items())]
                count=len(compatible)
                same_league=sum(clubs[k]['league']==clubs[cid]['league'] for k in compatible)
                if not (2<=count<=max(4,len(pools)//2)) or same_league<2: continue
                diversity=len({players[chosen[i]]['country'] for i in triple})
                options.append(((abs(count-8),-diversity,triple),triple,count,same_league))
            if not options: continue
            _,triple,count,same=min(options)
            puzzles.append(dict(id=f'V{cid}_{variant}',clubId=cid,formation='433',players=chosen,
                initial=list(triple),quality=dict(compatibleClubs=count,compatibleLeagueClubs=same)))
    active_clubs=sorted({p['clubId'] for p in puzzles})
    for club in clubs.values():
        # Search remains global; versioned league membership is separate.
        club['aliases']=[]
    for cid,alias in {36:['Fenerbahçe','Fenerbahce SK'],141:['Galatasaray SK'],114:['Beşiktaş','Besiktas'],
       131:['Barcelona','Barça'],418:['Real Madrid'],281:['Manchester City','Man City'],
       985:['Manchester United','Man United'],31:['Liverpool'],631:['Chelsea'],5:['Milan'],
       46:['Inter','Internazionale'],506:['Juventus'],583:['PSG','Paris Saint-Germain']}.items():
        if cid in clubs:
            clubs[cid]['aliases']=alias
            clubs[cid]['search']=norm(' '.join([clubs[cid]['name']]+alias))
    catalog=dict(schemaVersion=1,version='three-modes-2026-10-16.1',baseSha256=sha,
        formations=FORMATIONS,players=list(players.values()),clubs=list(clubs.values()),
        letters=letters,coaches=coaches,puzzles=puzzles,leagueSnapshot='v4-2026-10-05.1',
        sources=evidence['sources'],vaultClubs=active_clubs,
        policy=dict(medals=[{'at':5,'coins':5,'xp':10},{'at':8,'coins':10,'xp':20},
            {'at':11,'coins':15,'xp':30},{'at':11,'coins':10,'xp':20,'mastery':True}],
            vault=[{'at':1,'coins':5,'xp':10},{'at':3,'coins':10,'xp':20},{'at':5,'coins':10,'xp':20}],
            daily={'letter11':{'coins':10,'xp':20},'coach_xi':{'coins':0,'xp':0}},
            hintCosts={'flag':1,'league':1,'player':2},hintDailyLimit=6,
            archiveBonus={'at':5,'coins':30,'xp':50},leagueKnowledgePenalty=1))
    report=dict(version=catalog['version'],players=len(players),letters=len(letters),coaches=len(coaches),
       coachPools=[dict(name=x['name'],players=len(x['links']),formations=x['formations']) for x in coaches],
       vaultClubs=len(active_clubs),puzzles=len(puzzles),
       leagues=dict(Counter(clubs[i]['league'] for i in active_clubs)),
       excludedCoachRule='No full XI or no canonical match identity; never use union of career clubs',
       remaining='Coach evidence is a match subset; unknown links are unverified, never a punitive wrong answer.')
    c.close()
    return catalog,report

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    catalog,report=build()
    outputs={ROOT/'functions/config/three_modes_catalog.json':catalog,ROOT/'docs/three-modes/data-audit.json':report}
    for path,data in outputs.items():
        raw=(json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode()
        if args.check:
            if not path.exists() or path.read_bytes()!=raw: raise SystemExit(f'Stale {path}')
        else: path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__': main()
