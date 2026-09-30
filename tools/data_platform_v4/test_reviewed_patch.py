import contextlib
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from apply_reviewed_patch import ROOT, apply, digest


class ReviewedPatchTests(unittest.TestCase):
    def test_bundled_vlahovic_relationships_and_history(self):
        with sqlite3.connect(ROOT/'assets/runtime/linkball_game_data_v4.sqlite') as con:
            clubs = {r[0] for r in con.execute('SELECT club_id FROM player_clubs WHERE player_id=357498')}
            self.assertEqual(clubs, {114, 430, 506, 669})
            # Exercise the relational intersection used by discovery/Grid.
            for club in (114, 430, 669):
                found = con.execute('SELECT a.player_id FROM player_clubs a JOIN player_clubs b '
                    'ON a.player_id=b.player_id WHERE a.club_id=506 AND b.club_id=? AND a.player_id=357498', (club,)).fetchall()
                self.assertEqual(found, [(357498,)])
            self.assertEqual(con.execute('SELECT club_id FROM career_spells WHERE player_id=357498 ORDER BY sequence').fetchall(),
                             [(669,), (430,), (506,), (114,)])
            self.assertIsNone(con.execute('SELECT appearances FROM career_spells WHERE player_id=357498 AND club_id=114').fetchone()[0])
            self.assertEqual(con.execute("SELECT COUNT(*) FROM players WHERE source = 'v4'").fetchone()[0], 30135)
            manifest = json.loads((ROOT/'assets/runtime/linkball_game_data_v4_manifest.json').read_text())
            self.assertEqual(manifest['database']['sha256'], digest(ROOT/'assets/runtime/linkball_game_data_v4.sqlite'))

    def fixture(self, directory):
        db, manifest, patch = [Path(directory)/name for name in ('data.sqlite','manifest.json','patch.json')]
        with sqlite3.connect(db) as con:
            for table in ('players','clubs','transfers'):
                con.execute('CREATE TABLE '+table+'(id INTEGER PRIMARY KEY)')
            con.execute('INSERT INTO players VALUES(1)')
        manifest.write_text(json.dumps({'database': {'sha256': digest(db)}, 'counts': {}}))
        data = {'id': 'test-patch', 'baseSha256': digest(db), 'reviewedUtc': '2026-09-28',
                'preconditions': [], 'operations': [{'sql': 'INSERT INTO players VALUES(2)', 'changes': 1}],
                'postconditions': [{'sql': 'SELECT COUNT(*) FROM players', 'rows': [[2]]}]}
        patch.write_text(json.dumps(data))
        return db, manifest, patch, data

    def test_repeat_is_noop(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            db, manifest, patch, _ = self.fixture(directory)
            apply(db, manifest, patch)
            before = (db.read_bytes(), manifest.read_bytes())
            apply(db, manifest, patch)
            self.assertEqual((db.read_bytes(), manifest.read_bytes()), before)

    def test_bad_base_and_failed_postcondition_preserve_inputs(self):
        for bad_base in (True, False):
            with tempfile.TemporaryDirectory() as directory:
                db, manifest, patch, data = self.fixture(directory)
                before = (db.read_bytes(), manifest.read_bytes())
                if bad_base:
                    data['baseSha256'] = 'wrong'
                else:
                    data['postconditions'][0]['rows'] = [[999]]
                patch.write_text(json.dumps(data))
                with self.assertRaises(ValueError):
                    apply(db, manifest, patch)
                self.assertEqual((db.read_bytes(), manifest.read_bytes()), before)


if __name__ == '__main__':
    unittest.main()
