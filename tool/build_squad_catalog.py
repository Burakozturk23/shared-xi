"""Build a small, deterministic Squad Challenge catalog from the committed V4 data.

python tool/build_squad_catalog.py --dart <path-to-dart>
The same bytes are shipped in Flutter and Functions. No external data is fetched.

Known players only: themes are filled in order of the gameplay rating that the
online modes use (tools/pvp/build_catalog.py; Loto shows names from 75 up), not
the database selection rank, which misses many stars (Son, Elmas, Kim Min-jae)
and most retired legends. Credits follow the same order, so the best-known
players cost the most. Links count senior first-team clubs only, each under one
id: youth and reserve sides (Chelsea U18, Paris SG B) and the offset duplicates
of a club (PSG under two ids) no longer make or miss links.
"""
import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KNOWN_RATING = 72  # Theme pools draw from this rating up first.
FLOOR_RATING = 65  # Below this nobody enters, even to fill a position.
SLOT_CHOICES = 12  # Known options kept for every strict formation slot.
THEME_CORE = 120   # Best-known players of each theme.
parser = argparse.ArgumentParser()
parser.add_argument('--dart', default='dart')
args = parser.parse_args()
database = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
db = sqlite3.connect(f'file:{database}?mode=ro', uri=True)
db.row_factory = sqlite3.Row
rawclubs = {r['id']: dict(r) for r in db.execute('select * from clubs')}
mismatch = {x['id'] for x in json.loads((ROOT / 'tools/data_platform_v4/club_offset_mismatch.json')
                                       .read_text(encoding='utf-8'))['ids']}


def canonical(club):
    # Exposed V4 TM identifiers repeat the TM id with a namespace offset.
    original = club - 1000000000
    return original if club >= 1000000000 and club not in mismatch and original in rawclubs else club


def senior(club):
    row = rawclubs.get(club)
    return bool(row and row['entity_type'] == 'SENIOR' and row['gameplay_eligible'])


countries = collections.defaultdict(list)
clubs = collections.defaultdict(list)
for r in db.execute('select player_id,country from player_countries order by player_id,ord'):
    countries[r['player_id']].append(r['country'])
for r in db.execute('select player_id,club_id from player_clubs order by player_id,club_id'):
    club = canonical(r['club_id'])
    if senior(club) and club not in clubs[r['player_id']]:
        clubs[r['player_id']].append(club)
league = {i: c['competition'] or '' for i, c in rawclubs.items()}
pvp = json.loads(gzip.decompress((ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))['players']
rating = {int(k): v['rating'] for k, v in pvp.items()}
raw = []
for r in db.execute('''select p.id,p.name,p.country,p.position,p.selection_rank,
                      pr.detailed_position from players p
                      left join profiles pr on pr.player_id=p.id order by p.id'''):
    if r['name'].strip() and rating.get(r['id'], 0) >= FLOOR_RATING and clubs[r['id']]:
        raw.append(dict(id=r['id'], name=r['name'].strip(), position=r['position'] or '',
                        detailedPosition=r['detailed_position'] or '',
                        countries=countries[r['id']] or ([r['country']] if r['country'] else []),
                        clubIds=sorted(clubs[r['id']]),
                        rank=(-rating[r['id']], r['selection_rank'] or 999999, r['id'])))
# One player per name: the search box shows names only.
best = {}
for p in sorted(raw, key=lambda p: p['rank']):
    best.setdefault(p['name'].casefold(), p)
raw = list(best.values())
with tempfile.TemporaryDirectory() as tmp:
    source = Path(tmp) / 'players.json'
    source.write_text(json.dumps(raw), encoding='utf-8')
    result = subprocess.run([args.dart, str(ROOT / 'tool/export_squad_rules.dart'), str(source)],
                            cwd=ROOT, text=True, encoding='utf-8', check=True, capture_output=True)
    catalog = json.loads(result.stdout)
for p in catalog['players']:
    p['rank'] = tuple(p['rank'])

def matching(player, slot):
    detailed = player['detailedPosition']
    if detailed and detailed not in {'Goalkeeper', 'Defender', 'Midfield', 'Attack'}:
        return detailed in slot['positions']
    return player['position'] == slot['broad']

all_players = sorted(catalog.pop('players'), key=lambda p: p['rank'])
known = lambda p: -p['rank'][0] >= KNOWN_RATING
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
    selected = {p['id']: p for p in [p for p in candidates if known(p)][:THEME_CORE]}
    # Every strict position keeps a real choice; below the known line only to
    # reach that choice, best-known first.
    for formation in catalog['formations']:
        for slot in formation['slots']:
            fits = [p for p in candidates if matching(p, slot)]
            have = [p for p in fits if p['id'] in selected]
            for p in [p for p in fits if p['id'] not in selected][:max(0, SLOT_CHOICES - len(have))]:
                if known(p) or len(have) < SLOT_CHOICES // 2:
                    selected[p['id']] = p; have.append(p)
    # Regional tasks need a spread of countries: the best-known of each nation.
    for nation in sorted({n for p in candidates for n in p['countries']}):
        for p in [p for p in candidates if nation in p['countries'] and known(p)][:2]:
            selected[p['id']] = p
    ordered = sorted(selected.values(), key=lambda p: p['rank'])
    theme['players'] = [p['id'] for p in ordered]
    # Fixed scouting credits, separate from the spendable account coin wallet.
    theme['costs'] = {str(p['id']): max(3, 18 - (i * 16 // max(1, len(ordered))))
                      for i, p in enumerate(ordered)}
    theme['dailyEligible'] = theme['id'] != 'passportless'
    for p in ordered:
        picked[p['id']] = {k: v for k, v in p.items() if k != 'rank'}
    if len(ordered) < 35:
        raise RuntimeError(f"Theme {theme['id']} has only {len(ordered)} players")
    print(f"{theme['id']}: {len(ordered)} players, {sum(1 for p in ordered if not known(p))} below {KNOWN_RATING}")
catalog['players'] = [picked[k] for k in sorted(picked)]
used = sorted({c for p in catalog['players'] for c in p['clubIds']})
catalog['clubNames'] = {str(c): rawclubs[c]['name'].strip() for c in used if (rawclubs[c]['name'] or '').strip()}
catalog['sourceSha256'] = hashlib.sha256(database.read_bytes()).hexdigest()
# A changed rule, cost or player must never silently match an older client.
fingerprint = hashlib.sha256(json.dumps(catalog, ensure_ascii=False, sort_keys=True,
                                        separators=(',', ':')).encode()).hexdigest()[:12]
catalog['version'] = 'squad-v3-' + fingerprint
payload = json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n'
for relative in ['assets/data/squad_challenge_catalog.json', 'functions/data/squad_challenge_catalog.json']:
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(payload, encoding='utf-8', newline='\n')
print(f"{len(picked)} unique players; {len(payload.encode())} bytes per catalog")
