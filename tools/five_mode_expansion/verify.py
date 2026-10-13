"""Integrity of new content, redaction, identities and unchanged legacy contracts."""
import json,sqlite3,hashlib
from build import ROOT,build
private,public=build()
for path,data in [('functions/config/five_mode_expansion.json',private),('assets/data/five_mode_expansion.json',public)]:
 assert json.loads((ROOT/path).read_text())==data,path
new=private['journey']['journeys']
assert len(new)==8 and [j['id'] for j in new]==[f'PJ-{i}' for i in range(33,41)]
tasks=[t for j in new for t in j['tasks']]+private['ucl']+[t for c in private['nostalgia'] for t in c['tasks']]+private['international']+private['dynastyTasks']
assert len(tasks)==len({t['id'] for t in tasks})==51
assert [len(private[k]) for k in ['ucl','nostalgia','international','dynasties','dynastyTasks']]==[3,3,4,3,6]
con=sqlite3.connect(f"file:{ROOT/'assets/runtime/linkball_game_data_v4.sqlite'}?mode=ro",uri=True)
expected=['Pelé (Edson Arantes do Nascimento)','Diego Maradona','Ronaldo Nazário','Gianluigi Buffon','Gheorghe Hagi','Alex de Souza','Ricardo Quaresma','Burak Yılmaz']
for j,name in zip(new,expected):
 assert con.execute('select name from players where id=?',(j['playerId'],)).fetchone()==(name,)
 assert len(j['tasks'])==4
for t in tasks:
 opts={o.get('id',o.get('key')):o['label'] for o in t['options']}
 assert len(opts)==len(t['options']) and len(set(opts.values()))==len(opts)
 assert len(t['answerKeys'])==t['requiredCount'] and set(t['answerKeys'])<=opts.keys()
 assert t['rewardPolicy']=='mode_default' and t['hint'] and t['result']['story'] and t['result']['sources']
 assert all(s['url'].startswith('https://') for s in t['result']['sources'])
 if t.get('type') not in ['timeline'] and t.get('interaction')!='order':
  assert len(opts)-len(t['answerKeys'])>=3,t['id']
 for a in t['answerKeys']:
  label=opts[a]
  if len(label)>3:assert label.casefold() not in (t.get('intro','')+' '+t.get('introNarrative','')+' '+t['hint']).casefold(),t['id']
for key in ['answerKeys','result','explanation','strongHint','sources','story']:
 assert '"'+key+'":' not in json.dumps(public),key
assert len(private['international'][0]['lineup']['rows'][0])==1
assert len(sum(private['international'][0]['lineup']['rows'],[]))==11
assert private['ucl'][1]['result']['penalties']==[2,0]
assert private['international'][2]['result']['events']==[{'label':l,'minute':m} for l,m in zip(['Pablo Barrera · ilk golü','Andrés Guardado','Pablo Barrera · ikinci golü','Giovani dos Santos'],['29','36','50','76'])]
# New matches cannot duplicate an existing date/team pair.
for base,key in [('ucl_catalog','ucl'),('international_catalog','international')]:
 old=json.loads((ROOT/f'functions/config/{base}.json').read_text())['matches']
 dates=[m['date'] for m in old+private[key]]
 for m in private[key]:assert dates.count(m['date'])==1,m['id']
# Byte hashes freeze every legacy catalog used by the five modes.
for name,digest in json.loads((ROOT/'tools/five_mode_expansion/legacy_hashes.json').read_text()).items():
 assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
print('PASS: 51 tasks, 8 canonical players, private answers, exact PDF totals, frozen legacy catalogs.')
