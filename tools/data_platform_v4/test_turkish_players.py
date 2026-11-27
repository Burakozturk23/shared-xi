import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

from apply_turkish_players import ROOT, REVIEW, REVISION, LINK_SOURCE, apply
from apply_club_twins import canonical

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'


class TurkishPlayersTests(unittest.TestCase):
    def test_players_have_identity_links_and_ordered_careers(self):
        review = json.loads(REVIEW.read_text(encoding='utf-8'))
        twin = canonical(DB)  # v4-2026-11-23.3 merged twin club rows: a reviewed twin id now lives on its primary row.
        self.assertEqual(len(review['players']), 45)
        with sqlite3.connect(DB) as con:
            for p in review['players']:
                self.assertEqual(con.execute('SELECT name,country,source,answer_eligible FROM players WHERE id=?',
                                             (p['id'],)).fetchone(), (p['name'], 'Türkiye', 'reviewed-player', 1))
                self.assertTrue(con.execute('SELECT 1 FROM player_search_terms WHERE player_id=?', (p['id'],)).fetchone())
                self.assertEqual(set(con.execute('SELECT club_id FROM player_clubs WHERE player_id=? AND source=?',
                                                 (p['id'], LINK_SOURCE))), {(twin.get(c['id'], c['id']),) for c in p['clubs']})
                spells = con.execute('SELECT club_id,start_date,end_date FROM career_spells WHERE player_id=? ORDER BY sequence',
                                     (p['id'],)).fetchall()
                self.assertEqual(spells, [(twin.get(s['id'], s['id']), str(s['startYear']) if s['startYear'] else None,
                                           str(s['endYear']) if s['endYear'] else None) for s in p['spells']])

    def test_club_country_discovery_finds_the_reported_players(self):
        # Barcelona (131) / Real Madrid (418) × Turkey returned 0 before the fix.
        query = '''SELECT p.name FROM players p JOIN player_clubs pc ON pc.player_id=p.id
                   WHERE pc.club_id=? AND p.country COLLATE NOCASE IN ('Turkey','türkiye')'''
        with sqlite3.connect(DB) as con:
            madrid = {n for (n,) in con.execute(query, (418,))}
            self.assertTrue({'Nuri Şahin', 'Hamit Altıntop', 'Arda Güler'} <= madrid)
            self.assertIn('Arda Turan', {n for (n,) in con.execute(query, (131,))})
            # Reserve teams never become first-team links.
            nuri = next(p for p in json.loads(REVIEW.read_text(encoding='utf-8'))['players'] if p['name'] == 'Nuri Şahin')
            self.assertEqual(sum(1 for s in nuri['spells'] if s['id'] == 16), 3)

    def test_idempotency_and_evidence_guard(self):
        with tempfile.TemporaryDirectory() as td:
            db, manifest, evidence = [Path(td) / name for name in ('data.sqlite', 'manifest.json', 'review.json')]
            for source, dest in [(DB, db), (MANIFEST, manifest), (REVIEW, evidence)]:
                shutil.copy2(source, dest)
            before = (db.read_bytes(), manifest.read_bytes())
            self.assertEqual(apply(db, manifest, evidence)['id'], REVISION)
            self.assertEqual(before, (db.read_bytes(), manifest.read_bytes()))
            evidence.write_text('{}')
            with self.assertRaises(ValueError):
                apply(db, manifest, evidence)


if __name__ == '__main__':
    unittest.main()
