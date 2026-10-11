"""Catalog/schema/security gates; offline checks do not replace historical research."""
from collections import Counter
import json
import sqlite3
from urllib.parse import urlparse
from build_catalog import ROOT, HERE, build
private,public=build()
for path,data in [('functions/config/football_docu_catalog.json',private),('assets/data/football_docu_v2.json',public),('tools/football_docu/sources.json',{t['id']:t['verification'] for t in private['tasks']})]:
    assert json.loads((ROOT/path).read_text())==data,path
assert len(private['episodes'])==24 and len(private['tasks'])==48
assert Counter(t['mechanic'] for t in private['tasks'])==dict(evidence=14,turning=9,timeline=9,person=8,headline=8)
assert Counter(e['chapterId'] for e in public['episodes'])=={1:8,2:8,3:8}
assert len({t['id'] for t in private['tasks']})==48
for n,e in enumerate(public['episodes'],1):
    assert e['id']==f'DOC-{n:02}' and e['taskIds']==[f'DOC-{n:02}-01',f'DOC-{n:02}-02']
    ts=private['tasks'][(n-1)*2:n*2]
    assert len({t['mechanic'] for t in ts})==2
    assert 60<=len(e['intro'].split())<=90
    assert 60<=len(private['episodes'][n-1]['interlude'].split())<=100
    assert 'story' not in e and 'interlude' not in e
    # Named answers and long answer phrases must not appear in public narration.
    labels={o['id']:o['label'] for t in ts for o in t['options']}
    for t in ts:
        for a in t['answerKeys']:
            label=labels[a].casefold()
            if len(label)>5 and label not in ['doğru','yanlış']:
                assert label not in (e['title']+' '+e['intro']).casefold(),(e['id'],label)
for t,p in zip(private['tasks'],public['tasks']):
    assert not {'answerKeys','result','verification'} & p.keys()
    ids=[o['id'] for o in t['options']]
    assert len(ids)==len(set(ids))
    assert set(t['answerKeys'])<=set(ids) and len(t['answerKeys'])==t['requiredCount']
    if t['interaction']=='order':
        assert 2<=len(ids)<=5 and ids!=t['answerKeys'] and len(t['verification']['periods'])==len(ids)
    if t['interaction']=='match':assert len(t['slots'])==t['requiredCount']
    if t['mechanic']=='headline':assert t['interaction']=='boolean' and {o['label'] for o in t['options']}=={'Doğru','Yanlış'}
    if t['mechanic']=='person':assert len(ids)==4
    assert t['result']['evidence'] and t['verification']['verifiedAt']
    assert t['result']['sources'] and all(urlparse(s['url']).scheme=='https' and len(urlparse(s['url']).path)>3 for s in t['result']['sources'])
# Review only exact V4 IDs; missing faces deliberately use a local monogram, never a guessed identity.
c=sqlite3.connect('file:'+str(ROOT/'assets/runtime/linkball_game_data_v4.sqlite')+'?mode=ro',uri=True)
for label,identity in json.loads((HERE/'identities.json').read_text()).items():
    assert c.execute('select name from players where id=?',(identity['playerId'],)).fetchone()==(identity['canonicalName'],)
e=private['economy']
assert 48*e['task']['coins']+sum(m['coins'] for m in e['milestones'])==564
assert 48*e['task']['xp']+sum(m['xp'] for m in e['milestones'])==1410
assert [m['count'] for m in e['milestones']]==[8,16,24]
assert not (ROOT/'lib/data/football_docu_series.dart').exists()
print('Docu-Series PASS: 24 files / 48 sourced tasks / 5 mechanics / 3 chapters / private answers / 564 Coin + 1410 XP')
