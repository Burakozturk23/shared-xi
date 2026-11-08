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

    def test_youth_reserve_season_and_federation_items_never_map_to_the_senior_club(self):
        clubs = dict(CLUBS, **{'418': {'id': '418', 'name': 'Real Madrid', 'country': 'Spain'},
                               '131': {'id': '131', 'name': 'FC Barcelona', 'country': 'Spain'},
                               '9': {'id': '9', 'name': 'L\\', 'country': 'Italy'}})
        for label in ('Real Madrid Castilla', 'Real Madrid Juvenil', '2007–08 FC Barcelona season',
                      'FC Barcelona B', 'Real Madrid under 19', 'FC Barcelona II'):
            self.assertIsNone(F.map_club(label, 'Spain', clubs, {}), label)
        self.assertIsNone(F.map_club('Italian Football Federation', 'Italy', clubs, {}))
        self.assertIsNone(F.map_club('Vigor Lamezia', 'Italy', clubs, {}))
        self.assertEqual(F.map_club('Real Madrid CF', 'Spain', clubs, {}), '418')

    def test_manual_file_adds_and_drops_tenures(self):
        manual = {'add': {'coach_171': [{'clubId': '430', 'start': '2000-07-01', 'end': '2001-02-26'}]},
                  'drop': {'coach_171': [{'clubId': '141', 'start': '2011-06-08'}]}}
        tenures, report = F.build_one('coach_171', 'Fatih Terim', F.parse_tenures(fixture()), CLUBS, {}, manual)
        self.assertIn({'clubId': '430', 'start': '2000-07-01', 'end': '2001-02-26'}, tenures)
        self.assertFalse(any(t['clubId'] == '141' and t['start'] == '2011-06-08' for t in tenures))
        self.assertTrue(any('elle eklendi' in line for line in report))

    def test_duplicate_club_records_collapse_to_one_primary_with_twins(self):
        clubs = {
            '6195': {'id': '6195', 'name': 'SSC Napoli', 'country': 'Italy', 'links': 212},
            '15795': {'id': '15795', 'name': 'Napoli', 'country': 'Italy', 'links': 95},
            '583': {'id': '583', 'name': 'Paris Saint-Germain', 'country': 'France', 'links': 179},
            '1000000583': {'id': '1000000583', 'name': 'PSG', 'country': 'France', 'links': 90},
        }
        twins = F.club_twins(clubs)
        self.assertEqual(twins['6195'], ['15795'])
        self.assertEqual(twins['583'], ['1000000583'])
        self.assertEqual(F.map_club('SSC Napoli', 'Italy', clubs, {}), '6195')
        self.assertEqual(F.map_club('Paris Saint-Germain F.C.', 'France', clubs, {}), '583')

    def test_year_only_row_is_dropped_when_a_precise_row_covers_the_same_spell(self):
        rows = [{'qid': 'Q1119', 'label': 'Galatasaray S.K.', 'country': 'Turkey', 'start': s, 'end': e}
                for s, e in [('2009-01-01', '2010-01-01'), ('2009-07-01', '2010-10-19'), ('1996-01-01', None)]]
        tenures, _ = F.build_one('c', 'X', rows, CLUBS, {})
        self.assertEqual([t['start'] for t in tenures], ['1996-07-01', '2009-07-01'])  # year-only: season start

    def test_manual_replace_ignores_wikidata_rows(self):
        manual = {'replace': {'coach_171': [{'clubId': '114', 'start': '1990-01-01', 'end': '1991-01-01'}]}}
        tenures, _ = F.build_one('coach_171', 'Fatih Terim', F.parse_tenures(fixture()), CLUBS, {}, manual)
        self.assertEqual(tenures, [{'clubId': '114', 'start': '1990-01-01', 'end': '1991-01-01'}])

    def test_open_tenures_at_two_clubs_are_flagged(self):
        coaches = {'c': [{'clubId': '1', 'start': '2011-12-23', 'end': None},
                         {'clubId': '2', 'start': '2024-01-06', 'end': None}],
                   'd': [{'clubId': '3', 'start': '2025-09-13', 'end': None},
                         {'clubId': '3', 'start': '2025-09-15', 'end': None}]}
        self.assertEqual(F.open_conflicts(coaches), ['c'])

    def test_year_only_dates_become_season_bounds(self):
        self.assertEqual(F.season_bounds('1996-07-01', '2000-01-01'), ('1996-07-01', '2000-06-30'))
        self.assertEqual(F.season_bounds('2008-01-01', '2009-01-01'), ('2008-07-01', '2009-06-30'))
        self.assertEqual(F.season_bounds('2016-01-01', '2016-01-01'), ('2016-01-01', '2016-12-31'))
        self.assertEqual(F.season_bounds('2015-10-01', '2016-01-01'), ('2015-10-01', '2016-06-30'))
        self.assertEqual(F.season_bounds('2016-09-01', '2016-01-01'), ('2016-09-01', '2016-12-31'))
        self.assertEqual(F.season_bounds('2019-01-01', None), ('2019-07-01', None))


if __name__ == '__main__':
    unittest.main()
