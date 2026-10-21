import copy
import unittest
from build_snapshot import build, day

def row(**kwargs):
    return {'id': 7, 'utcDate': '2026-10-20T22:30:00Z', 'lastUpdated': '2026-10-20T12:00:00Z',
            'status': 'TIMED', 'competition.code': 'CL', 'homeTeam.id': 1, 'awayTeam.id': 2,
            'homeTeam.name': 'Home', 'awayTeam.name': 'Away', **kwargs}

class ImportTests(unittest.TestCase):
    def test_latest_over_duplicate_and_invalid_old_version(self):
        old = row(status='2026-10-20 20:00:00Z')
        new = row(status='FINISHED', lastUpdated='2026-10-21T01:00:00Z')
        result, report = build([old, old, new, copy.deepcopy(new)])
        self.assertEqual(len(result['matches']), 1)
        self.assertEqual(result['matches'][0][2], 'FINISHED')
        self.assertEqual(report['invalidStatusObservations'], 2)
        self.assertEqual(report['supersededOrDuplicateRows'], 3)
        self.assertEqual(day(result['matches'][0][1]), '2026-10-21')

    def test_invalid_latest_is_not_silently_replaced_by_older_version(self):
        valid_other = row(id=9)
        _, report = build([row(), row(status='nonsense', lastUpdated='2026-10-21T01:00:00Z'), valid_other])
        self.assertEqual(report['acceptedMatches'], 1)
        self.assertEqual(report['rejectedLatest'][0]['id'], 7)

    def test_conflicting_latest_quarantined_and_timezone_required(self):
        _, report = build([row(), row(status='POSTPONED'), row(id=9)])
        self.assertEqual(report['rejectedLatest'][0]['reason'], 'conflicting_latest_observations')
        with self.assertRaises(ValueError):
            day('2026-10-20T22:30:00')

if __name__ == '__main__':
    unittest.main()
