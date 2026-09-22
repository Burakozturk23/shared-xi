"""Build a small, deterministic Squad Challenge catalog from the committed V4 data.

python tool/build_squad_catalog.py --dart <path-to-dart>
The same bytes are shipped in Flutter and Functions. No external data is fetched.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--dart', default='dart')
args = parser.parse_args()
database = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
db = sqlite3.connect(f'file:{database}?mode=ro', uri=True)
db.row_factory = sqlite3.Row
countries = collections.defaultdict(list)
clubs = collections.defaultdict(list)
for r in db.execute('select player_id,country from player_countries order by player_id,ord'):
    countries[r['player_id']].append(r['country'])
for r in db.execute('select player_id,club_id from player_clubs order by player_id,club_id'):
    clubs[r['player_id']].append(r['club_id'])
league = {r['id']: r['competition'] or '' for r in db.execute('select id,competition from clubs')}
raw = []
for r in db.execute('''select p.id,p.name,p.country,p.position,p.selection_rank,
                      pr.detailed_position from players p
                      left join profiles pr on pr.player_id=p.id order by p.id'''):
    if r['name'].strip():
        raw.append(dict(id=r['id'], name=r['name'], position=r['position'] or '',
                        detailedPosition=r['detailed_position'] or '',
                        countries=countries[r['id']] or ([r['country']] if r['country'] else []),
                        clubIds=clubs[r['id']], rank=r['selection_rank'] or 999999))
with tempfile.TemporaryDirectory() as tmp:
    source = Path(tmp) / 'players.json'
    source.write_text(json.dumps(raw), encoding='utf-8')
    result = subprocess.run([args.dart, str(ROOT / 'tool/export_squad_rules.dart'), str(source)],
                            cwd=ROOT, text=True, encoding='utf-8', check=True, capture_output=True)
    catalog = json.loads(result.stdout)

def matching(player, slot):
    detailed = player['detailedPosition']
    if detailed and detailed not in {'Goalkeeper', 'Defender', 'Midfield', 'Attack'}:
        return detailed in slot['positions']
    return player['position'] == slot['broad']

all_players = sorted(catalog.pop('players'), key=lambda p: (p['rank'], p['id']))
picked = {}
for theme in catalog['themes']:
    kind = theme['poolType']
    allowed = set(theme.get('countries') or [])
    pair = set(theme.get('clubIds') or [])
    def eligible(p):
        if kind == 'league':
            aliases = {'LaLiga': {'LaLiga', 'La Liga'}, 'Liga Portugal': {'Liga Portugal', 'Primeira Liga'},
                       'Süper Lig': {'Süper Lig', 'Super Lig'}}
            accepted = aliases.get(theme['league'], {theme['league']})
            return any(league.get(k) in accepted for k in p['clubIds'])
        if kind == 'region':
            return bool(allowed.intersection(p['countries']))
        if kind == 'clubUnion':
            return bool(pair.intersection(p['clubIds']))
        if kind == 'clubPair':
            return pair.issubset(p['clubIds'])
        return len(p['clubIds']) >= (theme.get('minClubs') or 0)
    candidates = [p for p in all_players if eligible(p)]
    selected = {p['id']: p for p in candidates[:120]}
    # Preserve a genuine choice in every strict position, not just forwards.
    for formation in catalog['formations']:
        for slot in formation['slots']:
            for p in [p for p in candidates if matching(p, slot)][:12]:
                selected[p['id']] = p
    # Regional tasks need a useful spread of countries as well as positions.
    for nation in sorted({n for p in candidates for n in p['countries']}):
        for p in [p for p in candidates if nation in p['countries']][:2]:
            selected[p['id']] = p
    ordered = sorted(selected.values(), key=lambda p: (p['rank'], p['id']))
    theme['players'] = [p['id'] for p in ordered]
    # Fixed scouting credits, separate from the spendable account coin wallet.
    theme['costs'] = {str(p['id']): max(3, 18 - (i * 16 // max(1, len(ordered))))
                      for i, p in enumerate(ordered)}
    theme['dailyEligible'] = theme['id'] != 'passportless'
    for p in ordered:
        picked[p['id']] = {k: v for k, v in p.items() if k != 'rank'}
    if len(ordered) < 35:
        raise RuntimeError(f"Theme {theme['id']} has only {len(ordered)} players")
    print(f"{theme['id']}: {len(ordered)} players")
catalog['players'] = [picked[k] for k in sorted(picked)]
catalog['sourceSha256'] = hashlib.sha256(database.read_bytes()).hexdigest()
# A changed rule, cost or player must never silently match an older client.
fingerprint = hashlib.sha256(json.dumps(catalog, ensure_ascii=False, sort_keys=True,
                                        separators=(',', ':')).encode()).hexdigest()[:12]
catalog['version'] = 'squad-v1-' + fingerprint
payload = json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n'
for relative in ['assets/data/squad_challenge_catalog.json', 'functions/data/squad_challenge_catalog.json']:
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(payload, encoding='utf-8')
print(f"{len(picked)} unique players; {len(payload.encode())} bytes per catalog")
