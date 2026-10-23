#!/usr/bin/env python3
"""Audit the bundled V4 snapshot; source approval is never inferred from density."""
import collections, hashlib, json, math, pathlib, re, sqlite3, sys, unicodedata
ROOT=pathlib.Path(__file__).resolve().parents[2]
DB=ROOT/'assets/runtime/linkball_game_data_v4.sqlite'
def key(s):
 s=s.lower().translate(str.maketrans({'ı':'i','ø':'o','ł':'l','đ':'d'}))
 return ''.join(x for x in unicodedata.normalize('NFKD',s) if x.isalnum())
c=sqlite3.connect(DB);c.row_factory=sqlite3.Row
players={str(r['id']):dict(r) for r in c.execute('select * from players where answer_eligible=1')}
rawclubs={str(r['id']):dict(r) for r in c.execute("select * from clubs where entity_type='SENIOR' and gameplay_eligible=1")}
def clubid(i):
 i=int(i)
 return str(i-1000000000) if i>=1000000000 and str(i-1000000000) in rawclubs else str(i)
clubs={i:p for i,p in rawclubs.items() if clubid(i)==i}
aliases=collections.defaultdict(set)
for i,p in players.items():aliases[key(p['name'])].add(i)
for r in c.execute('select * from player_aliases'):
 if str(r['player_id']) in players:aliases[key(r['alias'])].add(str(r['player_id']))
manual={'neymarjr':'neymar','pippoinzaghi':'filippoinzaghi','ronaldonazario':'ronaldo','sonheungmin':'heungminson'}
def pid(name):
 ids=aliases[key(name)] or aliases[manual.get(key(name),'')]
 return next(iter(ids)) if len(ids)==1 else None
public={i:{'id':i,'playerId':i,'name':p['name'],'country':p['country'] or '', 'position':p['position'] or ''} for i,p in players.items()}
metrics={};audit={};dbhash=hashlib.sha256(DB.read_bytes()).hexdigest()
reviews=json.loads((ROOT/'tools/choice/reviews.json').read_text())
specs=[('peak_market_value','Zirve Piyasa Değeri','players','EUR'),('career_goals','Kariyer Golü','players','gol'),('international_caps','Millî Maç','profiles','maç'),('international_goals','Millî Takım Golü','profiles','gol'),('appearances','Kaydedilmiş Maç','player_stats','maç'),('assists','Kaydedilmiş Asist','player_stats','asist'),('ucl_appearances','Kaydedilmiş UCL Maçı','player_stats','maç'),('big5_appearances','Kaydedilmiş Big-5 Maçı','player_stats','maç')]
for field,label,table,unit in specs:
 groups=collections.defaultdict(list);missing=invalid=total=0;values=[]
 review=reviews.get('metrics',{}).get(field,{})
 for row in c.execute('select * from '+table):
  r=dict(row);i=str(r['id'] if table=='players' else r['player_id'])
  if i not in players:continue
  total+=1;v=r[field]
  if v is None:missing+=1;continue
  if not isinstance(v,(int,float)) or not math.isfinite(v) or v<0:invalid+=1;continue
  if v==0 and i not in review.get('verifiedZeroIds',[]):missing+=1;continue
  if table=='player_stats':
   if r['coverage_class']!='LIKELY_COMPLETE_MODERN_WINDOW' or not r['coverage_first_year'] or not r['coverage_last_year']:continue
   scope=f"recorded:{r['coverage_first_year']}:{r['coverage_last_year']}:{r['coverage_class']}"
  elif table=='profiles':
   if r['identity_confidence']!='HIGH_EXACT_NORMALIZED_NAME' or not r['source_last_season']:continue
   scope=f"senior-national:snapshot-season-{r['source_last_season']}"
  else:scope='legacy-scope-unverified'
  values.append(v);groups[scope].append({'id':i,'value':v})
 viable={scope:rows for scope,rows in groups.items() if len(rows)>=120 and len({r['value'] for r in rows})>=7}
 pairs=sum((len(rows)**2-sum(n*n for n in collections.Counter(r['value'] for r in rows).values()))//2 for rows in viable.values())
 reviewed=review.get('databaseSha256')==dbhash and review.get('sourceTable')==table and review.get('sourceColumn')==field and bool(review.get('sources')) and review.get('sampleVerified') is True and review.get('scopeVerified') is True
 gate=bool(viable) and pairs>=50 and reviewed
 reason='' if gate else ('Kaynak ve kapsam incelemesi bekleniyor.' if viable else 'Karşılaştırılabilir havuz yetersiz.')
 metrics[field]={'id':field,'label':label,'sourceTable':table,'sourceColumn':field,'unit':unit,'status':'ready' if gate else 'needs_review','gatePassed':gate,'reason':reason,'groups':viable if gate else {},'sources':review.get('sources',[])}
 audit[field]={'totalIdentities':total,'unknownCount':missing,'nullRate':round(missing/max(1,total),4),'invalidCount':invalid,'positiveCount':len(values),'distinctValues':len(set(values)),'comparableGroups':{k:len(v) for k,v in viable.items()},'eligibleCount':sum(map(len,viable.values())),'distinctPairs':pairs,'tieRate':round(sum(n*(n-1)//2 for n in collections.Counter(values).values())/max(1,len(values)*(len(values)-1)//2),4),'sourceReviewed':reviewed,'gatePassed':gate,'reason':reason}
# Independent, source-attributed historical criteria. Original eight gates stay intact.
from verified_snapshot import load_metrics
verified_metrics, verified_audit = load_metrics(players, aliases)
metrics.update(verified_metrics); audit.update(verified_audit)
files=['prime_battles_32','era_clash_64','position_rivalry_64','super_lig_legends_64','ucl_dynasties_64','historical_season_kings_64','turkish_peak_squads_64','city_derby_rivalries_64']
titles=['Zirve Sezonlar','Efsane vs Modern','Rol Kapışması','Süper Lig Efsaneleri','Avrupa Hanedanlıkları','Tarihsel Sezon Kralları','Türk Futbolunun Zirve Kadroları','Şehir ve Derbi Rekabetleri']
themes={};candidates={};unresolved=[]
pattern=re.compile(r'BracketCandidate\((.*?)\),',re.S)
fields=re.compile(r'''(id|name|badge|highlight):\s*('(?:\\.|[^'])*'|"(?:\\.|[^"])*")''')
clubnames=collections.defaultdict(set)
for i,p in clubs.items():clubnames[key(p['name'])].add(i)
for index,file in enumerate(files):
 text=(ROOT/f'lib/data/{file}_data.dart').read_text();rows=[];typ='player' if index<4 else 'club'
 for raw in pattern.findall(text):
  f=dict(fields.findall(raw))
  if not all(k in f for k in ['id','name','badge','highlight']):continue
  id,name,badge,highlight=[f[k][1:-1].replace("\\'","'").replace('\\\\','\\') for k in ['id','name','badge','highlight']]
  entity=pid(name) if typ=='player' else (next(iter(clubnames[key(name)])) if len(clubnames[key(name)])==1 else None)
  cid=file+'__'+id;review=reviews.get('candidates',{}).get(cid,{})
  verified=bool(entity and review.get('sources') and review.get('seasonKey')==badge and len(review.get('facts',[]))>=2)
  if not entity:unresolved.append(cid)
  candidates[cid]={'id':cid,'legacyId':id,'name':name,'type':typ,'entityId':entity,'playerId':entity if typ=='player' else None,'seasonKey':badge,'badge':badge if verified else '', 'legacyHighlight':highlight,'verifiedFacts':review.get('facts',[]) if verified else [],'sources':review.get('sources',[]),'contentStatus':'verified' if verified else 'needs_review'}
  rows.append(cid)
 assert len(rows)==len(set(rows)) and len(rows) in (64,128),(file,len(rows))
 formats={}
 for size in [16,32,64,128]:
  if size>len(rows):continue
  stride=len(rows)//size
  chosen=[x for pair in range(0,len(rows)//2,stride) for x in rows[pair*2:pair*2+2]]
  assert len(chosen)==size
  formats[str(size)]={'candidateIds':chosen,'approved':all(candidates[i]['contentStatus']=='verified' for i in chosen) and reviews.get('formats',{}).get(f'{file}:{size}') is True}
 themes[file]={'id':file,'title':titles[index],'type':typ,'candidateCount':len(rows),'formats':formats,'status':'ready' if all(f['approved'] for f in formats.values()) else 'needs_review'}
links=collections.defaultdict(set)
for r in c.execute('select player_id,club_id from player_clubs where trust>=2'):links[str(r['player_id'])].add(clubid(r['club_id']))
turkish={i for i,p in clubs.items() if key(p.get('competition') or '')=='superlig'}
ordered=sorted(players,key=lambda i:((players[i]['selection_rank'] or 999999),i))
personal={'favorites':{'id':'favorites','label':'Genel Favoriler','ids':ordered[:600]},'super_lig':{'id':'super_lig','label':'Süper Lig Kariyerleri','ids':[i for i in ordered if links[i]&turkish][:400]},'keepers':{'id':'keepers','label':'Kaleciler','ids':[i for i in ordered if key(players[i]['position'] or '') in ('goalkeeper','gk','kaleci')][:300]},'forwards':{'id':'forwards','label':'Forvetler','ids':[i for i in ordered if any(k in key(players[i]['position'] or '') for k in ['forward','striker','attack'])][:400]}}
used={i for t in personal.values() for i in t['ids']}|{p['playerId'] for p in candidates.values() if p['playerId']}
used.update(r['id'] for m in metrics.values() for rows in m['groups'].values() for r in rows)
body={'schema':1,'databaseSha256':dbhash,'metrics':metrics,'players':{i:p for i,p in public.items() if i in used},'themes':themes,'candidates':candidates,'personal':personal,'policy':{'this_or_that':{'16':2,'32':3,'64':4,'128':5},'blind_ranking':{'5':2,'10':3}}}
body['version']='choice-v1-'+hashlib.sha256(json.dumps(body,sort_keys=True).encode()).hexdigest()[:16]
report={'version':body['version'],'databaseSha256':dbhash,'metrics':audit,'themes':{k:{'count':v['candidateCount'],'formats':{n:{'count':len(f['candidateIds']),'approved':f['approved']} for n,f in v['formats'].items()}} for k,v in themes.items()},'unresolvedCandidates':unresolved,'unreviewedHighlights':sum(x['contentStatus']!='verified' for x in candidates.values()),'personalPools':{k:len(v['ids']) for k,v in personal.items()},'note':'Density and structural checks are not external source or editorial approval.'}
for path,obj in [('functions/config/choice_catalog.json',body),('docs/choice/data-audit.json',report)]:
 text=json.dumps(obj,ensure_ascii=False,separators=(',',':'))+'\n';p=ROOT/path
 if '--check' in sys.argv:assert p.read_text()==text,path+' drift'
 else:p.write_text(text)
print(body['version'], 'reviewed metrics',sum(m['gatePassed'] for m in metrics.values()),'legacy candidates',len(candidates))
