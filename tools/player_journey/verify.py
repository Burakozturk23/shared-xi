"""Check identities, task shape, deterministic pack generation and spoiler copy."""
import json, sqlite3, subprocess, sys, unicodedata
from pathlib import Path
root=Path(__file__).resolve().parents[2]
chapters = [
 ('one', 'chapter_1_goat', ['messi','ronaldo','ronaldinho','modric','zidane','kaka','benzema','maldini']),
 ('two', 'chapter_2_underdogs', ['vardy','kante','drogba','arda_turan','ozil','eriksen','salah','falcao']),
 ('three', 'chapter_3_architects', ['ibrahimovic','de_bruyne','lewandowski','haaland','bale','neymar','neuer','ramos']),
]
journeys=[]
for number, chapter_id, ids in chapters:
 path=root/f'assets/data/player_journey_chapter_{number}.json'
 original=path.read_bytes()
 subprocess.run([sys.executable,str(Path(__file__).with_name(f'build_chapter_{number}.py'))],check=True)
 assert path.read_bytes()==original, f'Regenerate chapter {number} before committing'
 pack=json.loads(original)
 assert pack['version']==2 and pack['chapterId']==chapter_id
 assert [j['id'] for j in pack['journeys']]==ids
 journeys.extend(pack['journeys'])
assert len({j['id'] for j in journeys}) == 24
def key(s):return ''.join(c for c in unicodedata.normalize('NFKD',s.casefold()) if c.isalnum())
with sqlite3.connect(root/'assets/runtime/linkball_game_data_v4.sqlite') as c:
 for j in journeys:
  assert c.execute('select name from players where id=?',(j['playerId'],)).fetchone()==(j['name'],),j['id']
  assert len(j['tasks'])==4
  for i,t in enumerate(j['tasks']):
   assert t['id']==f'{j["id"]}_v2_{i+1}'
   opts={o['key']:o for o in t['options']}
   assert len(opts)==len(t['options']) and len(opts)>=3
   assert set(t['answerKeys'])<=opts.keys() and len(set(t['answerKeys']))==len(t['answerKeys'])
   if t['type']=='timeline':assert len(t['answerKeys'])==len(opts)==t['requiredCount']
   elif t['type']=='teammate':assert t['requiredCount']==2 and len(t['answerKeys'])>=2
   else:assert t['requiredCount']==len(t['answerKeys'])==1
   for o in opts.values():
    if 'playerId' in o:
     assert c.execute('select name from players where id=?',(o['playerId'],)).fetchone()==(o['label'],),o
     assert o['playerId']!=j['playerId']
   public=key(t['title']+' '+t['hint']+' '+t['prompt'])
   for k in t['answerKeys']:
    assert key(opts[k]['label']) not in public, (t['id'],'answer in pre-solve copy')
   assert t['hint'] and t['explanation'] and j['sources']
print('[PASS] Chapters 1–3: 24 canonical players, 96 valid tasks, no answer in pre-solve text.')
