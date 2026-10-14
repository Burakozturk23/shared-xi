"""Validate the reviewed research supplement; never promote it to gameplay."""
from datetime import date
import hashlib
import json
from pathlib import Path

from audit import DEFAULT_DB, open_readonly

METRIC_ROLES = {'manager_european_cup_titles': 'manager', 'manager_turkish_league_titles': 'manager',
                'player_ballon_dor': 'player', 'player_senior_caps': 'player'}
COMPETITIONS = {'manager_european_cup_titles': 'european_cup_ucl',
                'manager_turkish_league_titles': 'turkish_top_flight', 'player_ballon_dor': 'ballon_dor_men'}


def validate(data, db=DEFAULT_DB):
    errors = []
    def check(condition, message):
        if not condition:
            errors.append(message)
    check(data['runtimeEnabled'] is False, 'research package must remain disabled')
    check(data['baseDatabaseSha256'] == hashlib.sha256(Path(db).read_bytes()).hexdigest(), 'database hash mismatch')
    sources = {s['id']: s for s in data['sources']}
    check(len(sources) == len(data['sources']), 'duplicate source')
    entities = {e['key']: e for e in data['entities']}
    check(len(entities) == len(data['entities']), 'duplicate entity')
    with open_readonly(db) as c:
        local_keys = set()
        for e in data['entities']:
            check(e['role'] in {'player', 'manager'}, 'invalid entity role')
            check(e['key'].startswith(e['role']+':'), 'entity role/key mismatch')
            check(e['identitySource'] in sources, 'missing identity evidence')
            local = e['local']
            if local is None:
                check(e['identityStatus'] == 'verified_external_unmapped', 'unmapped identity must remain explicit')
                continue
            table = 'players' if e['role'] == 'player' else 'coaches'
            check(local['table'] == table, 'local role/table mismatch')
            check((table,local['id']) not in local_keys, 'duplicate local identity')
            local_keys.add((table,local['id']))
            row = c.execute(f'SELECT * FROM {table} WHERE id=?', (local['id'],)).fetchone()
            check(row is not None, 'local entity missing')
            if row is not None:
                check(row['name'] == local['name'], 'local identity changed')
                if table == 'coaches':
                    check(json.loads(row['payload_json'])['id'] == local['payloadId'], 'coach payload ID mismatch')
    fact_ids = set()
    unique_metrics = set()
    for f in data['facts']:
        check(f['id'] not in fact_ids, 'duplicate fact')
        fact_ids.add(f['id'])
        key = (f['entity'], f['metric'], f['cutoff'])
        check(key not in unique_metrics, 'duplicate metric snapshot')
        unique_metrics.add(key)
        check(f['entity'] in entities, 'unknown entity')
        check(f['metric'] in METRIC_ROLES, 'unknown metric')
        if f['entity'] in entities:
            check(entities[f['entity']]['role'] == METRIC_ROLES.get(f['metric']), 'metric role mismatch')
        check(f['enabled'] is False, 'unreviewed gameplay promotion')
        check(type(f['value']) is int and f['value'] >= 0, 'unknown/negative/noninteger value')
        check(f['verification'] == 'primary_checked', 'verification missing')
        check(f['coverage'] == 'complete_for_entity_metric_cutoff', 'incomplete metric cannot assert a total')
        check(bool(f['sources']) and all(s in sources and sources[s]['kind']=='primary' for s in f['sources']),
              'primary evidence required')
        try:
            cutoff = date.fromisoformat(f['cutoff'])
        except ValueError:
            errors.append('invalid cutoff')
            continue
        check(cutoff <= date.fromisoformat(data['reviewedOn']), 'future cutoff')
        if f['metric'] in COMPETITIONS:
            check(f['value'] == len(f['events']), 'event count mismatch')
            seen = set()
            for event in f['events']:
                ek = (event['competition'], event['season'])
                check(ek not in seen, 'duplicate season award')
                seen.add(ek)
                check(event['competition'] == COMPETITIONS[f['metric']], 'competition mismatch')
                check(event['role'] == METRIC_ROLES[f['metric']], 'event role mismatch')
                check(event['year'] <= cutoff.year, 'event beyond cutoff')
                expected = str(event['year']) if f['metric']=='player_ballon_dor' else f"{event['year']-1}-{event['year']}"
                check(event['season'] == expected, 'season/year mismatch')
                if f['metric'] == 'player_ballon_dor':
                    check(event['year'] != 2020, '2020 Ballon d Or not awarded')
                else:
                    check(bool(event['team']), 'team required for team trophy')
        else:
            check(not f['events'], 'aggregate caps must not masquerade as trophy events')
    return errors


if __name__ == '__main__':
    data = json.loads((Path(__file__).parent/'reviewed_facts.json').read_text())
    errors = validate(data)
    for error in errors:
        print('FAIL:', error)
    if errors:
        raise SystemExit(1)
    print(f"PASS: {len(data['entities'])} identities, {len(data['facts'])} facts; gameplay remains disabled.")
