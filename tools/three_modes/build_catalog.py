"""Compile source-bound Harf 11 and Kadro Kasası content, offline."""
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
# Turkish alphabet plus W (Walker, Werner, Wijnaldum: 343 players).
LETTERS = list('ABCÇDEFGHIİJKLMNOÖPRSŞTUÜVWYZ')
# Lower-case surname particles never give a letter on their own ("Virgil van
# Dijk" is D and V only through Virgil/Dijk); a capitalised one is part of the
# surname and counts ("Kevin De Bruyne" is D).
PARTICLES = {'van','von','de','da','di','do','dos','das','del','della','der','den','du','la','le',
             'el','al','bin','ben','ten','ter','y','e','zu','of','af'}
# Kadro Kasası: three puzzles per club in three formations; two puzzles of a
# club share at most MAX_SHARED players so the variants are not memorised.
VAULT_FORMATIONS = ['433', '4231', '352']
MAX_SHARED = 3
# Median selection rank of the eleven: roughly thirds of the release puzzles.
ALIASES = {36:['Fenerbahçe','Fenerbahce SK','Fener'],141:['Galatasaray SK','Gala','Cimbom'],
    114:['Beşiktaş','Besiktas','BJK'],449:['Trabzon'],131:['Barcelona','Barça','Barca'],418:['Real Madrid'],
    281:['Manchester City','Man City','City'],985:['Manchester United','Man United','Man Utd'],
    31:['Liverpool'],631:['Chelsea'],11:['Arsenal','Gunners'],148:['Tottenham','Spurs'],5:['Milan'],
    46:['Inter','Internazionale'],506:['Juventus','Juve'],583:['PSG','Paris Saint-Germain'],
    27:['Bayern','FC Bayern'],16:['Dortmund','BVB'],13:['Atletico Madrid','Atleti'],610:['Ajax'],
    720:['Porto'],294:['Benfica'],1090:['AZ'],12:['Roma'],398:['Lazio'],6195:['Napoli']}

def norm(s):
    s=s.casefold().translate(str.maketrans({'ı':'i','ø':'o','ł':'l','ß':'ss','đ':'d'}))
    return re.sub(r'[^a-z0-9]+',' ',''.join(c for c in unicodedata.normalize('NFKD',s) if not unicodedata.combining(c))).strip()

def initials(names, turkish=False):
    result=set()
    for name in names:
        for token in re.split(r'[\s-]+',name.strip()):
            if not token or token in PARTICLES: continue
            ch=token[0]
            if ch in 'iİ': ch='İ'
            # ASCII spellings of Turkish names ("Selcuk Inan") mean İ.
            elif ch=='I' and turkish: ch='İ'
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
    if sha!=evidence['baseDatabaseSha256']: raise ValueError('Review match canonical IDs against new base')
    c=sqlite3.connect(f'file:{DB}?mode=ro',uri=True);c.row_factory=sqlite3.Row
    aliases=defaultdict(list)
    for r in c.execute('select player_id,alias from player_aliases'): aliases[r['player_id']].append(r['alias'])
    players={r['id']:dict(id=r['id'],name=r['name'],country=r['country'],position=GROUP.get(r['position'],''),
             rank=r['selection_rank'] or 999999,aliases=sorted(set(aliases[r['id']])),
             letters=initials([r['name']]+aliases[r['id']],norm(r['country'] or '') in ('turkey','turkiye')),search=norm(' '.join([r['name']]+aliases[r['id']])))
             for r in c.execute('select * from players')}
    clubs={r['id']:dict(id=r['id'],name=r['name'],country=r['country'],league=r['competition'],
            badgeKey=r['badge_key'],search=norm(r['name']),popularity=0,
            searchable=bool(r['gameplay_eligible']) and bool((r['competition'] or '').strip()))
           for r in c.execute("select * from clubs where entity_type='SENIOR'")}
    # Existing canonical relations only; positive club appearances are required
    # for vault generation; StatsBomb lineups add verified club appearances.
    club_players=defaultdict(set)
    for r in c.execute('select player_id,club_id from player_club_stats where appearances>0'):
        if r['player_id'] in players and r['club_id'] in clubs:
            club_players[r['club_id']].add(r['player_id'])
    for player in players.values():
        player['clubs']=[]
    for cid,ids in club_players.items():
        for pid in ids: players[pid]['clubs'].append(cid)
    for player in players.values(): player['clubs'].sort()
    # Search order: how many well-known players appeared for the club. The V4
    # popularity seed is unreliable (Real Betis 19, Valladolid above Real Madrid).
    for cid,ids in club_players.items():
        clubs[cid]['popularity']=sum(players[i]['rank']<=2000 for i in ids)
    for a in evidence['appearances']:
        pid=a['playerId']
        if pid is None or not a['participated'] or not a['positions']: continue
        if pid not in players or a['clubId'] not in clubs: raise ValueError('Invalid match identity')
        club_players[a['clubId']].add(pid)
    letters=[]
    for letter in LETTERS:
        ids=[p['id'] for p in players.values() if letter in p['letters'] and p['position'] and p['rank']<=12000]
        forms=viable(ids,players)
        if forms:
            letters.append(dict(id=f'L{ord(letter)}',letter=letter,formations=forms,count=len(ids),
                difficulty='easy' if len(ids)>=900 else 'medium' if len(ids)>=200 else 'hard'))
    league_map={'Premier League':('England','Premier League'),'LaLiga':('Spain','La Liga'),
       'Serie A':('Italy','Serie A'),'Bundesliga':('Germany','Bundesliga'),'Süper Lig':('Turkey','Süper Lig'),
       'Ligue 1':('France','Ligue 1'),'Liga Portugal':('Portugal','Liga Portugal'),
       'Eredivisie':('Netherlands','Eredivisie'),
       'Major League Soccer':(('United States','Canada'),'MLS'),
       'Campeonato Brasileiro Série A':('Brazil','Brasileirão'),
       'Torneo Clausura':('Argentina','Arjantin Primera'),
       'Scottish Premiership':('Scotland','Scottish Premiership'),
       'Jupiler Pro League':('Belgium','Jupiler Pro League')}
    pools={}
    for cid,ids in club_players.items():
        club=clubs[cid];group=league_map.get(club['league'])
        nation=norm(club['country']).replace('turkiye','turkey')
        nations=group[0] if group and isinstance(group[0],tuple) else (group[0],) if group else ()
        if not group or nation not in {norm(n) for n in nations}: continue
        ids={i for i in ids if players[i]['rank']<=12000 and players[i]['country'] and players[i]['position']}
        if len(ids)<16 or '433' not in viable(ids,players): continue
        pools[cid]=sorted(ids,key=lambda i:(players[i]['rank'],i))
    # Reject uninformative triples and trivially unique triples within the
    # release universe. Country counts are matched per position, with duplicates.
    signatures={cid:Counter((players[i]['position'],players[i]['country']) for i in ids) for cid,ids in pools.items()}
    puzzles=[]
    for cid,ids in sorted(pools.items()):
        rng=random.Random(cid)
        made=[]
        for variant,form in enumerate(VAULT_FORMATIONS):
            if form not in viable(ids,players): continue
            groups={pos:[i for i in ids if players[i]['position']==pos][:24] for pos in GROUP.values()}
            for g in groups.values(): rng.shuffle(g)
            # Prefer players no earlier puzzle of this club used, so variants differ.
            used=set().union(*made) if made else set()
            for g in groups.values(): g.sort(key=lambda i:i not in used)
            chosen=[groups[pos].pop() for pos in FORMATIONS[form]]
            if any(len(set(chosen)&set(m))>MAX_SHARED for m in made): continue
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
            made.append(chosen)
            median=sorted(players[i]['rank'] for i in chosen)[5]
            puzzles.append(dict(id=f'V{cid}_{variant}',clubId=cid,formation=form,players=chosen,
                initial=list(triple),difficulty='easy' if median<=2800 else 'medium' if median<=6000 else 'hard',
                quality=dict(compatibleClubs=count,compatibleLeagueClubs=same,medianRank=median)))
    active_clubs=sorted({p['clubId'] for p in puzzles})
    for club in clubs.values():
        # Search remains global; versioned league membership is separate.
        club['aliases']=[]
    for cid,alias in ALIASES.items():
        if cid in clubs:
            clubs[cid]['aliases']=alias
            clubs[cid]['search']=norm(' '.join([clubs[cid]['name']]+alias))
    # One club, several V4 rows (same name and country): every row answers for
    # the same club, and only the main row is offered in the search list.
    same=defaultdict(list)
    for club in clubs.values():
        if club['searchable']: same[(norm(club['name']),norm(club['country']))].append(club['id'])
    for ids in same.values():
        if len(ids)<2: continue
        main=max(ids,key=lambda i:(i in active_clubs,clubs[i]['popularity'],-i))
        for i in ids:
            if i!=main:
                clubs[i]['canonicalId']=main; clubs[i]['searchable']=False
    catalog=dict(schemaVersion=1,version='three-modes-2026-10-31.3',baseSha256=sha,
        formations=FORMATIONS,players=list(players.values()),clubs=list(clubs.values()),
        letters=letters,puzzles=puzzles,leagueSnapshot='v4-2026-10-05.1',vaultClubs=active_clubs,
        policy=dict(medals=[{'at':5,'coins':5,'xp':10},{'at':8,'coins':10,'xp':20},
            {'at':11,'coins':15,'xp':30},{'at':11,'coins':10,'xp':20,'mastery':True}],
            vault=[{'at':1,'coins':5,'xp':10},{'at':3,'coins':10,'xp':20},{'at':5,'coins':10,'xp':20}],
            daily={'letter11':{'coins':10,'xp':20},'squad_vault':{'coins':10,'xp':20}},
            # Daily letter bonus needs fewer players on a medium letter; hard
            # letters are never the daily letter.
            letterDailyAt={'easy':8,'medium':7},
            # Harf Pasaportu milestones: letters completed with all eleven.
            passport=[{'at':5,'coins':20,'xp':40},{'at':10,'coins':30,'xp':60},
                {'at':20,'coins':50,'xp':100},{'at':'all','coins':100,'xp':200}],
            hintCosts={'flag':1,'league':1,'player':2},hintDailyLimit=6,
            archiveBonus={'at':5,'coins':30,'xp':50},leagueKnowledgePenalty=1))
    report=dict(version=catalog['version'],players=len(players),letters=len(letters),
       vaultClubs=len(active_clubs),puzzles=len(puzzles),
       leagues=dict(Counter(clubs[i]['league'] for i in active_clubs)),
       formations=dict(Counter(p['formation'] for p in puzzles)),
       difficulties=dict(Counter(p['difficulty'] for p in puzzles)),
       searchableClubs=sum(c['searchable'] for c in clubs.values()),
       mergedClubRows=sum('canonicalId' in c for c in clubs.values()))
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
