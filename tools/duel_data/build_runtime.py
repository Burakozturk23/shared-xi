"""Build the additive, source-traced duel package without changing canonical V4.

No numeric V4 field or roster membership is silently promoted to a career fact.
Run offline after collect_sources.py. --check verifies committed outputs.
"""
import argparse
from collections import Counter, defaultdict
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
DB = ROOT/'assets/runtime/linkball_game_data_v4.sqlite'
CUTOFF = '2025-12-31'
VERSION = 'duel-2026-10-15.1'
CORE = ['F01','F02','F06','F07','F08','F10','F12','F13','F14','F15','F16','F17','F18','F22']
EXTRA = ['F20','F21','F24','F25','F29','T01','T02','T07','T09','T10']
GOALKEEPER_ZERO = ['F12','F13','F14','F16','F18','F22']
POSITIONS = {'Goalkeeper':'GK','GK':'GK','G':'GK','Defender':'DEF','DF':'DEF','D':'DEF',
             'Midfield':'MID','MF':'MID','M':'MID','Attack':'FWD','FW':'FWD','F':'FWD'}
TITLES = {
 'F01':'En çok farklı kulüpte oynamış kadro','F02':'En çok farklı lig ülkesinde oynamış kadro',
 'F06':'En uzun / en kısa kadro','F07':'En genç / en yaşlı kadro','F08':'Zirve değeri en yüksek kadro',
 'F10':'En çok resmî kulüp maçına çıkmış kadro','F12':'En çok kulüp golü atan kadro',
 'F13':'En çok kulüp asisti yapan kadro','F14':'Kulüp gol + asist toplamı en yüksek kadro',
 'F15':'En çok A millî maça çıkmış kadro','F16':'A millî takımda en çok gol atan kadro',
 'F17':'En çok Şampiyonlar Ligi maçına çıkmış kadro','F18':'Şampiyonlar Ligi golü en yüksek kadro',
 'F22':'Tek kulüpteki gol toplamları en yüksek kadro','F20':'Beş büyük ligde en çok maç',
 'F21':'Tek kulüpte en çok maç','F24':'En çok lig şampiyonluğu','F25':'En çok ana ulusal kupa',
 'F29':'En çok farklı kulüple lig/ana kupa şampiyonluğu','T01':'En çok farklı başantrenörle oynama',
 'T02':'Tek başantrenörle en çok maç','T07':'Tek başantrenörle ortak lig/ana kupa şampiyonluğu',
 'T09':'Açıklanan başantrenörle en çok maç','T10':'En çok Avrupa şampiyonu başantrenörle oynama'}
NEEDS = {
 'F01':['complete_senior_club_appearances'], 'F02':['complete_domestic_league_participation','league_country_mapping'],
 'F06':['exact_height_cm_at_cutoff'], 'F07':['exact_birth_date','active_at_cutoff'],
 'F08':['dated_single_provider_peak_eur'], 'F10':['complete_senior_club_appearances'],
 'F12':['complete_club_goals'], 'F13':['complete_single_provider_club_assists'],
 'F14':['F12','F13','identical_match_scope'], 'F15':['complete_senior_caps'],
 'F16':['complete_senior_goals','senior_participation'], 'F17':['complete_ucl_main_appearances_1992_onwards'],
 'F18':['complete_ucl_main_goals_1992_onwards','ucl_participation'],
 'F22':['complete_goals_for_all_career_clubs'], 'F20':['complete_big5_league_appearances'],
 'F21':['complete_appearances_for_all_career_clubs'], 'F24':['approved_competition_list','player_title_entitlements'],
 'F25':['approved_competition_list','player_title_entitlements'], 'F29':['F24','F25'],
 'T01':['complete_player_head_coach_match_links'], 'T02':['complete_player_head_coach_match_counts'],
 'T07':['player_and_coach_joint_title_entitlements'], 'T09':['specified_coach_complete_match_counts'],
 'T10':['complete_player_head_coach_match_links','coach_european_titles']}
SB_CLUBS = {38:148,24:31,39:985,217:131,220:418,224:506,129:162,256:720,806:610,238:46}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def norm(value):
    value=(value or '').casefold().translate(str.maketrans({'ı':'i','ø':'o','ł':'l','đ':'d','ß':'ss'}))
    return re.sub(r'[^a-z0-9]+',' ',''.join(c for c in unicodedata.normalize('NFKD',value) if not unicodedata.combining(c))).strip()


def country(value):
    aliases={'turkey':'turkiye','republic of ireland':'ireland','korea republic':'south korea',
             'cote d ivoire':'ivory coast','congo dr':'dr congo','united states of america':'united states'}
    value=norm(value)
    return aliases.get(value,value)


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def dumps(data):
    return json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(',',':'))+'\n'


def source_id(path):
    return 'receipt:'+path.stem


def build():
    receipt_paths = list((HERE/'sources').glob('*.json'))
    if len(receipt_paths) != 24:
        raise ValueError('Expected all 17 ESPN and 7 StatsBomb source receipts')
    for path in receipt_paths:
        receipt = read(path)
        if not re.fullmatch(r'[0-9a-f]{64}', receipt['sha256']):
            raise ValueError(f'Invalid source receipt: {path.name}')
    c=sqlite3.connect(f'file:{DB}?mode=ro',uri=True); c.row_factory=sqlite3.Row
    players={r['id']:dict(r) for r in c.execute('select p.*,pr.birth_year from players p left join profiles pr on pr.player_id=p.id')}
    clubs={r['id']:r['name'] for r in c.execute('select id,name from clubs')}
    links=set(tuple(r) for r in c.execute('select player_id,club_id from player_clubs'))
    names=defaultdict(set)
    for pid,p in players.items(): names[norm(p['name'])].add(pid)
    for r in c.execute('select player_id,alias from player_aliases'): names[norm(r['alias'])].add(r['player_id'])
    # Existing reviewed source-ID mappings; conflicting IDs remain unresolved.
    espn=defaultdict(set)
    for path in sorted((ROOT/'tools/data_platform_v4/patches').glob('*.json')):
        data=read(path)
        if not isinstance(data,list): continue
        for r in data:
            sid=r.get('sourcePlayerId')
            pid=r.get('playerId')
            if not sid: continue
            if r.get('status')=='new_player': pid=3_000_000_000+int(sid)
            if pid in players and r.get('status') in ['new_player','existing','add_link']:
                espn[str(sid)].add(pid)

    sources={}; observations=[]; unresolved=[]; matched_profiles=set(); profile_conflicts=[]
    for path in sorted((HERE/'sources').glob('espn_*.json')):
        doc=read(path); sid=source_id(path)
        sources[sid]={k:doc[k] for k in ['url','sha256','retrievedAt','provider']}
        sources[sid]['receiptSha256']=digest(path)
        for a in doc['athletes']:
            source_player=str(a['id']); dob=(a.get('dateOfBirth') or '')[:10]
            try: birth=date.fromisoformat(dob)
            except ValueError: continue
            aliases={norm(a.get(k)) for k in ['displayName','fullName']}-{''}
            candidates=espn.get(source_player,set()) or set().union(*(names[n] for n in aliases))
            valid=[pid for pid in candidates if players[pid]['birth_year']==birth.year
                   and country(players[pid]['country'])==country(a.get('citizenship'))
                   and pid in set().union(*(names[n] for n in aliases))]
            if len(valid)!=1:
                unresolved.append(dict(provider='espn',sourcePlayerId=source_player,name=a.get('displayName'),candidates=sorted(candidates),reason='identity_not_unique_or_context_mismatch'))
                continue
            pid=valid[0]; matched_profiles.add(pid)
            position=POSITIONS.get((a.get('position') or {}).get('abbreviation'))
            if position!=POSITIONS.get(players[pid]['position']):
                profile_conflicts.append(dict(playerId=pid,field='position',canonical=players[pid]['position'],observed=position))
            # DOB is immutable identity data, but not proof of activity at 2025-12-31.
            observations.append(dict(playerId=pid,field='birth_date',value=dob,source=sid,sourcePlayerId=source_player,
                status='source_observed',identityStatus='matched_name_birthyear_country',observedAt=doc['retrievedAt']))
            # ESPN height is inches (displayHeight is feet/inches). Never treat it as cm,
            # round it into a precise historical height, or overwrite an exact cm source.
            if isinstance(a.get('height'),(int,float)) and 50 <= a['height'] <= 90:
                observations.append(dict(playerId=pid,field='height_inches',value=a['height'],source=sid,
                    status='source_observed',display=a.get('displayHeight'),observedAt=doc['retrievedAt'],
                    blockedForScoring=['historical_cutoff_unverified','rounded_imperial_measurement']))
            observations.append(dict(playerId=pid,field='citizenship',value=a.get('citizenship'),source=sid,
                status='source_observed',observedAt=doc['retrievedAt'],blockedForCondition=['football_country_not_established']))

    # Independent dates with the same source ID must not be silently last-write-wins.
    dobs=defaultdict(set)
    for o in observations:
        if o['field']=='birth_date': dobs[o['playerId']].add(o['value'])
    for o in observations:
        if o['field']=='birth_date' and len(dobs[o['playerId']])>1: o['status']='conflicting'

    appearances=[]; unused=0; manager_entities={}; sb_players={}; matches=[]
    for path in sorted((HERE/'sources').glob('statsbomb_*.json')):
        doc=read(path); sid=source_id(path)
        sources[sid]={k:doc[k] for k in ['url','sha256','retrievedAt','provider']}
        sources[sid]['receiptSha256']=digest(path)
        for m in doc['matches']:
            mid=m['match_id']; lineup_path=ROOT/f'assets/history/lineups/{mid}.json'
            if not lineup_path.exists(): continue
            if m['match_date']>CUTOFF: continue
            lineup_sid=f'statsbomb:lineups:{mid}'
            sources[lineup_sid]=dict(url=f'https://github.com/hudl/open-data/blob/master/data/lineups/{mid}.json',sha256=digest(lineup_path),provider='statsbomb',retrievedAt=doc['retrievedAt'])
            matches.append(dict(id=f'statsbomb:{mid}',date=m['match_date'],metadataSource=sid,lineupSource=lineup_sid))
            for team in read(lineup_path):
                tid=team['team_id']; club_id=SB_CLUBS[tid]
                side=next(t for t in [m['home_team'],m['away_team']] if t.get('home_team_id',t.get('away_team_id'))==tid)
                if len(side.get('managers',[]))!=1: raise ValueError('Ambiguous head coach')
                manager=side['managers'][0]; coach_key=f"statsbomb:coach:{manager['id']}"
                manager_entities[coach_key]=dict(key=coach_key,name=manager['name'],birthDate=manager.get('dob'),role='head_coach',canonicalId=None,source=sid)
                for p in team['lineup']:
                    player_key=f"statsbomb:player:{p['player_id']}"
                    ns={norm(p.get('player_name')),norm(p.get('player_nickname'))}-{''}
                    candidates=set().union(*(names[n] for n in ns))
                    valid=[pid for pid in candidates if country(players[pid]['country'])==country(p['country']['name']) and (pid,club_id) in links]
                    pid=valid[0] if len(valid)==1 else None
                    prior=sb_players.get(player_key)
                    if prior and prior['canonicalId'] is not None and pid is not None and prior['canonicalId']!=pid:
                        raise ValueError('Conflicting StatsBomb identity')
                    sb_players[player_key]=dict(key=player_key,name=p['player_name'],canonicalId=pid if pid is not None else (prior or {}).get('canonicalId'),identityStatus='matched_name_country_club' if pid is not None else 'unmapped')
                    if not p.get('positions'):
                        unused+=1; continue
                    appearances.append(dict(matchId=f'statsbomb:{mid}',date=m['match_date'],sourcePlayerKey=player_key,
                        playerId=pid,coachKey=coach_key,clubId=club_id,role='head_coach',participated=True,
                        sources=[sid,lineup_sid],coverage='single_official_match',status='source_verified',
                        positions=[x['position_id'] for x in p['positions']]))
    # Canonical mappings cannot propagate silently to previously unmapped match rows.
    # Each row retains the evidence/context used for that match.
    research=read(HERE/'reviewed_facts.json')
    if research['baseDatabaseSha256']!=digest(DB): raise ValueError('Research base hash mismatch')
    research_sources={s['id']:s for s in research['sources']}
    sources.update(research_sources)
    buffon=next(f for f in research['facts'] if f['metric']=='player_senior_caps')
    assert players[5023]['name']=='Gianluigi Buffon' and buffon['value']==176
    # FIGC expressly documents his final senior career, not just a live 2018 total.
    verified=[dict(playerId=5023,criterionId='F15',value=176,unit='count',scopeId='F15:senior_caps:v1',
                   cutoff=CUTOFF,status='verified',coverage='complete',finalCareer=True,
                   sources=buffon['sources'],evidenceCutoff=buffon['cutoff'])]
    conditions=[dict(playerId=5023,kind='country',key='Italy',status='verified',cutoff=CUTOFF,
                     sources=buffon['sources'],meaning='senior_national_team')]
    approved = read(HERE/'approved_metrics.json')
    if approved['schemaVersion'] != 1:
        raise ValueError('Unsupported metric review schema')
    sources.update(approved['sources'])
    for fact in approved['metrics']:
        player = players[fact['playerId']]
        if (player['name'], player['country'], player['position']) != (
                fact['expectedName'], fact['expectedCountry'], fact['expectedPosition']):
            raise ValueError('Reviewed metric canonical identity mismatch')
        if (fact['cutoff'] != CUTOFF or fact['retiredBy'] > CUTOFF or
                not fact['finalCareer'] or fact['coverage'] != 'complete' or
                fact['status'] != 'verified' or fact['criterionId'] not in ['F15','F16','F18'] or
                not fact['sources'] or any(s not in sources for s in fact['sources'])):
            raise ValueError('Incomplete reviewed career evidence')
        verified.append({k:v for k,v in fact.items() if not k.startswith('expected')})
        if fact['criterionId'] == 'F15':
            conditions.append(dict(playerId=fact['playerId'],kind='country',key=player['country'],
                status='verified',cutoff=CUTOFF,sources=fact['sources'],meaning='senior_national_team'))
    for a in appearances:
        if a['playerId'] is not None:
            conditions.append(dict(playerId=a['playerId'],kind='club',key=str(a['clubId']),status='verified',
                cutoff=CUTOFF,sources=a['sources'],matchId=a['matchId'],meaning='official_senior_appearance'))
    # No metric is enabled until pool, condition paths and gameplay acceptance are reviewed.
    criteria=[]
    for cid in CORE+EXTRA:
        facts=[f for f in verified if f['criterionId']==cid]
        pos=Counter(POSITIONS.get(players[f['playerId']]['position']) for f in facts)
        criteria.append(dict(id=cid,title=TITLES[cid],stage='core' if cid in CORE else 'expansion',
            scopeId=cid+':'+('senior_caps' if cid=='F15' else 'v1'),
            directions=['high','low'] if cid in ['F06','F07'] else ['high'],
            unit={'F06':'cm','F07':'days','F08':'EUR'}.get(cid,'count'),cutoff=CUTOFF,
            goalkeeperZeroAllowed=cid in GOALKEEPER_ZERO,requirements=NEEDS[cid],enabled=False,
            verifiedPlayers=len(facts),positions=dict(pos),
            blockers=['insufficient_verified_pool','condition_paths_not_approved','gameplay_acceptance_pending']))
    # A scope identifier is a closed contract, not free text.
    next(d for d in criteria if d['id']=='F15')['scopeId']='F15:senior_caps:v1'
    canonical_ids=set(matched_profiles)|{f['playerId'] for f in verified}|{a['playerId'] for a in appearances if a['playerId'] is not None}
    identities=[dict(id=pid,name=players[pid]['name'],position=POSITIONS.get(players[pid]['position']),
                     aliases=sorted({r[0] for r in c.execute('select alias from player_aliases where player_id=?',(pid,))})) for pid in sorted(canonical_ids)]
    raw_counts={}
    for field in ['goals','assists','appearances','ucl_appearances']:
        raw_counts[field]=c.execute(f'select count(*) from player_stats where {field} is not null').fetchone()[0]
    report=dict(version=VERSION,baseSha256=digest(DB),cutoff=CUTOFF,sourceReceipts=len(list((HERE/'sources').glob('*.json'))),
        matchedProfiles=len(matched_profiles),observations=len(observations),unresolvedProfiles=unresolved,
        profileConflicts=profile_conflicts,matchCount=len(matches),appearedRows=len(appearances),unusedRowsExcluded=unused,
        sourcePlayers=len(sb_players),sourceCoaches=len(manager_entities),
        sourcePairs=len({(a['sourcePlayerKey'],a['coachKey']) for a in appearances}),
        mappedAppearanceRows=sum(a['playerId'] is not None for a in appearances),
        verifiedScoringFacts=len(verified),enabledCriteria=0,rawStatRowsNotPromoted=raw_counts,
        criteria=[dict(id=x['id'],verifiedPlayers=x['verifiedPlayers'],blockers=x['blockers']) for x in criteria])
    data=dict(schemaVersion=1,version=VERSION,baseDatabaseSha256=digest(DB),cutoff=CUTOFF,
        formation=['GK','DEF','MID','DEF','MID','FWD'],minimumCatalog=120,
        minimumPositions={'GK':10,'DEF':20,'MID':20,'FWD':10},minimumConditionPlayers=6,
        criteria=criteria,players=identities,verifiedMetrics=verified,conditions=conditions,
        profileObservations=observations,matchAppearances=appearances,matches=matches,
        externalPlayers=list(sb_players.values()),externalCoaches=list(manager_entities.values()),
        reviewedEntities=research['entities'],reviewedFacts=research['facts'],sources=sources,
        acceptance={'conditionPathsApproved':False,'gameplayApproved':False})
    c.close()
    return data,report


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data,report=build();raw=dumps(data)
    manifest=dict(schemaVersion=1,version=VERSION,baseDatabaseSha256=data['baseDatabaseSha256'],
                  sha256=hashlib.sha256(raw.encode()).hexdigest(),bytes=len(raw.encode()),cutoff=CUTOFF)
    outputs={ROOT/'assets/data/duel/runtime.json':raw,ROOT/'functions/config/duel_runtime.json':raw,
             ROOT/'assets/data/duel/manifest.json':dumps(manifest),ROOT/'functions/config/duel_manifest.json':dumps(manifest),
             ROOT/'docs/duel-data/integration-audit.json':json.dumps(report,ensure_ascii=False,indent=2)+'\n'}
    for path,text in outputs.items():
        if args.check:
            if not path.exists() or path.read_bytes()!=text.encode('utf-8'): raise SystemExit(f'Stale generated file: {path.relative_to(ROOT)}')
        else:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(text.encode('utf-8'))
    print(json.dumps({k:v for k,v in report.items() if k not in ['unresolvedProfiles','profileConflicts','criteria']},ensure_ascii=False))


if __name__=='__main__': main()
