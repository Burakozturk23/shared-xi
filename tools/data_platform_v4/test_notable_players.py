import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path
from apply_notable_players import ROOT, REVIEW, SOURCE, apply
from apply_roster_expansion import norm

DB = ROOT/'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT/'assets/runtime/linkball_game_data_v4_manifest.json'


class NotablePlayersTests(unittest.TestCase):
    def test_reviewed_identities_clubs_and_turkish_search(self):
        review = json.loads(REVIEW.read_text())
        with sqlite3.connect(DB) as c:
            self.assertEqual(len(review['players']), 45)
            self.assertEqual(
                c.execute(
                    'SELECT COUNT(*) FROM players WHERE id BETWEEN 4000000001 AND 4000000045 AND source=?',
                    (SOURCE,),
                ).fetchone()[0],
                45,
            )
            for r in review['players'] + review['corrections']:
                self.assertEqual(c.execute('SELECT name FROM players WHERE id=?', (r['id'],)).fetchone(), (r['name'],))
                for club in r['clubs']:
                    self.assertTrue(c.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?', (r['id'],club['id'])).fetchone())
                for label in [r['name'], norm(r['name'])]:
                    rows = c.execute('''SELECT DISTINCT p.id FROM players p JOIN player_search_terms s ON s.player_id=p.id
                        WHERE (p.selection_rank BETWEEN 1 AND 30000 OR
                        (p.source IN ('reviewed-player','worldcup26-roster') AND p.answer_eligible=1))
                        AND s.compact_term LIKE ?''', ('%'+norm(label).replace(' ','')+'%',)).fetchall()
                    self.assertIn((r['id'],), rows)
            common = c.execute('''SELECT a.player_id FROM player_clubs a JOIN player_clubs b ON a.player_id=b.player_id
                WHERE a.club_id=36 AND b.club_id=114''').fetchall()
            self.assertIn((4000000001,), common)
            self.assertEqual(c.execute("SELECT COUNT(*) FROM players WHERE position IN ('GK','DF','MF','FW')").fetchone()[0], 0)
            self.assertEqual(c.execute('SELECT COUNT(*) FROM transfers').fetchone()[0], 33994)
            self.assertEqual(c.execute('SELECT COUNT(*) FROM career_spells').fetchone()[0], 37966)

    def test_idempotency_and_changed_evidence_rejected_without_writes(self):
        with tempfile.TemporaryDirectory() as td:
            db, manifest, review = [Path(td)/n for n in ('data.sqlite','manifest.json','review.json')]
            shutil.copy2(DB,db); shutil.copy2(MANIFEST,manifest); shutil.copy2(REVIEW,review)
            before = (db.read_bytes(),manifest.read_bytes())
            apply(db,manifest,review)
            self.assertEqual(before,(db.read_bytes(),manifest.read_bytes()))
            review.write_text('{}')
            with self.assertRaises(ValueError):
                apply(db,manifest,review)
            self.assertEqual(before,(db.read_bytes(),manifest.read_bytes()))


if __name__ == '__main__':
    unittest.main()
