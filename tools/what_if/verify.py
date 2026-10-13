"""Content gate: deterministic app/server pack, branch shape, spoilers and receipts."""
import json, subprocess, sys, unicodedata
from pathlib import Path
root=Path(__file__).resolve().parents[2]
client=root/'assets/data/what_if_v2.json'
before=client.read_bytes()
subprocess.run([sys.executable,str(Path(__file__).with_name('build_catalog.py'))],check=True)
assert before==client.read_bytes(),'Regenerate the catalog before committing'
p=json.loads(before)
assert p==json.loads((root/'functions/config/what_if_catalog.json').read_text())
def key(s):return ''.join(c for c in unicodedata.normalize('NFKD',s.casefold()) if c.isalnum())
assert len(p['scenarios'])==24 and len({s['id'] for s in p['scenarios']})==24
texts=[]; kinds=set()
for s in p['scenarios']:
 assert s['chapter'] in (1,2,3) and 1950<=s['year']<=2021
 assert s['sources'] and all(x['url'].startswith('https://') for x in s['sources'])
 assert len(s['intro'].split())>=30,s['id']
 assert {r['id'] for r in s['routes']}=={'real','alternate'}
 for r in s['routes']:
  assert r['kind']==('history' if r['id']=='real' else 'fiction')
  t=r['task'];kinds.add(t['type']);texts.append(r['ending'])
  opts={o['key']:o['label'] for o in t['options']}
  assert t['id']==s['id']+'__'+r['id']
  assert len(opts)==len(t['options'])>=3 and len(set(opts.values()))==len(opts)
  assert set(t['answerKeys'])<=opts.keys()
  assert len(r['ending'].split())>=30,(s['id'],r['id'])
  if t['type']=='timeline':assert set(t['answerKeys'])==set(opts)
  else:
   assert len(t['answerKeys'])==1
   public=key(s['intro']+' '+s['title']+' '+t['prompt']+' '+t['hint'])
   assert key(opts[t['answerKeys'][0]]) not in public,(s['id'],r['id'],'spoiler')
  assert t['hint']!=t['strongHint']
assert len(set(texts))==48
assert kinds=={'transfer','teammate','missing','timeline','connection'}
assert 24*10+3*60==420 and 24*25+3*100==900
print('[PASS] What If: 24 scenarios / 48 tasks and endings / 5 mechanics / spoiler and budget checks')
