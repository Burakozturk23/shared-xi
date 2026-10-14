import copy
import json
from pathlib import Path
import sqlite3
import unittest

from audit import DEFAULT_DB, audit, open_readonly
from validate import validate


class ResearchDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.seed = json.loads((Path(__file__).parent/'reviewed_facts.json').read_text())

    def setUp(self):
        self.data = copy.deepcopy(self.seed)

    def test_checked_seed(self):
        self.assertEqual(validate(self.data), [])

    def test_unknown_cannot_be_numeric_zero(self):
        self.data['facts'][0]['value'] = None
        self.assertIn('unknown/negative/noninteger value', validate(self.data))

    def test_duplicate_season_rejected_even_if_total_changed(self):
        f = self.data['facts'][0]
        f['events'].append(copy.deepcopy(f['events'][0]))
        f['value'] += 1
        self.assertIn('duplicate season award', validate(self.data))

    def test_coach_and_player_roles_cannot_mix(self):
        self.data['facts'][0]['entity'] = 'player:zinedine-zidane'
        self.assertIn('metric role mismatch', validate(self.data))

    def test_palmares_is_not_primary_verification(self):
        self.data['facts'][0]['sources'] = ['palmares_managers']
        self.assertIn('primary evidence required', validate(self.data))

    def test_partial_metric_cannot_assert_total(self):
        self.data['facts'][0]['coverage'] = 'partial'
        self.assertIn('incomplete metric cannot assert a total', validate(self.data))

    def test_future_season_not_merged_into_snapshot(self):
        self.data['facts'][0]['events'][0]['year'] = 2026
        self.assertIn('event beyond cutoff', validate(self.data))

    def test_cannot_enable_gameplay(self):
        self.data['facts'][0]['enabled'] = True
        self.assertIn('unreviewed gameplay promotion', validate(self.data))

    def test_wrong_ronaldo_identity_rejected(self):
        e = next(e for e in self.data['entities'] if e['key']=='player:ronaldo-nazario')
        e['local']['id'] = 6887
        self.assertIn('local identity changed', validate(self.data))

    def test_database_version_pinned(self):
        self.data['baseDatabaseSha256'] = '0'*64
        self.assertIn('database hash mismatch', validate(self.data))

    def test_audit_reconciles_counts_and_retains_missing(self):
        report = audit(DEFAULT_DB, self.data)
        total = report['counts']['players']
        for info in report['playerFields'].values():
            self.assertEqual(info['present']+info['missing_in_population'], total)
            self.assertLessEqual(info['zero']+info['positive'], info['present'])
        self.assertGreater(report['coaches']['missingClubLinks'], 0)
        self.assertGreater(len(report['reviewedSupplement']['unmapped']), 0)
        self.assertTrue(all(not m['enabled'] for m in report['reviewedSupplement']['metrics']))

    def test_database_connection_rejects_writes(self):
        with open_readonly(DEFAULT_DB) as c:
            with self.assertRaises(sqlite3.OperationalError):
                c.execute('CREATE TABLE duel_readonly_probe (id INTEGER)')


if __name__ == '__main__':
    unittest.main()
