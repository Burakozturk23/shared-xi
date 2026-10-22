"""Download and validate the latest Kaggle Parquet, without changing bundled assets."""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path

from build_snapshot import build, timestamp

HANDLE = 'adrianjuliusaluoch/live-european-football-match-results'
FILENAME = 'football_matches.parquet'


def prepare(path, now=None):
    import pyarrow.parquet as pq
    now = now or datetime.now(timezone.utc)
    path = Path(path)
    if not 0 < path.stat().st_size <= 100_000_000:
        raise ValueError('Parquet size outside allowed bounds')
    parquet = pq.ParquetFile(path)
    if not 1000 <= parquet.metadata.num_rows <= 2_000_000:
        raise ValueError('Unexpected source row count')
    payload, report = build(parquet.read().to_pylist())
    rejected = report['rejectedLatest']
    if len(rejected) > 50 or len(rejected) > report['uniqueIds'] * 0.005 or report['acceptedMatches'] < 1000:
        raise ValueError('Latest records failed validation; nothing will be published')
    source_time = timestamp(payload['sourceUpdatedAt'])
    if source_time > now + timedelta(minutes=5) or now - source_time > timedelta(days=3):
        raise ValueError('Source is stale or future-dated')
    today = now.astimezone(timezone(timedelta(hours=3))).date().isoformat()
    if not payload['coverageStart'] <= today <= payload['coverageEnd']:
        raise ValueError('Source coverage does not include today')
    payload['import'] = {'dataset': HANDLE, 'parquetSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'quarantinedIds': [r['id'] for r in rejected]}
    return payload, report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, help='Validate a local Parquet instead of downloading')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    path = args.input
    if path is None:
        import kagglehub
        path = kagglehub.dataset_download(HANDLE, path=FILENAME, force_download=True)
    payload, report = prepare(path)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({k: report[k] for k in ['inputRows', 'acceptedMatches', 'sourceUpdatedAt',
                                         'coverageStart', 'coverageEnd', 'rejectedLatest']}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # HTTP exception strings can contain authentication/redirect details.
        raise SystemExit('Kaggle download/validation failed (' + type(error).__name__ + '); previous data retained')
