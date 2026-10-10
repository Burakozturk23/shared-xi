"""Offline integrity, spoiler, club identity and redacted export gate."""
import json,pathlib,collections,sqlite3,datetime
ROOT=pathlib.Path(__file__).resolve().parents[2]
a=json.loads((ROOT/'assets/data/ucl_moments_v2.json').read_text())
s=json.loads((ROOT/'functions/config/ucl_catalog.json').read_text())
assert len(a['matches'])==len(s['matches'])==34
assert len({m['id'] for m in s['matches']})==34
assert collections.Counter(m['type'] for m in a['matches'])=={'goal':10,'hero':9,'xi':7,'timeline':4,'score':4}
assert len([m for m in s['matches'] if m['verification']['statsBombMatchId']])==15
con=sqlite3.connect(f"file:{ROOT/'assets/runtime/linkball_game_data_v4.sqlite'}?mode=ro",uri=True)
for server,public in zip(s['matches'],a['matches']):
 assert public=={k:v for k,v in server.items() if k not in ('answerKeys','result','verification')}
 datetime.date.fromisoformat(public['date'])
 for club in ('home','away'): assert con.execute('select id from clubs where id=?',(public[club]['id'],)).fetchone()
 ids=[o['id'] for o in public['options']]
 assert len(set(ids))==len(ids)
 assert all(k in ids for k in server['answerKeys'])
 assert all(x['url'].startswith('https://') for x in server['result']['sources'])
 if public['type']=='xi':
  names=sum(public['lineup']['rows'],[])
  assert len(names)==11 and names.count('?')==1
 if public['type']=='timeline': assert len(ids)>=3 and ids!=server['answerKeys']
 for key in server['answerKeys']:
  label=next(o['label'] for o in public['options'] if o['id']==key)
  assert all(label.casefold() not in public[k].casefold() for k in ('title','intro','hint'))
assert s['matches'][15]['date']=='2013-03-12'
assert s['matches'][0]['result']['penalties']==[2,3]
assert s['matches'][21]['result']['penalties']==[3,4]
assert s['matches'][31]['result']['penalties']==[5,3]
assert 'deplasman golü' in s['matches'][7]['result']['story']
assert 'deplasman golü' in s['matches'][16]['result']['story']
assert s['matches'][24]['competition']=='Avrupa Şampiyon Kulüpler Kupası'
e=s['economy']
assert 34*e['match']['coins']+sum(m['coins'] for m in e['milestones'])==482
assert 34*e['match']['xp']+sum(m['xp'] for m in e['milestones'])==1005
print('UCL integrity OK: 34 matches, 5 mechanics, 15 provider references, 7 starting XIs, 482 coin / 1005 XP')
