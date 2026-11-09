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
# Statistics that passed the sample check in docs/choice/metric-review.md. Each row is filtered to
# values the check trusts: zeros are unknowns in this database, never real values.
KNOWN="(p.selection_rank<=3000 or p.peak_market_value>=15000000)"
SINCE="2012'den beri · 2025/26 sonrası maçlar dahil değil"
NATIONAL="Son veri 2025/26; güncel maçlar eksik olabilir"
def comp(cid,col,least=1,known=KNOWN):
 return f"select s.player_id id,s.{col} value from player_competition_stats s join players p on p.id=s.player_id where s.competition_id='{cid}' and s.{col}>={least} and {known}"
def prof(col,where):
 return f"select r.player_id id,r.{col} value from profiles r join players p on p.id=r.player_id where r.{col} is not null and {where} and {KNOWN}"
TALL={'easy':[10,99],'normal':[6,15],'hard':[4,9],'master':[3,6]}
AGE={'easy':[8,99],'normal':[4,12],'hard':[2,6],'master':[1,3]}
MORE={'higherLabel':'Daha çok','lowerLabel':'Daha az'}
specs=[
 ('peak_market_value','En yüksek piyasa değeri','Piyasa','EUR',"select p.id id,p.peak_market_value value from players p join profiles r on r.player_id=p.id where p.peak_market_value>=1000000 and r.birth_year>=1983 and "+KNOWN,'1983 ve sonrası doğan oyuncular; önceki yılların değerleri eksik',{}),
 ('international_caps','Millî maç','Millî takım','maç',prof('international_caps',"r.international_caps>=5 and r.identity_confidence='HIGH_EXACT_NORMALIZED_NAME'"),NATIONAL,{**MORE,'minGap':8}),
 ('international_goals','Millî gol','Millî takım','gol',prof('international_goals',"r.international_goals>=1 and r.identity_confidence='HIGH_EXACT_NORMALIZED_NAME'"),NATIONAL,{**MORE,'minGap':3}),
 ('ucl_goals','Şampiyonlar Ligi golü','Avrupa','gol',comp('CL','goals'),SINCE,MORE),
 ('ucl_appearances','Şampiyonlar Ligi maçı','Avrupa','maç',comp('CL','appearances',5),SINCE,{**MORE,'minGap':4}),
 ('pl_goals','Premier League golü','Ligler','gol',comp('GB1','goals'),SINCE,MORE),
 ('laliga_goals','LaLiga golü','Ligler','gol',comp('ES1','goals'),SINCE,MORE),
 ('seriea_goals','Serie A golü','Ligler','gol',comp('IT1','goals'),SINCE,MORE),
 ('bundesliga_goals','Bundesliga golü','Ligler','gol',comp('L1','goals'),SINCE,MORE),
 ('ligue1_goals','Ligue 1 golü','Ligler','gol',comp('FR1','goals'),SINCE,MORE),
 ('super_lig_goals','Süper Lig golü','Ligler','gol',comp('TR1','goals',1,'p.selection_rank<=12000'),SINCE,MORE),
 ('height_cm','Boy','Oyuncu','cm',prof('height_cm','r.height_cm between 150 and 210'),'Boy bilgisi kaynağa göre 1-2 cm değişebilir',{'higherLabel':'Daha uzun','lowerLabel':'Daha kısa','minGap':3,'absBands':TALL}),
 ('birth_year','Doğum yılı','Oyuncu','',prof('birth_year','r.birth_year between 1950 and 2012'),'Aynı yıl doğanlar karşılaştırılmaz',{'higherLabel':'Daha genç','lowerLabel':'Daha yaşlı','minGap':1,'absBands':AGE}),
]
for field,label,group,unit,sql,scope_label,extra in specs:
 review=reviews.get('metrics',{}).get(field,{})
 rows=[]
 for row in c.execute(sql):
  i=str(row['id'])
  if i in players and isinstance(row['value'],(int,float)) and math.isfinite(row['value']) and row['value']>0:rows.append({'id':i,'value':row['value']})
 rows.sort(key=lambda r:int(r['id']))
 viable=len(rows)>=120 and len({r['value'] for r in rows})>=7
 reviewed=review.get('databaseSha256')==dbhash and bool(review.get('sources')) and review.get('sampleVerified') is True
 assert viable and reviewed,(field,len(rows),reviewed)
 metrics[field]={'id':field,'label':label,'group':group,'unit':unit,'status':'ready','gatePassed':True,'reason':'','groups':{'all':rows},'sources':review['sources'],'scopeLabel':scope_label,'poolLabel':f'{len(rows)} oyuncu',**extra}
 audit[field]={'eligibleCount':len(rows),'distinctValues':len({r['value'] for r in rows}),'sampleNote':review.get('sampleNote','')}
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
