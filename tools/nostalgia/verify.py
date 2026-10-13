"""Fail closed on catalog drift, missing evidence or accidental mechanic loss."""
import json
from pathlib import Path
from collections import Counter
from build_catalog import catalog
ROOT=Path(__file__).resolve().parents[2]
for path in ['assets/data/turkish_nostalgia_v2.json','functions/config/nostalgia_catalog.json']:
    assert json.loads((ROOT/path).read_text()) == catalog, path
chapters=catalog['chapters']; tasks=[t for c in chapters for t in c['tasks']]
assert len(chapters)==12 and len(tasks)==24 and len({t['id'] for t in tasks})==24
assert Counter(t['mechanic'] for t in tasks)==dict(season=7,squad=5,timeline=3,legend=5,route=4)
for c in chapters:
    assert len(c['tasks'])==2 and c['tasks'][0]['mechanic']!=c['tasks'][1]['mechanic']
    for t in c['tasks']:
        assert t['verification']=='A' and t['spoilerReviewed'] and t['sources']
        labels={o['id']:o['label'] for o in t['options']}
        for k in t['answerKeys']:
            for text in [c['title'],c['era'],c['intro'],t['hint']]:
                assert labels[k] not in text,(t['id'],'spoiler',text)
        assert all(s['url'].startswith('https://') and s['accessed']=='2026-10-10' for s in t['sources'])
e=catalog['economy']
assert 24*e['task']['coins']+12*e['chapter']['coins']+e['final']['coins']==384
assert 24*e['task']['xp']+12*e['chapter']['xp']+e['final']['xp']==840
print('Nostalji V2: 12 chapters / 24 tasks / 5 mechanics; source records, runtime parity and 384 Coin / 840 XP verified')
