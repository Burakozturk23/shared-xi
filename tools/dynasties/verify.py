"""Reproducible content, spoiler, ordering and economy checks (no network)."""
from collections import Counter
import json
from pathlib import Path
from build_catalog import ROOT,build

private,public=build()
for path,data in [('functions/config/dynasties_catalog.json',private),('assets/data/dynasties_v2.json',public)]:
 assert json.loads((ROOT/path).read_text())==data,path
assert len(private['dynasties'])==16 and len(private['tasks'])==32
assert Counter(t['mechanic'] for t in private['tasks'])==dict(squad=8,timeline=7,trophies=7,tactics=5,records=5)
assert Counter(t['interaction'] for t in private['tasks'])==dict(single=15,multi=7,order=6,match=4)
for i,d in enumerate(public['dynasties'],1):
 assert d['id']==f'DY-{i:02}' and d['taskIds']==[f'DY-{i:02}-01',f'DY-{i:02}-02']
 assert set(d)=={'id','number','chapterId','club','period','title','intro','taskIds'}
 assert d['chapterId']==(1 if i<=8 else 2)
for t,p in zip(private['tasks'],public['tasks']):
 assert set(p)=={'id','number','dynastyId','stage','contentVersion','mechanic','interaction','title','prompt','hint','options','requiredCount','slots'}
 ids=[o['id'] for o in t['options']];labels=[o['label'] for o in t['options']]
 assert len(ids)==len(set(ids))==len(set(labels))
 assert len(t['answerKeys'])==t['requiredCount']==len(set(t['answerKeys']))
 assert set(t['answerKeys'])<=set(ids)
 assert t['result']['sources'] and all(s['url'].startswith('https://') for s in t['result']['sources'])
 if t['interaction']=='order':assert ids!=t['answerKeys'] and len(ids)==t['requiredCount']
 if t['interaction']=='match':assert len(t['slots'])==t['requiredCount'] and len(t['slots'])==len(set(t['slots']))
 if t['interaction']=='single':assert t['requiredCount']==1
 if t['interaction']=='multi':assert 1<t['requiredCount']<len(ids)
 for o in t['options']:
  if o['id'] in t['answerKeys'] and len(o['label'])>3:
   d=public['dynasties'][(t['number']-1)//2]
   assert o['label'].casefold() not in (' '.join([p['title'],p['hint'],d['title'],d['intro']])).casefold(),t['id']
# Anchors for historically sensitive data, not inferred from the public option order.
def answers(n):
 t=private['tasks'][n-1];return [next(o['label'] for o in t['options'] if o['id']==a) for a in t['answerKeys']]
assert answers(1)==['Sergio Busquets'] and answers(4)==['Isco']
assert answers(11)==['Reims · Paris finali','Fiorentina','Milan','Reims · Stuttgart finali','Eintracht Frankfurt']
assert answers(19)==['1975/76','1976/77','1978/79','1979/80','1980/81','1983/84']
assert answers(22)==['Mário Coluna']
assert answers(24)==['Juninho Pernambucano','Sidney Govou','Grégory Coupet']
assert answers(29)==['Franz Beckenbauer','Sepp Maier','Gerd Müller']
assert answers(32)==['Bruce Grobbelaar']
e=private['economy']
assert 32*e['task']['coins']+sum(m['coins'] for m in e['milestones'])==456
assert 32*e['task']['xp']+sum(m['xp'] for m in e['milestones'])==1015
assert [m['count'] for m in e['milestones']]==[4,8,12,16]
# No old route can reach the stale named-answer pack.
assert 'StoryJourneyPage' not in (ROOT/'lib/screens/dynasties_part_selection_page.dart').read_text()
print('Dynasties verified: 16 eras, 32 tasks, 5 mechanics, private answers, 456 Coin / 1015 XP.')
