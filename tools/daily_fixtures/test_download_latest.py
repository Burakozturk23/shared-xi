import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

from download_latest import prepare
from test_snapshot import row

NOW = datetime(2026, 10, 21, 10, tzinfo=timezone.utc)


class DownloadValidationTests(unittest.TestCase):
    def prepare_rows(self, rows, now=NOW):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'matches.parquet'
            pq.write_table(pa.Table.from_pylist(rows), path)
            return prepare(path, now=now)

    def test_latest_scores_stay_null_and_valid_zero_stays_zero(self):
        rows = [row(id=i, **{'score.fullTime.home': None, 'score.fullTime.away': 0}) for i in range(1, 1001)]
        payload, _ = self.prepare_rows(rows)
        self.assertEqual(payload['matches'][0][-2:], [None, 0])
        self.assertEqual(payload['import']['quarantinedIds'], [])

    def test_isolated_corrupt_latest_is_quarantined_without_using_old_observation(self):
        rows = [row(id=i) for i in range(1, 1002)]
        rows.append(row(id=1001, status='2026-10-21 20:00:00Z', lastUpdated='2026-10-21T01:00:00Z'))
        payload, _ = self.prepare_rows(rows)
        self.assertEqual(payload['import']['quarantinedIds'], [1001])
        self.assertNotIn(1001, [r[0] for r in payload['matches']])

    def test_many_corrupt_records_block_publication(self):
        rows = [row(id=i) for i in range(1, 1101)]
        for r in rows[:10]:
            r['status'] = 'invalid'
        with self.assertRaises(ValueError):
            self.prepare_rows(rows)

    def test_old_file_is_not_relabelled_as_fresh(self):
        rows = [row(id=i) for i in range(1, 1001)]
        with self.assertRaises(ValueError):
            self.prepare_rows(rows, now=NOW + timedelta(days=4))


if __name__ == '__main__':
    unittest.main()
