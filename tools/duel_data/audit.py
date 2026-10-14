"""Read-only, offline coverage audit for the proposed single-metric duel.

Run from the repository root: python tools/duel_data/audit.py
Field presence is NOT verification. This tool never updates the runtime database.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'


def normalize(value):
    return ' '.join(''.join(ch for ch in unicodedata.normalize('NFKD', value.casefold().replace('ı', 'i'))
                           if not unicodedata.combining(ch)).split())


def open_readonly(path):
    conn = sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def distribution(conn, table, column):
    return [dict(r) for r in conn.execute(
        f'SELECT {column} value, count(*) count FROM {table} GROUP BY {column} ORDER BY count(*) DESC, {column}')]


def field_coverage(conn, table, column, population):
    # table/column are internal constants, never user-provided SQL identifiers.
    row = dict(conn.execute(f'''SELECT count(*) rows, count({column}) present,
        sum({column} = 0) zero, sum({column} > 0) positive,
        min({column}) minimum, max({column}) maximum FROM {table}''').fetchone())
    row['missing_in_population'] = population - row['present']
    row['meaning'] = 'presence_only_not_verified'
    return row


def audit(db, seed):
    with open_readonly(db) as c:
        count = lambda table: c.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
        total = count('players')
        cols = {
            'players': ['market_value', 'peak_market_value', 'career_goals'],
            'profiles': ['birth_year', 'height_cm', 'international_caps', 'international_goals'],
            'player_stats': ['appearances', 'goals', 'assists', 'ucl_appearances'],
        }
        fields = {f'{t}.{col}': field_coverage(c, t, col, total) for t, cs in cols.items() for col in cs}
        coaches = [dict(r) for r in c.execute('SELECT * FROM coaches ORDER BY id')]
        payloads = [json.loads(r['payload_json']) for r in coaches]
        legacy_coaches = json.loads((ROOT / 'assets/data/coaches_min.json').read_text())
        payload_parity = sorted(payloads, key=lambda p: p['id']) == sorted(legacy_coaches, key=lambda p: p['id'])
        keys = sorted({k for p in payloads for k in p})
        presence = {k: sum(bool(p.get(k)) for p in payloads) for k in keys}
        index = defaultdict(list)
        for r, p in zip(coaches, payloads):
            for name in {r['name'], *p.get('aliases', [])}:
                if r['id'] not in index[normalize(name)]:
                    index[normalize(name)].append(r['id'])
        candidates = [{
            'name': name, 'candidateIds': index.get(normalize(name), []),
            'status': 'needs_identity_review' if index.get(normalize(name)) else 'not_found_by_name_or_alias',
        } for name in seed['palmaresManagerCandidates']]
        duplicates = defaultdict(list)
        for r in coaches:
            duplicates[normalize(r['name'])].append(r['id'])
        club_ids = {r[0] for r in c.execute('SELECT id FROM clubs')}
        invalid_clubs = [{'coach': p['id'], 'club': cid} for p in payloads
                         for cid in p['clubIds'] if cid not in club_ids]
        buffon = dict(c.execute('SELECT p.id,p.name,pr.international_caps FROM players p '
                               'JOIN profiles pr ON pr.player_id=p.id WHERE p.id=5023').fetchone())
        daily = json.loads((ROOT / 'assets/data/daily_footballer_catalog.json').read_text())
        metrics = []
        for metric in sorted({f['metric'] for f in seed['facts']}):
            facts = [f for f in seed['facts'] if f['metric'] == metric]
            entities = {e['key']: e for e in seed['entities']}
            metrics.append({'metric': metric, 'reviewedEntities': len(facts),
                            'mappedEntities': sum(entities[f['entity']]['local'] is not None for f in facts),
                            'cutoffs': sorted({f['cutoff'] for f in facts}), 'enabled': False,
                            'blockers': ['population_coverage_not_complete', 'game_balance_not_evaluated',
                                         'no_runtime_integration']})
        return {
            'schemaVersion': 1, 'reviewDate': seed['reviewedOn'],
            'databaseSha256': hashlib.sha256(Path(db).read_bytes()).hexdigest(),
            'counts': {'players': total, 'coaches': len(coaches), 'clubs': count('clubs')},
            'playerFields': fields,
            'playerPositions': distribution(c, 'players', 'position'),
            'statsCoverageClasses': distribution(c, 'player_stats', 'coverage_class'),
            'statsFirstYears': distribution(c, 'player_stats', 'coverage_first_year'),
            'statsLastYears': distribution(c, 'player_stats', 'coverage_last_year'),
            'profileSourceSeasons': distribution(c, 'profiles', 'source_last_season'),
            'heightByPosition': [dict(r) for r in c.execute('SELECT p.position,count(*) count FROM players p '
                'JOIN profiles f ON f.player_id=p.id WHERE height_cm BETWEEN 140 AND 220 GROUP BY p.position')],
            'dailyBirthDates': {'players': len(daily['players']),
                'present': sum(bool(p.get('birthDate')) for p in daily['players']),
                'idNamespace': 'espn', 'v4IdentityMapping': 'not_validated'},
            'coaches': {'payloadFields': keys, 'nonemptyFields': presence,
                'legacyJsonMatchesSqlitePayloads': payload_parity,
                'missingClubLinks': len(coaches)-presence.get('clubIds', 0),
                'missingCountries': len(coaches)-presence.get('countries', 0),
                'normalizedNameCollisions': [{'name': n, 'ids': ids} for n, ids in sorted(duplicates.items()) if len(ids)>1],
                'invalidClubLinks': invalid_clubs,
                'warning': 'rating is not a verified win, appearance or trophy statistic; club links have no tenure dates'},
            'palmaresManagerIdentityCandidates': candidates,
            'reviewedSupplement': {'entities': len(seed['entities']), 'facts': len(seed['facts']),
                'events': sum(len(f['events']) for f in seed['facts']),
                'unmapped': [e['key'] for e in seed['entities'] if e['local'] is None], 'metrics': metrics},
            'blockingFindings': [
                {'id': 'buffon_caps_conflict', 'observed': buffon, 'reviewedValue': 176,
                 'source': 'figc_buffon', 'resolution': 'corrected_in_supplement_runtime_patch_pending'},
                {'id': 'partial_career_windows', 'resolution': 'do_not_label_aggregates_all_time'},
                {'id': 'unknown_is_not_zero', 'resolution': 'legacy_default_zero_requires_metric_specific_review'},
                {'id': 'coach_honours_missing', 'resolution': 'use_role_specific_season_events_not_rating'},
                {'id': 'source_date_mismatch', 'resolution': 'do_not_mix_historical_snapshots_with_current_totals'},
            ],
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=DEFAULT_DB)
    parser.add_argument('--output', type=Path, default=ROOT/'docs/duel-data/audit.json')
    args = parser.parse_args()
    seed = json.loads((Path(__file__).parent/'reviewed_facts.json').read_text())
    result = audit(args.db, seed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'output': str(args.output), 'counts': result['counts'],
                      'status': 'AUDITED_NOT_GAME_READY'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
