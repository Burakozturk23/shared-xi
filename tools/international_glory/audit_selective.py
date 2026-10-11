"""Audit exactly the six requested files without shipping provider data.
Raw files remain in the supplied external directory; no asset importer exists.
"""
import argparse, hashlib, json, urllib.request
from pathlib import Path
FILES = [('events',7584),('events',3869685),('events',3869321),('events',3942382),('lineups',3869420),('lineups',3938639)]
def main():
    p=argparse.ArgumentParser();p.add_argument('--cache',required=True,type=Path);args=p.parse_args()
    root=Path(__file__).resolve().parents[2]
    cache=args.cache.resolve()
    if cache==root or root in cache.parents: p.error('Use an external cache; provider data must not enter this repository.')
    cache.mkdir(parents=True,exist_ok=True)
    report=[]
    for kind,mid in FILES:
        url=f'https://raw.githubusercontent.com/hudl/open-data/master/data/{kind}/{mid}.json'
        raw=urllib.request.urlopen(url,timeout=60).read(); data=json.loads(raw)
        (cache/f'{kind}-{mid}.json').write_bytes(raw)
        if kind=='events':
            critical=[e for e in data if (e.get('type',{}).get('name')=='Shot' and (e.get('shot',{}).get('outcome',{}).get('name')=='Goal' or e.get('period')==5)) or e.get('type',{}).get('name')=='Own Goal Against']
            assert critical
        else:
            starters=[[p for p in team['lineup'] if any(pos.get('start_reason')=='Starting XI' for pos in p.get('positions',[]))] for team in data]
            assert len(starters)==2 and all(len(s)==11 for s in starters)
        report.append({'path':f'data/{kind}/{mid}.json','sha256':hashlib.sha256(raw).hexdigest(),'records':len(data),'redistributed':False})
    print(json.dumps({'files':report,'licenseGate':'No provider data redistributed. Commercial permission is not assumed.'},indent=2))
if __name__=='__main__':main()
