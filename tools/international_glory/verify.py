"""Fail closed on catalog drift, spoilers, missing evidence and key edge cases."""
import json, collections, hashlib
from pathlib import Path
from build_catalog import build
R=Path(__file__).resolve().parents[2]
files=[R/'functions/config/international_catalog.json',R/'assets/data/international_glory_v2.json']
before=[p.read_bytes() for p in files];build();assert before==[p.read_bytes() for p in files], 'Regenerate catalog and review changes'
private,public=[json.loads(p.read_text()) for p in files]
ms=private['matches'];assert len(ms)==40 and len({m['id'] for m in ms})==40
assert collections.Counter(m['chapterId'] for m in ms)=={1:10,2:10,3:10,4:10}
assert collections.Counter(m['type'] for m in ms)=={'critical':12,'penalty':9,'timeline':7,'route':7,'xi':5}
allowed={'id','number','contentVersion','chapterId','date','competition','round','home','away','title','intro','type','difficulty','prompt','clock','hint','options','slots','lineup'}
for m,p in zip(ms,public['matches']):
 assert set(p)<=allowed and m['id']==p['id']
 assert m['verification']['sources'] and all(s['url'].startswith('https://') for s in m['result']['sources'])
 opts={o['id']:o['label'] for o in m['options']};keys=m['answerKeys'];assert len(opts)==len(m['options']) and all(k in opts for k in keys)
 for k in keys if m['type'] != 'route' else []:
  assert all(opts[k] not in m[f] for f in ['title','intro','hint'])
 if m['type'] in ('timeline','route'):
  assert len(keys)==len(opts) and list(opts)!=keys
 else:assert len(opts)==4 and len(keys)==1
 if m['type']=='xi':
  names=sum(m['lineup']['rows'],[]);assert len(names)==11 and names.count('?')==1 and len(set(names))==11
 if m['type']=='route':assert len(m['slots'])==len(keys)
by={m['number']:m for m in ms}
assert by[16]['date'].startswith('2021') and by[16]['competition']=='EURO 2020'
assert by[22]['date'].startswith('2024') and by[22]['competition']=='AFCON 2023'
assert by[23]['date'].startswith('2022') and by[23]['competition']=='AFCON 2021'
assert by[3]['result']['scoreFT']=='2-2' and by[3]['result']['scoreET']=='3-3'
assert by[26]['result']['scoreET'] is None and by[26]['result']['penalties']==[4,2]
assert by[29]['result']['penalties'] is None and by[29]['clock']=='Maç içi penaltı'
assert by[39]['result']['events'][-1]=={'label':'Mert Müldür (KK)','minute':'76'}
assert by[35]['lineup']['rows'][0]==['?'] and by[37]['lineup']['rows'][1][-1]=='?'
for field,total in [('coins',640),('xp',1275)]:assert private['economy']['match'][field]*40+sum(m[field] for m in private['economy']['milestones'])==total
assert len(json.loads((R/'tools/international_glory/selective_audit.json').read_text())['files'])==6
print('International Glory: 40 matches, 4 chapters, 5 mechanics, 5 starting XIs, spoiler and economy gates passed.')
