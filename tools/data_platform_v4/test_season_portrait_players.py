import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

from apply_season_portrait_players import ROOT, REVIEW, REVISION, LINK_SOURCE, apply
from apply_roster_expansion import norm

DB = ROOT/'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT/'assets/runtime/linkball_game_data_v4_manifest.json'


class SeasonPortraitPlayersTests(unittest.TestCase):
    def test_three_missing_identities_and_minimal_links(self):
        review = json.loads(REVIEW.read_text(encoding='utf-8'))
        self.assertEqual(len(review['players']), 3)
        self.assertEqual(sum(len(r['clubs']) for r in review['players']), 3)
        with sqlite3.connect(DB) as con:
            for r in review['players']:
                self.assertEqual(
                    con.execute('SELECT name FROM players WHERE id=?',(r['id'],)).fetchone(),
                    (r['name'],),
                )
                for club in r['clubs']:
                    self.assertTrue(con.execute(
                        'SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?',
                        (r['id'],club['id']),
                    ).fetchone())
                compact = norm(r['name']).replace(' ','')
                rows = con.execute(
                    'SELECT compact_term FROM player_search_terms WHERE player_id=?',
                    (r['id'],),
                ).fetchall()
                self.assertTrue(any(compact in norm(x[0]).replace(' ','') for x in rows))
            self.assertEqual(
                con.execute('SELECT COUNT(*) FROM player_clubs WHERE source=?',(LINK_SOURCE,)).fetchone()[0],
                3,
            )
            self.assertEqual(
                con.execute("SELECT value FROM metadata WHERE key='data_revision'").fetchone(),
                (REVISION,),
            )

    def test_idempotent_and_changed_evidence_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            db, manifest, review = [Path(td)/n for n in ('data.sqlite','manifest.json','review.json')]
            shutil.copy2(DB,db)
            shutil.copy2(MANIFEST,manifest)
            shutil.copy2(REVIEW,review)
            before=(db.read_bytes(),manifest.read_bytes())
            apply(db,manifest,review)
            self.assertEqual(before,(db.read_bytes(),manifest.read_bytes()))
            review.write_text('{}',encoding='utf-8')
            with self.assertRaises(ValueError):
                apply(db,manifest,review)
            self.assertEqual(before,(db.read_bytes(),manifest.read_bytes()))


if __name__ == '__main__':
    unittest.main()
