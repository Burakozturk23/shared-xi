"""Read-only, resumable six-league squad audit. Never changes the game asset."""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import sqlite3
import time
import unicodedata
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
LEAGUES = {'tur.1', 'eng.1', 'esp.1', 'ita.1', 'ger.1', 'fra.1'}

def norm(s):
    return ''.join(c for c in unicodedata.normalize('NFKD', s.lower().replace('ı', 'i')) if c.isalnum())

def fetch(club, cache):
    path = cache / (club['league'] + '-' + club['sourceClubId'] + '.json')
    try:
        if path.exists():
            data = json.loads(path.read_text())
        else:
            with urlopen(club['sourceUrl'], timeout=25) as response:
                data = json.load(response)
            path.write_text(json.dumps(data, ensure_ascii=False))
            time.sleep(.7)
        if str(data.get('club', {}).get('id')) != str(club['sourceClubId']):
            raise ValueError('Response club identity mismatch')
        return club, data, None
    except Exception as error:
        return club, None, str(error)

def audit(cache):
    cache.mkdir(parents=True, exist_ok=True)
    clubs = [c for c in json.loads((ROOT/'tools/data_platform_v4/patches/rosters-2026-09-29.json').read_text())['clubs'] if c['league'] in LEAGUES]
    with ThreadPoolExecutor(max_workers=3) as pool:
        responses = list(pool.map(lambda club: fetch(club, cache), clubs))
    con = sqlite3.connect(ROOT/'assets/runtime/linkball_game_data_v4.sqlite')
    con.row_factory = sqlite3.Row
    players = {r['id']: dict(r) for r in con.execute('SELECT p.id,p.name,pr.birth_year FROM players p LEFT JOIN profiles pr ON p.id=pr.player_id')}
    index = defaultdict(set)
    for pid, row in players.items():
        index[norm(row['name'])].add(pid)
    for pid, alias in con.execute('SELECT player_id,alias FROM player_aliases'):
        index[norm(alias)].add(pid)
    links = {tuple(r) for r in con.execute('SELECT player_id,club_id FROM player_clubs')}
    rows, errors, coverage = [], [], []
    for club, data, error in responses:
        if error:
            errors.append({'club': club['canonicalName'], 'url': club['sourceUrl'], 'error': error})
            continue
        coverage.append({'league':club['league'], 'club':club['canonicalName'], 'clubId':club['clubId'], 'count':len(data.get('roster',[])), 'lastSyncedAt':data.get('lastSyncedAt')})
        for item in data.get('roster', []):
            names = sorted({item[k] for k in ('displayName','fullName') if item.get(k)})
            sid = str(item.get('id', ''))
            birth = str(item.get('dateOfBirth', ''))[:4]
            birth = int(birth) if birth.isdigit() else None
            candidates = set().union(*(index[norm(name)] for name in names))
            exact = [pid for pid in candidates if birth and players[pid]['birth_year'] == birth]
            source_id = 3000000000 + int(sid) if sid.isdigit() else None
            if source_id in candidates:
                pid = source_id
            elif len(exact) == 1:
                pid = exact[0]
            elif len(candidates) == 1 and (next(iter(candidates)),club['clubId']) in links:
                pid = next(iter(candidates))
            else:
                pid = None
            status = 'linked' if pid and (pid,club['clubId']) in links else 'missing_link' if pid else 'ambiguous' if candidates else 'missing_identity'
            rows.append({'league':club['league'], 'clubId':club['clubId'], 'club':club['canonicalName'], 'sourceClubId':club['sourceClubId'], 'sourcePlayerId':sid, 'names':names, 'birthYear':birth, 'country':item.get('citizenshipCountry',item.get('birthCountry')), 'position':item.get('position'), 'playerId':pid, 'candidates':sorted(candidates), 'status':status, 'lastSyncedAt':data.get('lastSyncedAt'), 'sourceUrl':club['sourceUrl']})
    report = {'scope':'Mapped clubs in Türkiye and the five major European first divisions; unresolved identities are never auto-merged.', 'clubsRequested':len(clubs), 'coverage':coverage, 'errors':errors, 'counts':dict(Counter(r['status'] for r in rows)), 'rows':rows}
    (cache/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('rows','coverage')},ensure_ascii=False))
    return report

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache',type=Path,required=True)
    audit(parser.parse_args().cache)
