"""Deterministic import of the user-supplied football-data-shaped Parquet export.

A snapshot is not a live feed. Pick the newest observation per provider match ID;
never relabel old games as today's games or fall back from a corrupt latest row.
"""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta
import gzip
import hashlib
import io
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/daily_fixtures/source/football-matches.zip'
OUTPUT = ROOT / 'functions/config/daily_fixture_snapshot.json.gz'
REPORT = ROOT / 'tools/daily_fixtures/audit.json'
COMPETITIONS = {
    'PL': [39, 'Premier League', 'England'], 'PD': [140, 'La Liga', 'Spain'],
    'BL1': [78, 'Bundesliga', 'Germany'], 'SA': [135, 'Serie A', 'Italy'],
    'FL1': [61, 'Ligue 1', 'France'], 'DED': [88, 'Eredivisie', 'Netherlands'],
    'PPL': [94, 'Primeira Liga', 'Portugal'], 'ELC': [40, 'Championship', 'England'],
    'BSA': [71, 'Brasileirão Série A', 'Brazil'], 'CL': [2, 'Şampiyonlar Ligi', 'Europe'],
}
STATUSES = {'SCHEDULED', 'TIMED', 'IN_PLAY', 'PAUSED', 'EXTRA_TIME',
            'PENALTY_SHOOTOUT', 'FINISHED', 'SUSPENDED', 'POSTPONED', 'CANCELLED', 'AWARDED'}
FIELDS = ['id', 'utcDate', 'status', 'competition.code', 'homeTeam.id', 'awayTeam.id',
          'lastUpdated', 'score.fullTime.home', 'score.fullTime.away']

def timestamp(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('Timezone required')
    return result

def day(value):
    return timestamp(value).astimezone(timezone(timedelta(hours=3))).date().isoformat()

def score(value):
    if value is None:
        return None
    if value < 0 or value != int(value):
        raise ValueError('Invalid score')
    return int(value)

def build(rows):
    versions = defaultdict(list)
    invalid_observations = 0
    for row in rows:
        timestamp(row['lastUpdated'])
        versions[row['id']].append(row)
        invalid_observations += row['status'] not in STATUSES
    matches, teams, rejected = [], {}, []
    for identity, observations in sorted(versions.items()):
        latest_time = max(timestamp(r['lastUpdated']) for r in observations)
        newest = [r for r in observations if timestamp(r['lastUpdated']) == latest_time]
        if len({json.dumps([r.get(k) for k in FIELDS]) for r in newest}) != 1:
            rejected.append({'id': identity, 'reason': 'conflicting_latest_observations'})
            continue
        r = newest[0]
        try:
            if not isinstance(identity, int) or not 0 < identity < 1_000_000_000:
                raise ValueError('Invalid identity')
            timestamp(r['utcDate'])
            if r['status'] not in STATUSES or r['competition.code'] not in COMPETITIONS:
                raise ValueError('Unknown status or competition')
            if r['homeTeam.id'] == r['awayTeam.id']:
                raise ValueError('Same team')
            for side in ['homeTeam', 'awayTeam']:
                if not isinstance(r[side+'.id'], int) or r[side+'.id'] <= 0 or not r[side+'.name']:
                    raise ValueError('Invalid team')
            values = [r.get(k) for k in FIELDS]
            values[-2:] = [score(v) for v in values[-2:]]
            matches.append(values)
            for side in ['homeTeam', 'awayTeam']:
                teams[str(r[side+'.id'])] = r[side+'.name']
        except (ValueError, TypeError, KeyError) as error:
            rejected.append({'id': identity, 'reason': str(error)})
    if not matches:
        raise ValueError('No valid matches')
    dates = [day(r[1]) for r in matches]
    payload = {'schemaVersion': 1, 'provider': 'football-data-snapshot',
               'sourceUpdatedAt': max((r[6] for r in matches), key=timestamp),
               'coverageStart': min(dates), 'coverageEnd': max(dates),
               'competitions': COMPETITIONS, 'teams': teams, 'columns': FIELDS, 'matches': matches}
    report = {'inputRows': len(rows), 'uniqueIds': len(versions), 'acceptedMatches': len(matches),
              'supersededOrDuplicateRows': len(rows)-len(versions),
              'invalidStatusObservations': invalid_observations, 'rejectedLatest': rejected,
              'competitions': dict(sorted(Counter(r[3] for r in matches).items())),
              'statuses': dict(sorted(Counter(r[2] for r in matches).items())),
              'coverageStart': min(dates), 'coverageEnd': max(dates),
              'sourceUpdatedAt': payload['sourceUpdatedAt'], 'turkishLeagueIncluded': False,
              'provenance': 'User-supplied export; football-data.org schema. No live subscription implied.'}
    return payload, report

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    import pyarrow.parquet as pq
    source = SOURCE.read_bytes()
    with zipfile.ZipFile(io.BytesIO(source)) as archive:
        member = archive.getinfo('football_matches.parquet')
        if member.file_size > 20_000_000:
            raise ValueError('Unexpected source size')
        raw = archive.read(member)
    payload, report = build(pq.read_table(io.BytesIO(raw)).to_pylist())
    packed = gzip.compress(json.dumps(payload, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode(), mtime=0)
    report.update({'sourceZipSha256': hashlib.sha256(source).hexdigest(),
                   'sourceParquetSha256': hashlib.sha256(raw).hexdigest(),
                   'outputSha256': hashlib.sha256(packed).hexdigest()})
    audit = (json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True)+'\n').encode()
    for path, data in [(OUTPUT, packed), (REPORT, audit)]:
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                raise SystemExit('Snapshot drift: '+str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
