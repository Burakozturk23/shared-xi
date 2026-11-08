"""Tests for fetch_coach_tenures (run: py -3 -m unittest tools/pvp/test_coach_tenures.py)."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import fetch_coach_tenures as F  # noqa: E402

HERE = os.path.dirname(__file__)
CLUBS = {
    '141': {'id': '141', 'name': 'Galatasaray', 'country': 'Türkiye'},
    '114': {'id': '114', 'name': 'Beşiktaş JK', 'country': 'Türkiye'},
    '430': {'id': '430', 'name': 'ACF Fiorentina', 'country': 'Italy'},
    '294': {'id': '294', 'name': 'SL Benfica', 'country': 'Portugal'},
    '777': {'id': '777', 'name': 'CD Ben', 'country': 'Portugal'},
    '614': {'id': '614', 'name': 'CR Flamengo', 'country': 'Brazil'},
}


def fixture():
    with open(os.path.join(HERE, 'fixtures', 'wikidata_terim.json'), encoding='utf-8') as f:
        return json.load(f)


class TenureTests(unittest.TestCase):
    def test_parse_reads_start_end_and_club(self):
        rows = F.parse_tenures(fixture())
        gs = [r for r in rows if r['label'] == 'Galatasaray S.K.']
        self.assertEqual(gs[0]['start'], '1996-07-01')
        self.assertEqual(gs[0]['end'], '2000-06-30')
        self.assertEqual(gs[0]['country'], 'Turkey')

    def test_missing_start_is_dropped(self):
        tenures, report = F.build_one('coach_171', 'Fatih Terim', F.parse_tenures(fixture()), CLUBS, {})
        self.assertFalse(any(t['clubId'] == '430' and t['start'] is None for t in tenures))
        self.assertTrue(any('başlangıç tarihi yok' in line for line in report))

    def test_unmapped_club_is_reported(self):
        tenures, report = F.build_one('coach_171', 'Fatih Terim', F.parse_tenures(fixture()), CLUBS, {})
        self.assertFalse(any(t['clubId'] is None for t in tenures))
        self.assertTrue(any('AC Milan' in line and 'eşlenemedi' in line for line in report))

    def test_multiple_spells_same_club_kept(self):
        tenures, _ = F.build_one('coach_171', 'Fatih Terim', F.parse_tenures(fixture()), CLUBS, {})
        self.assertEqual(len([t for t in tenures if t['clubId'] == '141']), 2)

    def test_map_club_strips_affixes_and_checks_country(self):
        self.assertEqual(F.map_club('Galatasaray S.K.', 'Turkey', CLUBS, {}), '141')
        self.assertEqual(F.map_club('Beşiktaş J.K.', 'Turkey', CLUBS, {}), '114')
        self.assertIsNone(F.map_club('Galatasaray S.K.', 'Italy', CLUBS, {}))
        self.assertEqual(F.map_club('S.L. Benfica', 'Portugal', CLUBS, {}), '294')
        self.assertEqual(F.map_club('Clube de Regatas do Flamengo', 'Brazil', CLUBS, {}), '614')
        self.assertEqual(F.map_club('Whatever', 'Turkey', CLUBS, {'Q1': '141'}, qid='Q1'), '141')


if __name__ == '__main__':
    unittest.main()
