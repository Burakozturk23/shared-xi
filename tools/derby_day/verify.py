"""Offline structural and V4 identity gates; source review is documented separately."""
import json,sqlite3
from collections import Counter
from urllib.parse import urlparse
from build_catalog import ROOT,HERE,build
private,public=build()
for path,data in zip(['functions/config/derby_day_catalog.json','assets/data/derby_day_v2.json'],[private,public]):assert json.loads((ROOT/path).read_text())==data,path
assert len(private['tasks'])==48 and len(private['countries'])==16
assert [t['clubIds'] for t in private['tasks'][:40]]==json.loads((HERE/'legacy_pairs.json').read_text())
assert len({tuple(sorted(t['clubIds'])) for t in private['tasks']})==48
assert Counter(t['mechanic'] for t in private['tasks'][40:])==dict(memory=3,identity=2,timeline=1,two_shirts=1,legend=1)
assert len({t['mechanic'] for t in private['tasks']})==5
for n,(t,p) in enumerate(zip(private['tasks'],public['tasks']),1):
    assert t['id']==f'DER-{n:02}'
    assert not {'answerKeys','result','verification','period','playerId'}&p.keys()
    ids=[o['id'] for o in t['options']]
    assert len(ids)==len(set(ids)) and set(t['answerKeys'])<=set(ids)
    assert len({o['label'] for o in t['options']})==len(ids)
    assert len(t['answerKeys'])==t['requiredCount']
    assert len(ids)==(3 if t['interaction']=='order' else 4)
    if t['interaction']=='order':assert ids!=t['answerKeys']
    labels={o['id']:o['label'] for o in t['options']}
    for a in t['answerKeys']:
        assert labels[a].casefold() not in t['intro'].casefold(),(t['id'],'intro spoiler')
    assert t['result']['sources'] and all(urlparse(s['url']).scheme=='https' for s in t['result']['sources'])
    assert t['origin']==('pdf_final' if n>40 else 'sourced_expansion')
con=sqlite3.connect('file:'+str(ROOT/'assets/runtime/linkball_game_data_v4.sqlite')+'?mode=ro',uri=True)
identities=json.loads((HERE/'identities.json').read_text())
for k,v in identities.items():
    assert con.execute('select name,canonical_key from clubs where id=?',(int(k),)).fetchone()==(v['canonicalName'],v['canonicalKey'])
for t in private['tasks']:
    for cid,label in zip(t['clubIds'],t['clubs']):assert identities[str(cid)]['displayName']==label
for v in json.loads((HERE/'portraits.json').read_text()).values():
    assert con.execute('select name from players where id=?',(v['playerId'],)).fetchone()==(v['canonicalName'],)
assert private['tasks'][44]['clubIds']==[3840,6] # 54291 has unrelated Belgian career evidence.
assert private['tasks'][46]['clubIds']==[1000000861,1000000866] # Nacional Montevideo, not Paraguay.
assert private['tasks'][47]['clubIds']==[3631,6711] # Guadalajara Mexico, not Spain.
e=private['economy'];assert [m['count'] for m in e['milestones']]==[10,25,48]
assert 48*e['task']['coins']+sum(m['coins'] for m in e['milestones'])==564
assert 48*e['task']['xp']+sum(m['xp'] for m in e['milestones'])==1410
print('Derby Day PASS: 48 rivalries / 16 countries / 5 mechanics / 40 preserved pairs / V4 identities / private answers / 564 Coin + 1410 XP')
