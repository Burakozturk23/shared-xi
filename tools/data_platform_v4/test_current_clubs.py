import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

from apply_current_clubs import ROOT, REVIEW, REVISION, SEASON, apply
from build_current_club_review import build

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'


class CurrentClubsTests(unittest.TestCase):
    def test_reviewed_moves_are_final_stops_and_season_transfers(self):
        review = json.loads(REVIEW.read_text(encoding='utf-8'))
        excluded = set(review['excludedPlayerIds'])
        # The 2026-11-12 Wikipedia review (test_wikipedia_moves.py) later removed or
        # redated some of these stops; those players are checked there.
        corrections = json.loads((ROOT / 'tools/data_platform_v4/patches/wikipedia-moves-2026-11-12.json')
                                 .read_text(encoding='utf-8'))
        excluded |= {p['playerId'] for p in corrections['players']
                     if any(op['op'] in ('removeSpell', 'updateSpell') and op['start'] == '2026-07-01' for op in p['ops'])}
        with sqlite3.connect(DB) as con:
            for r in review['players']:
                if r['playerId'] in excluded:
                    continue
                last = con.execute('''SELECT club_id,start_date,confidence FROM career_spells
                    WHERE player_id=? AND start_date=? AND club_id=?''', (r['playerId'], '2026-07-01', r['toClubId'])).fetchone()
                self.assertEqual(last, (r['toClubId'], '2026-07-01', SEASON), r['name'])
                moved = con.execute('SELECT 1 FROM transfers WHERE player_id=? AND from_club_id=? AND to_club_id=? '
                                    'AND transfer_date=? AND trust=?', (r['playerId'], r['fromClubId'], r['toClubId'],
                                                                        '2026-07-01', SEASON)).fetchone()
                self.assertEqual(bool(moved), r['transfer'], r['name'])
            # Dumfries: Inter -> Real Madrid; Tadić's club left is uncertain (Al-Wahda in between).
            names = {r['name']: r for r in review['players']}
            self.assertEqual((names['Denzel Dumfries']['fromClub'], names['Denzel Dumfries']['toClub']),
                             ('Inter Milan', 'Real Madrid'))
            self.assertFalse(names['Dušan Tadić']['transfer'])
            self.assertEqual({c['name'] for c in review['conflicts']}, {'Thilo Kehrer', 'Danilho Doekhi'})

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

    def test_review_file_is_reproducible_from_the_pre_patch_database(self):
        # The review was built from the database before it was applied: rebuilt
        # now, every applied player is already at his new club and drops out.
        data = build()
        self.assertEqual(data['counts']['players'], 0)


if __name__ == '__main__':
    unittest.main()
