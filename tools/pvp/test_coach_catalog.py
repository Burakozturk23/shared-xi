"""Coach criteria in the PvP catalog (run: py -3 -m unittest tools/pvp/test_coach_catalog.py).

Unit tests for the overlap rule, then checks on the generated functions/config/pvp_catalog.json.gz
(regenerate with `py -3 tools/pvp/build_catalog.py`).
"""
import gzip
import json
import os
import sys
import unittest

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import build_catalog as B  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
TEN = {'c1': [{'clubId': '141', 'start': '1996-07-01', 'end': '2000-06-30'},
              {'clubId': '141', 'start': '2011-06-08', 'end': '2013-09-24'}]}


class OverlapTests(unittest.TestCase):
    def test_overlap_by_one_day_matches(self):
        spells = {'p1': [('141', '2000-06-30', '2003-06-30')], 'p2': [('141', '1990-01-01', '1996-07-01')],
                  'p3': [('141', '2000-07-01', '2001-01-01')]}
        self.assertEqual(B.coach_members(spells, TEN, {}, '2026-11-08')['c1'], {'p1', 'p2'})

    def test_spell_between_two_tenures_does_not_match(self):
        spells = {'p1': [('141', '2003-01-01', '2010-12-31')], 'p2': [('141', '2012-01-01', '2012-06-30')]}
        self.assertEqual(B.coach_members(spells, TEN, {}, '2026-11-08')['c1'], {'p2'})

    def test_open_ended_spell_is_ongoing(self):
        ten = {'c2': [{'clubId': '141', 'start': '2022-06-23', 'end': None}]}
        spells = {'p1': [('141', '2019-01-01', None)], 'p2': [('141', '2010-01-01', '2015-01-01')]}
        self.assertEqual(B.coach_members(spells, ten, {}, '2026-11-08')['c2'], {'p1'})

    def test_spell_at_a_twin_club_id_counts(self):
        spells = {'p1': [('1000000141', '1997-01-01', '1998-01-01')]}
        self.assertEqual(B.coach_members(spells, TEN, {'141': ['1000000141']}, '2026-11-08')['c1'], {'p1'})

    def test_spell_without_start_is_ignored(self):
        self.assertEqual(B.coach_members({'p1': [('141', '', '1998-01-01')]}, TEN, {}, '2026-11-08')['c1'], set())


def catalog():
    with gzip.open(os.path.join(ROOT, 'functions', 'config', 'pvp_catalog.json.gz'), 'rt', encoding='utf-8') as f:
        return json.load(f)


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = catalog()
        cls.members = {}
        for pid, p in cls.c['players'].items():
            for k in p.get('coaches', []):
                cls.members.setdefault('coach:' + k, set()).add(pid)

    def coach_keys(self, keys):
        return [k for k in keys if k.startswith('coach:')]

    def test_coach_criteria_have_the_agreed_shape(self):
        terim = self.c['criteria']['coach:coach_171']
        self.assertEqual({k: terim[k] for k in ('id', 'type', 'value', 'label')},
                         {'id': 'coach:coach_171', 'type': 'coach', 'value': 'coach_171', 'label': 'Fatih Terim'})
        self.assertEqual(self.c['criteria']['coach:coach_0'].get('avatarKey'), 'pep_guardiola_coach')

    def test_ineligible_coach_not_on_boards(self):
        def eligible(k):
            m = self.members.get(k, set())
            return len(m) >= 15 and sum(1 for i in m if self.c['players'][i]['rank'] <= 3000) >= 5
        used = {k for g in self.c['grids'] for k in self.coach_keys(g['rows'] + g['cols'])}
        used |= {k for p in self.c['pairs'] for k in self.coach_keys(p['criteria'])}
        self.assertTrue(used)
        self.assertEqual([k for k in used if not eligible(k)], [])

    def test_board_mix_and_no_coach_cross(self):
        grids = self.c['grids']
        self.assertEqual(len(grids), 300)
        counts = []
        for g in grids:
            r, c = self.coach_keys(g['rows']), self.coach_keys(g['cols'])
            self.assertFalse(r and c, g['id'])
            counts.append(len(r) + len(c))
            for ans in g['answers']:
                self.assertGreaterEqual(len(ans), 3)
        self.assertLessEqual(max(counts), 2)
        share = sum(1 for n in counts if n) / 300
        self.assertTrue(0.65 <= share <= 0.85, share)
        self.assertGreater(sum(1 for n in counts if n == 2), 0)

    def test_coach_cells_hold_real_members(self):
        for g in self.c['grids']:
            cells = [(a, b) for a in g['rows'] for b in g['cols']]
            for (a, b), ans in zip(cells, g['answers']):
                for k in (a, b):
                    if k.startswith('coach:'):
                        self.assertTrue(set(ans) <= self.members[k], (g['id'], k))

    def test_coach_club_pairs_exist(self):
        pairs = [p for p in self.c['pairs'] if self.coach_keys(p['criteria'])]
        self.assertTrue(pairs)
        self.assertTrue(all(len(p['answers']) >= 6 for p in pairs))

    def test_simeone_has_no_napoli_players(self):
        napoli = [i for i, p in self.c['players'].items() if p['name'] == 'Kevin De Bruyne']
        self.assertTrue(napoli)
        self.assertNotIn('coach_52', self.c['players'][napoli[0]]['coaches'])

    def test_examples(self):
        players = self.c['players']
        def find(name):
            return [i for i, p in players.items() if p['name'] == name]
        benfica = [k for k, v in self.c['criteria'].items() if v['type'] == 'club' and v['label'] == 'SL Benfica']
        talisca = find('Talisca')
        self.assertTrue(talisca and benfica)
        self.assertIn('coach_269', players[talisca[0]]['coaches'])
        self.assertIn(benfica[0][5:], players[talisca[0]]['clubs'])
        hagi = find('Gheorghe Hagi')
        if hagi and 'coach_171' not in players[hagi[0]].get('coaches', []):
            self.skipTest('Gheorghe Hagi has no dated career_spells; Terim × Barcelona → Hagi needs them')


if __name__ == '__main__':
    unittest.main()
