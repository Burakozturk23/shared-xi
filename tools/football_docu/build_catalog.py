"""Build minimal, reproducible Docu-Series catalogs; private answers stay server-side."""
import copy
import hashlib
import json
import random
from pathlib import Path
from editorial_episodes import EPISODES
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def build():
    rows = json.loads((HERE/'editorial_tasks.json').read_text())
    identities = json.loads((HERE/'identities.json').read_text())
    sources = json.loads((HERE/'references.json').read_text())
    episodes, tasks = [], []
    for i, (club, period, title, theme, intro, interlude, story) in enumerate(EPISODES, 1):
        episodes.append(dict(id=f'DOC-{i:02}', number=i, chapterId=(i-1)//8+1,
            club=club, period=period, title=title, theme=theme, intro=intro,
            interlude=interlude, story=story, taskIds=[f'DOC-{i:02}-01',f'DOC-{i:02}-02']))
    for r in rows:
        n=r['number']; episode=(n+1)//2; stage=1 if n%2 else 2; tid=f'DOC-{episode:02}-{stage:02}'
        key=lambda label:'c'+hashlib.sha256((tid+'|'+label).encode()).hexdigest()[:12]
        options=[dict(id=key(label),label=label) for label in r['correct']+r['distractors']]
        if r['mechanic']=='person':
            for o in options:
                if o['label'] in identities:o['playerId']=identities[o['label']]['playerId']
        random.Random(tid).shuffle(options)
        answers=[key(label) for label in r['correct']]
        if r['interaction']=='order' and [o['id'] for o in options]==answers:
            options=options[1:]+options[:1]
        refs=[dict(name=k,url=sources[k]) for k in r['sourceIds']]
        answer=' → '.join(r['correct']) if r['interaction']=='order' else '; '.join(r['correct'])
        if r['slots']:answer='; '.join(f'{a}: {b}' for a,b in zip(r['slots'],r['correct']))
        tasks.append(dict(id=tid,number=n,episodeId=f'DOC-{episode:02}',stage=stage,
            title=f'Araştırma {stage}',contentVersion=2,difficulty='orta' if r['interaction'] in ['order','match','multi'] else 'kolay',
            mechanic=r['mechanic'],interaction=r['interaction'],prompt=r['prompt'],hint=r['hint'],
            options=options,requiredCount=len(answers),slots=r['slots'],answerKeys=answers,
            result=dict(answer=answer,evidence=r['evidence'],sources=refs,
                interlude=episodes[episode-1]['interlude'] if stage==1 else '',contentVersion=2),
            verification=dict(verifiedAt='2026-10-11',evidence=r['evidence'],periods=r['periods'],sources=refs)))
    private=dict(version=2,storageVersion=1,chapters=['Mucizenin doğuşu','Güç, karar ve kırılma anları','Çöküş, taraftar ve yeniden doğuş'],
        episodes=episodes,tasks=tasks,economy=dict(task=dict(coins=8,xp=20),hintCoins=6,
        milestones=[dict(count=n,coins=c,xp=x) for n,c,x in [(8,40,100),(16,60,150),(24,80,200)]]))
    public=copy.deepcopy(private)
    for e in public['episodes']:
        for k in ['story','interlude']:del e[k]
    for t in public['tasks']:
        for k in ['answerKeys','result','verification']:del t[k]
    return private,public

if __name__=='__main__':
    private,public=build()
    for path,data in [('functions/config/football_docu_catalog.json',private),('assets/data/football_docu_v2.json',public),
                      ('tools/football_docu/sources.json',{t['id']:t['verification'] for t in private['tasks']})]:
        (ROOT/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('24 documentaries / 48 tasks / 3 chapters; answer-free app catalog')
