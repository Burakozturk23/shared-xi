import io
import json
from unittest.mock import patch
from pathlib import Path
import sqlite3
import tempfile
import unittest
from datetime import date
from api_football_sync import Client, collect, index_database, match, validate_mapping


class FakeClient:
    calls = 0
    def get(self, endpoint, **params):
        self.calls += 1
        if endpoint == 'teams':
            return {'response': [{'team': {'id': x, 'name': n}} for x, n in [(10, 'Old'), (20, 'New')]]}
        if endpoint == 'players/squads':
            return {'response': [{'team': {'id': params['team']}, 'players': [{'id': 99}]}]}
        event = {'date': '2026-08-01', 'type': 'Loan', 'teams': {'out': {'id': 10, 'name': 'Old'}, 'in': {'id': 20, 'name': 'New'}}}
        return {'response': [{'player': {'id': 99, 'name': 'Test Player'}, 'transfers': [event, {**event, 'date': '2025-08-01'}]}]}


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.executescript('''CREATE TABLE players(id INTEGER PRIMARY KEY,name TEXT);
CREATE TABLE clubs(id INTEGER PRIMARY KEY,name TEXT);
CREATE TABLE player_aliases(player_id INTEGER,alias TEXT);
CREATE TABLE player_clubs(player_id INTEGER,club_id INTEGER);
INSERT INTO players VALUES(1,'Test Player'),(2,'Test Player');
INSERT INTO clubs VALUES(7,'Old'),(8,'New');
INSERT INTO player_clubs VALUES(1,7);''')
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name)/'report.json'

    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()

    def test_names_are_candidates_never_automatic_ids(self):
        result = match({'id': 99, 'name': 'Test Player'}, 'players', index_database(self.db), {})
        self.assertEqual(result['candidates'], [1, 2])
        self.assertIsNone(result['canonicalId'])

    def test_dedup_dates_mapping_and_no_mutation(self):
        before = list(self.db.iterdump())
        mapping = {'players': {'99': 1}, 'clubs': {'10': 7, '20': 8}}
        validate_mapping(self.db, mapping)
        report = collect(FakeClient(), self.db, mapping, [203], 2026, date(2026, 6, 1), date(2026, 9, 28), self.path)
        self.assertTrue(report['complete'])
        self.assertEqual(len(report['transfers']), 1)
        row = report['transfers'][0]
        self.assertEqual(row['player']['canonicalId'], 1)
        self.assertFalse(row['existingDestinationLink'])
        self.assertTrue(row['inCurrentDestinationSquad'])
        self.assertFalse(row['appearanceVerified'])
        self.assertEqual(before, list(self.db.iterdump()))

    def test_missing_mapping_target_rejected(self):
        with self.assertRaises(ValueError):
            validate_mapping(self.db, {'players': {'99': 12345}})

    def test_partial_failure_is_not_success(self):
        class Failing(FakeClient):
            def get(self, endpoint, **params):
                if endpoint == 'transfers' and params['team'] == 20:
                    raise ValueError('Request budget reached')
                return super().get(endpoint, **params)
        report = collect(Failing(), self.db, {}, [203], 2026, date(2026, 6, 1), date(2026, 9, 28), self.path)
        self.assertFalse(report['complete'])
        self.assertEqual(report['teamsCompleted'], [10])
        self.assertEqual(len(json.loads(self.path.read_text())['transfers']), 1)

    def test_offline_missing_cache_fails_without_request(self):
        client = Client('', Path(self.tmp.name), offline=True)
        with self.assertRaises(ValueError):
            client.get('teams', league=203, season=2026)
        self.assertEqual(client.calls, 0)

    def test_cached_resume_and_no_credential_persistence(self):
        cache = Path(self.tmp.name)
        client = Client('secret-value', cache, budget=1)
        body = json.dumps({'response': [{'team': {'id': 20}}], 'errors': [], 'paging': {'total': 1}}).encode()
        with patch('api_football_sync.urlopen', return_value=io.BytesIO(body)) as network:
            first = client.get('teams', season=2026, league=203)
            self.assertEqual(client.get('teams', league=203, season=2026), first)
            network.assert_called_once()
        self.assertNotIn('secret-value', next(cache.glob('*.json')).read_text())
        self.assertEqual(Client('', cache, offline=True).get('teams', league=203, season=2026), first)
        with self.assertRaises(ValueError):
            client.get('transfers', team=20)

    def test_api_errors_are_not_cached_or_echoed(self):
        client = Client('secret-value', Path(self.tmp.name))
        body = json.dumps({'response': [], 'errors': {'token': 'secret-value'}}).encode()
        with patch('api_football_sync.urlopen', return_value=io.BytesIO(body)):
            with self.assertRaises(ValueError) as error:
                client.get('transfers', team=20)
        self.assertNotIn('secret-value', str(error.exception))
        self.assertEqual(list(Path(self.tmp.name).glob('*.json')), [])

    def test_empty_coverage_is_not_success(self):
        class Empty(FakeClient):
            def get(self, endpoint, **params):
                return {'response': []}
        report = collect(Empty(), self.db, {}, [203], 2026, date(2026, 6, 1), date(2026, 9, 28), self.path)
        self.assertFalse(report['complete'])


if __name__ == '__main__':
    unittest.main()
