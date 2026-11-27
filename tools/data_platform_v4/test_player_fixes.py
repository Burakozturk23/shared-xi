"""Every reported-player fix (patches/player-fixes-*.json, applied with
apply_reviewed_corrections.py) is in the database and in the manifest."""
import json
import sqlite3
import unittest

from apply_reviewed_corrections import ROOT

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'
FIXES = sorted((ROOT / 'tools/data_platform_v4/patches').glob('player-fixes-*.json'))


class PlayerFixesTests(unittest.TestCase):
    def test_every_fix_is_applied(self):
        applied = {r['id'] for r in json.loads(MANIFEST.read_text(encoding='utf-8')).get('reviewedAdditions', [])}
        self.assertTrue(FIXES)
        with sqlite3.connect(DB) as con:
            for path in FIXES:
                fix = json.loads(path.read_text(encoding='utf-8'))
                self.assertIn(fix['id'], applied, path.name)
                for player in fix['players']:
                    pid = player['playerId']
                    self.assertTrue(player['wiki']['revid'], player['name'])
                    for op in player['ops']:
                        self.assertIn(op['op'], ('addPlayerClub', 'addSpell'), 'fixes only add')
                        if op['op'] == 'addPlayerClub':
                            self.assertTrue(con.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?',
                                                        (pid, op['clubId'])).fetchone(), (player['name'], op))
                        else:
                            self.assertTrue(con.execute('''SELECT 1 FROM career_spells WHERE player_id=? AND club_id=?
                                AND start_date=?''', (pid, op['clubId'], op['start'])).fetchone(), (player['name'], op))

    def test_deniz_gul_has_his_career(self):
        with sqlite3.connect(DB) as con:
            clubs = {n for (n,) in con.execute('''SELECT c.name FROM player_clubs pc JOIN clubs c ON c.id=pc.club_id
                WHERE pc.player_id=3000350513''')}
        self.assertEqual(clubs, {'Hammarby IF', 'FC Porto', 'Galatasaray'})


if __name__ == '__main__':
    unittest.main()
