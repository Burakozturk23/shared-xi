"""Fetch primary profile observations and match metadata; never infer career totals.

Only selected factual fields are retained, with full-response SHA256 receipts.
These observations are NOT automatically approved for the 2025 scoring cutoff.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / 'sources'


def fetch(url):
    with urllib.request.urlopen(url, timeout=45) as response:
        raw = response.read()
    return json.loads(raw), hashlib.sha256(raw).hexdigest()


def collect():
    OUT.mkdir(exist_ok=True)
    catalog = json.loads((ROOT/'assets/data/daily_footballer_catalog.json').read_text(encoding='utf-8'))
    requests = [('espn', s['url']) for s in catalog['sources']]
    requests += [('statsbomb', f'https://raw.githubusercontent.com/hudl/open-data/master/data/matches/16/{s}.json') for s in [1,4,22,26,41,44,71]]
    def run(item):
        kind, url = item
        data, sha = fetch(url)
        receipt = dict(url=url, sha256=sha, retrievedAt=datetime.now(timezone.utc).isoformat(), provider=kind)
        if kind == 'espn':
            receipt['season'] = data.get('season')
            receipt['team'] = {k:data['team'].get(k) for k in ['id','name','displayName']}
            receipt['athletes'] = [{k:a.get(k) for k in ['id','displayName','fullName','shortName','dateOfBirth','height','displayHeight','citizenship','position']} for a in data['athletes']]
            filename = 'espn_' + url.split('/soccer/')[1].replace('/','_') + '.json'
        else:
            receipt['matches'] = [{k:m[k] for k in ['match_id','match_date','home_team','away_team','competition','season']} for m in data]
            filename = 'statsbomb_' + url.rsplit('/',1)[1]
        (OUT/filename).write_bytes((json.dumps(receipt, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
        return filename
    with ThreadPoolExecutor(max_workers=4) as pool:
        for filename in pool.map(run, requests):
            print(filename, flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    collect()
