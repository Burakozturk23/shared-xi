import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path
from apply_legend_portrait_players import ROOT, REVIEW, SOURCE, REVISION, apply
from apply_roster_expansion import norm

DB = ROOT/'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT/'assets/runtime/linkball_game_data_v4_manifest.json'

class LegendPortraitPlayersTests(unittest.TestCase):
    def test_reviewed_identities_and_exact_link_count(self):
        review = json.loads(REVIEW.read_text(encoding='utf-8'))
        self.assertEqual(len(review['players']), 21)
        self.assertEqual(sum(len(r['clubs']) for r in review['players']), 83)
        ids = {r['id'] for r in review['players']}
        self.assertEqual(len(ids), 21)
        with sqlite3.connect(DB) as c:
            for r in review['players']:
                self.assertEqual(c.execute('SELECT name FROM players WHERE id=?',(r['id'],)).fetchone(), (r['name'],))
                for club in r['clubs']:
                    self.assertTrue(c.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?',
                                              (r['id'],club['id'])).fetchone())
                rows = c.execute('''SELECT DISTINCT p.id FROM players p JOIN player_search_terms s ON s.player_id=p.id
                    WHERE (p.selection_rank BETWEEN 1 AND 30000 OR
                    (p.source IN ('reviewed-player','worldcup26-roster') AND p.answer_eligible=1))
                    AND s.compact_term LIKE ?''', ('%'+norm(r['name']).replace(' ','')+'%',)).fetchall()
                self.assertIn((r['id'],), rows)
            added_links = c.execute('SELECT COUNT(*) FROM player_clubs WHERE source=?',
                                    ('reviewed:legend-portraits:2026-10-01',)).fetchone()[0]
            self.assertEqual(added_links, 83)
            self.assertTrue(
                any(
                    item.get('id') == REVISION
                    for item in json.loads(MANIFEST.read_text(encoding='utf-8')).get('reviewedAdditions', [])
                )
            )
            self.assertEqual(c.execute("SELECT COUNT(*) FROM players WHERE position IN ('GK','DF','MF','FW')").fetchone()[0], 0)

    def test_idempotency_and_changed_evidence_rejected_without_writes(self):
        with tempfile.TemporaryDirectory() as td:
            db, manifest, review = [Path(td)/n for n in ('data.sqlite','manifest.json','review.json')]
            shutil.copy2(DB,db); shutil.copy2(MANIFEST,manifest); shutil.copy2(REVIEW,review)
            before = (db.read_bytes(),manifest.read_bytes())
            apply(db,manifest,review)
            self.assertEqual(before,(db.read_bytes(),manifest.read_bytes()))
            review.write_text('{}',encoding='utf-8')
            with self.assertRaises(ValueError):
                apply(db,manifest,review)
            self.assertEqual(before,(db.read_bytes(),manifest.read_bytes()))

if __name__ == '__main__':
    unittest.main()
