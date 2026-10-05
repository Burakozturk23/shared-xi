import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

from apply_avatar_careers import ROOT, REVIEW, REVISION, LINK_SOURCE, apply

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'


class AvatarCareersTests(unittest.TestCase):
    def test_reviewed_players_have_search_identity_and_ordered_careers(self):
        review = json.loads(REVIEW.read_text())
        self.assertEqual(len(review['players']), 38)
        with sqlite3.connect(DB) as con:
            for p in review['players']:
                self.assertEqual(con.execute('SELECT name,country,playable,answer_eligible FROM players WHERE id=?',
                                 (p['id'],)).fetchone(), (p['name'], p['country'], int(p['playable']), int(p['playable'])))
                self.assertTrue(con.execute('SELECT 1 FROM player_search_terms WHERE player_id=?', (p['id'],)).fetchone())
                self.assertEqual(set(con.execute('SELECT club_id FROM player_clubs WHERE player_id=?', (p['id'],))),
                                 {(c['id'],) for c in p['clubs']})
                spells = con.execute('SELECT club_id,start_date,end_date,appearances FROM career_spells WHERE player_id=? ORDER BY sequence', (p['id'],)).fetchall()
                self.assertEqual(spells, [(s['id'], str(s['startYear']) if s['startYear'] else None,
                                          str(s['endYear']) if s['endYear'] else None, None) for s in p['spells']])
            ids = {p['key']: p['id'] for p in review['players']}
            for key, namesake in [('cafu', 466279), ('guti', 186623), ('burak_yilmaz', 164148), ('alex_de_souza', 15420)]:
                self.assertNotEqual(ids[key], namesake)
            # Clubs managed do not leak into a former player's career.
            for key, forbidden in [('jose_mourinho', 631), ('fatih_terim', 5), ('unai_emery', 11), ('carlo_ancelotti', 418)]:
                self.assertFalse(con.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?', (ids[key], forbidden)).fetchone())

    def test_coach_json_sqlite_and_portraits_agree(self):
        review = json.loads(REVIEW.read_text())
        legacy = {c['id']: c for c in json.loads((ROOT / 'assets/data/coaches_min.json').read_text())}
        portraits = json.loads((ROOT / 'tools/uploaded_portraits/manifest.json').read_text())
        with sqlite3.connect(DB) as con:
            database = {c['id']: c for (payload,) in con.execute('SELECT payload_json FROM coaches') for c in [json.loads(payload)]}
            for c in review['coaches']:
                self.assertEqual(legacy[c['id']], database[c['id']])
                self.assertEqual(legacy[c['id']]['clubIds'], c['clubIds'])
                self.assertEqual(portraits['coachKeys'][c['id']], c['avatarKey'])
            by_name = {c['name']: c for c in review['coaches']}
            self.assertNotIn(131, by_name['Unai Emery']['clubIds'])
            self.assertNotIn(418, by_name['Luis Enrique']['clubIds'])
            self.assertEqual(by_name['Didier Deschamps']['clubIds'], [162, 506, 244])

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
