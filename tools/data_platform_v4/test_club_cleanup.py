import sqlite3
import unittest

from apply_club_cleanup import ROOT, DUPLICATES, SUCCESSORS, RESERVES, COUNTRIES

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'


class ClubCleanupTests(unittest.TestCase):
    def test_merged_rows_are_empty_and_out_of_the_pools(self):
        with sqlite3.connect(DB) as con:
            for (old, name), (kept, _) in DUPLICATES + SUCCESSORS:
                self.assertEqual(con.execute('SELECT COUNT(*) FROM player_clubs WHERE club_id=?', (old,)).fetchone()[0], 0, name)
                self.assertEqual(con.execute('SELECT COUNT(*) FROM career_spells WHERE club_id=?', (old,)).fetchone()[0], 0, name)
                self.assertEqual(con.execute('SELECT gameplay_eligible FROM clubs WHERE id=?', (old,)).fetchone()[0], 0, name)
                self.assertGreater(con.execute('SELECT COUNT(*) FROM player_clubs WHERE club_id=?', (kept,)).fetchone()[0], 0)

    def test_reserves_and_countries(self):
        with sqlite3.connect(DB) as con:
            for cid, name in RESERVES:
                self.assertEqual(con.execute('SELECT entity_type FROM clubs WHERE id=?', (cid,)).fetchone()[0], 'RESERVE', name)
            for (cid, _), country in COUNTRIES:
                self.assertEqual(con.execute('SELECT country FROM clubs WHERE id=?', (cid,)).fetchone()[0], country)

    def test_reported_clubs_are_listed_once(self):
        # The Ortak Oyuncu Keşfi list: a senior club with a player link.
        query = '''SELECT COUNT(*) FROM clubs c WHERE c.name LIKE ? AND c.entity_type='SENIOR'
                   AND EXISTS (SELECT 1 FROM player_clubs pc WHERE pc.club_id=c.id)'''
        with sqlite3.connect(DB) as con:
            for name in ['%Napoli', 'Adana Demirspor', 'Albacete%', 'Inter Miami%', '%Lokeren%', '%Brescia%']:
                self.assertEqual(con.execute(query, (name,)).fetchone()[0], 1, name)
            # Baggio's Brescia career is now Union Brescia's.
            self.assertTrue(con.execute('''SELECT 1 FROM player_clubs pc JOIN players p ON p.id=pc.player_id
                WHERE p.name='Roberto Baggio' AND pc.club_id=132806''').fetchone())


if __name__ == '__main__':
    unittest.main()
