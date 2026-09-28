#!/usr/bin/env python3
"""Read-only API-Football transfer collection and canonical-ID review report."""
import argparse
from datetime import date, datetime, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import time
import unicodedata
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = 'https://v3.football.api-sports.io/'
LEAGUES = [203, 39, 140, 135, 78, 61]  # Turkey, England, Spain, Italy, Germany, France


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


class Client:
    def __init__(self, key, cache, budget=20, offline=False):
        self.key, self.cache, self.budget, self.offline = key, cache, budget, offline
        self.calls = 0
        self.last_call = 0.0

    def get(self, endpoint, **params):
        query = endpoint + ('?' + urlencode(sorted(params.items())) if params else '')
        path = self.cache / (hashlib.sha256(query.encode()).hexdigest() + '.json')
        if endpoint != 'status' and path.exists():
            envelope = json.loads(path.read_text(encoding='utf-8'))
            if envelope['query'] != query:
                raise ValueError('Cache query mismatch')
            return envelope['data']
        if self.offline:
            raise ValueError('Missing offline cache: ' + query)
        if self.calls >= self.budget:
            raise ValueError('Request budget reached; rerun with the same cache to resume')
        time.sleep(max(0, 6.1 - (time.monotonic() - self.last_call)))
        self.calls += 1
        self.last_call = time.monotonic()
        request = Request(BASE + query, headers={'x-apisports-key': self.key})
        try:
            with urlopen(request, timeout=45) as response:
                data = json.load(response)
        except HTTPError as error:
            raise ValueError(f'API HTTP {error.code} at {endpoint}; check subscription/quota') from None
        except (URLError, TimeoutError):
            raise ValueError('API connection failed; cached progress retained') from None
        if data.get('errors'):
            # Never print provider errors: they can echo request credentials.
            raise ValueError('API rejected ' + endpoint + '; check access, season and quota')
        if 'response' not in data:
            raise ValueError('Invalid API response: ' + endpoint)
        if data.get('paging', {}).get('total', 1) > 1:
            raise ValueError('Unexpected pagination; refusing incomplete collection')
        if endpoint != 'status':
            save(path, {'query': query, 'fetchedUtc': datetime.now(timezone.utc).isoformat(), 'data': data})
        return data


def normalize(value):
    value = unicodedata.normalize('NFKD', value.casefold().replace('ı', 'i'))
    return ''.join(c for c in value if c.isalnum() and not unicodedata.combining(c))


def index_database(db):
    indexes = {'players': {}, 'clubs': {}}
    for table in indexes:
        for identifier, name in db.execute('SELECT id,name FROM ' + table):
            indexes[table].setdefault(normalize(name), set()).add(identifier)
    for identifier, alias in db.execute('SELECT player_id,alias FROM player_aliases'):
        indexes['players'].setdefault(normalize(alias), set()).add(identifier)
    return indexes


def validate_mapping(db, mapping):
    for table in ('players', 'clubs'):
        for provider_id, canonical_id in mapping.get(table, {}).items():
            if not str(provider_id).isdigit() or type(canonical_id) is not int:
                raise ValueError('Mapping IDs must be numeric')
            if not db.execute('SELECT 1 FROM ' + table + ' WHERE id=?', (canonical_id,)).fetchone():
                raise ValueError('Unknown canonical ID in ' + table)


def match(entity, table, indexes, mapping):
    identifier = mapping.get(table, {}).get(str(entity.get('id')))
    return {'providerId': entity.get('id'), 'name': entity.get('name'),
            'canonicalId': identifier,
            'candidates': sorted(indexes[table].get(normalize(entity.get('name') or ''), set())),
            'status': 'mapped' if identifier is not None else 'needs_review'}


def transfer_rows(payload, start, end):
    for group in payload:
        for transfer in group.get('transfers', []):
            raw_date = transfer.get('date')
            try:
                day = date.fromisoformat(raw_date)
            except (ValueError, TypeError):
                # Do not silently discard a transfer with an unknown date.
                yield group['player'], transfer, 'invalid_date'
                continue
            if start <= day <= end:
                yield group['player'], transfer, None


def collect(client, db, mapping, leagues, season, start, end, report_path):
    indexes = index_database(db)
    report = {'complete': False, 'season': season, 'from': str(start), 'to': str(end),
              'generatedUtc': datetime.now(timezone.utc).isoformat(),
              'databaseSha256': None, 'leagues': leagues, 'teamsCompleted': [],
              'transfers': [], 'warnings': [], 'policy': 'Review only; no database writes. Squad membership is not appearance evidence.'}
    seen = set()
    try:
        teams = {}
        for league in leagues:
            records = client.get('teams', league=league, season=season)['response']
            if not records:
                raise ValueError(f'No teams returned for league {league}, season {season}')
            for record in records:
                teams[record['team']['id']] = record['team']
        for team_id in sorted(teams):
            squad = client.get('players/squads', team=team_id)['response']
            squad_ids = {p['id'] for item in squad if item['team']['id'] == team_id for p in item['players']}
            if not squad_ids:
                report['warnings'].append(f'Empty current squad: {team_id}')
            transfers = client.get('transfers', team=team_id)['response']
            for player, event, issue in transfer_rows(transfers, start, end):
                outgoing = event.get('teams', {}).get('out') or {}
                incoming = event.get('teams', {}).get('in') or {}
                key = (player['id'], event.get('date'), outgoing.get('id'), incoming.get('id'), event.get('type'))
                # A player can occur in responses for both involved teams.
                if key in seen:
                    if incoming.get('id') == team_id:
                        for row in report['transfers']:
                            if row['_key'] == list(key):
                                row['inCurrentDestinationSquad'] = player['id'] in squad_ids
                    continue
                seen.add(key)
                pm = match(player, 'players', indexes, mapping)
                cm = match(incoming, 'clubs', indexes, mapping)
                existing = None
                if pm['canonicalId'] is not None and cm['canonicalId'] is not None:
                    existing = bool(db.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?', (pm['canonicalId'], cm['canonicalId'])).fetchone())
                report['transfers'].append({'_key': list(key), 'date': event.get('date'), 'type': event.get('type'),
                    'player': pm, 'fromClub': match(outgoing, 'clubs', indexes, mapping), 'toClub': cm,
                    'existingDestinationLink': existing, 'issue': issue,
                    'inCurrentDestinationSquad': player['id'] in squad_ids if incoming.get('id') == team_id else None,
                    'appearanceVerified': False, 'action': 'review_required'})
            report['teamsCompleted'].append(team_id)
            save(report_path, report)
        report['complete'] = True
    except (ValueError, KeyError, TypeError) as error:
        report['stopReason'] = str(error) if isinstance(error, ValueError) else 'Unexpected response schema'
    finally:
        report['requestsThisRun'] = client.calls
        save(report_path, report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--season', type=int, required=True)
    parser.add_argument('--from-date', type=date.fromisoformat, required=True)
    parser.add_argument('--to-date', type=date.fromisoformat, required=True)
    parser.add_argument('--leagues', type=int, nargs='+', default=LEAGUES)
    parser.add_argument('--max-requests', type=int, default=20)
    parser.add_argument('--output', type=Path, default=ROOT/'reports/api_football')
    parser.add_argument('--mapping', type=Path)
    parser.add_argument('--database', type=Path, default=ROOT/'assets/runtime/linkball_game_data_v4.sqlite')
    parser.add_argument('--prompt-key', action='store_true')
    parser.add_argument('--offline', action='store_true')
    args = parser.parse_args()
    if args.from_date > args.to_date or args.max_requests < 1:
        parser.error('Invalid date range or request budget')
    key = os.environ.get('API_FOOTBALL_KEY', '')
    if args.prompt_key and not args.offline:
        key = getpass.getpass('API-Football key (hidden): ')
    if not key and not args.offline:
        parser.error('Set API_FOOTBALL_KEY or use --prompt-key. Never commit the key.')
    client = Client(key, args.output/'cache', args.max_requests, args.offline)
    mapping = json.loads(args.mapping.read_text(encoding='utf-8')) if args.mapping else {}
    with sqlite3.connect(args.database.resolve().as_uri() + '?mode=ro', uri=True) as db:
        validate_mapping(db, mapping)
        if not args.offline:
            status = client.get('status')['response']
            # Only quota/subscription fields; never persist account identity.
            print(json.dumps({k: status.get(k) for k in ('subscription', 'requests')}))
            if status.get('subscription', {}).get('active') is False:
                raise ValueError('API subscription inactive')
        report = collect(client, db, mapping, args.leagues, args.season, args.from_date, args.to_date, args.output/'report.json')
    report['databaseSha256'] = hashlib.sha256(args.database.read_bytes()).hexdigest()
    save(args.output/'report.json', report)
    print(f"Complete={report['complete']}; teams={len(report['teamsCompleted'])}; transfers={len(report['transfers'])}")
    print('Report:', args.output/'report.json')
    if not report['complete']:
        print(report.get('stopReason'))
        return 2
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(str(error))
        raise SystemExit(2)
