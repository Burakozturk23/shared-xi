"""CI content, redaction, source, spoiler and economy contract."""
from collections import Counter
import json
from build_catalog import ROOT, build
private, public = build()
for path, expected in zip(['functions/config/nostalgia_catalog.json','assets/data/nostalgia_v2.json'],[private,public]):
    assert json.loads((ROOT/path).read_text())==expected, f'Regenerate {path}'
assert len(private['chapters'])==12 and len(private['tasks'])==24
assert Counter(t['type'] for t in private['tasks'])==dict(season=7,squad=5,timeline=3,legend=5,route=4)
assert len({t['id'] for t in private['tasks']})==24
for c in private['chapters']:
    tasks=[t for t in private['tasks'] if t['chapterId']==c['id']]
    assert len(tasks)==2 and tasks[0]['type']!=tasks[1]['type']
    assert c['taskIds']==[t['id'] for t in tasks]
    for t in tasks:
        assert t['verification']['status']=='A' and t['verification']['spoilerReviewed']
        assert len(set(t['answerKeys']))==t['required']
        assert all(any(o['id']==k for o in t['options']) for k in t['answerKeys'])
        assert len(t['options'])== (t['required'] if t['type']=='timeline' else 4)
        assert t['result']['sources'] and all(s['url'].startswith('https://') for s in t['result']['sources'])
        for o in t['options']:
            if o['id'] not in t['answerKeys']: continue
            # Timeline labels necessarily occur as neutral events; single-name/season answers must not leak.
            if t['type'] not in ('timeline','route') and len(o['label'])>2:
                for text in [c['title'],c['intro'],c['era'],t['hint']]: assert o['label'].casefold() not in text.casefold(),(t['id'],text)
for t in public['tasks']:
    assert not {'answerKeys','result','verification','strongHint'} & t.keys()
assert all('album' not in c for c in public['chapters'])
e=private['economy']
assert [24*e['task'][k]+12*e['chapter'][k]+e['album'][k] for k in ['coins','xp']]==[384,840]
print('Nostalji: 12 chapters, 24 tasks, 5 mechanics; redaction, sources, spoiler and 384 coin / 840 XP checks passed.')
