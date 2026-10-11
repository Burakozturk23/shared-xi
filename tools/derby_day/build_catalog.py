"""Deterministic 48-rivalry catalog; result/period/source proof stays server-side."""
import copy, hashlib, json, random
from pathlib import Path
from editorial import ROWS
from intros import INTROS
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
LABELS=dict(memory='Derbi Hafızası',identity='Rekabetin Kimliği',timeline='Rekabet Kronolojisi',two_shirts='İki Formanın Hikâyesi',legend='Derbi Efsanesi')
def build():
    tasks=[]
    portraits=json.loads((HERE/"portraits.json").read_text())
    for n,(r,intro) in enumerate(zip(ROWS,INTROS),1):
        tid=f'DER-{n:02}'
        key=lambda label:'c'+hashlib.sha256((tid+'|'+label).encode()).hexdigest()[:12]
        options=[dict(id=key(v),label=v) for v in r['correct']+r['distractors']]
        random.Random(tid).shuffle(options)
        answers=[key(v) for v in r['correct']]
        ordered=r['mechanic']=='timeline'
        if ordered and [o['id'] for o in options]==answers:options=options[1:]+options[:1]
        sources=[dict(name=__import__('urllib.parse',fromlist=['urlparse']).urlparse(url).hostname,url=url) for url in r['urls']]
        tasks.append(dict(id=tid,number=n,contentVersion=2,origin='pdf_final' if n>40 else 'sourced_expansion',country=r['country'],clubIds=r['clubIds'],clubs=r['clubs'],city=r['city'],title=' – '.join(r['clubs']),intro=intro,mechanic=r['mechanic'],interaction='order' if ordered else 'single',prompt=r['prompt'],hint=r['hint'],options=options,requiredCount=len(answers),answerKeys=answers,result=dict(answer=' → '.join(r['correct']),evidence=r['evidence'],period=r['period'],sources=sources),verification=dict(verifiedAt='2026-10-11',scope=r['period'],sources=sources,origin='Derby_Day_V2_Final.pdf' if n>40 else 'Original sourced question for preserved legacy rivalry')))
    for t,r in zip(tasks,ROWS):
        if r["mechanic"]=="legend" and r["correct"][0] in portraits:
            t["result"]["playerId"]=portraits[r["correct"][0]]["playerId"]
    private=dict(version=2,storageVersion=1,countries=list(dict.fromkeys(t['country'] for t in tasks)),tasks=tasks,economy=dict(task=dict(coins=8,xp=20),hintCoins=6,milestones=[dict(count=n,coins=c,xp=x,title=label) for n,c,x,label in [(10,40,100,'Derbi Gezgini'),(25,60,150,'Rekabet Kaşifi'),(48,80,200,'Derbi Ustası')]]))
    public=copy.deepcopy(private)
    for t in public['tasks']:
        for k in ['answerKeys','result','verification']:del t[k]
    return private,public
if __name__=='__main__':
    for path,data in zip(['functions/config/derby_day_catalog.json','assets/data/derby_day_v2.json'],build()):
        (ROOT/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('48 rivalries / 16 countries / 5 mechanics; private answer catalog')
