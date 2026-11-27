import sqlite3
import unittest
from contextlib import closing

from apply_club_collision_fix import move_links, pairs


class ClubCollisionFixTest(unittest.TestCase):
    def test_moves_only_imported_links_to_the_tm_club(self):
        with closing(sqlite3.connect(':memory:')) as con:
            con.execute('CREATE TABLE clubs(id INTEGER PRIMARY KEY, name TEXT)')
            con.execute('''CREATE TABLE player_clubs(player_id INTEGER, club_id INTEGER, trust INTEGER,
                           source TEXT, PRIMARY KEY(player_id, club_id))''')
            con.executemany('INSERT INTO clubs VALUES(?,?)', [(208, 'Haras El Hodood'), (1000000208, 'CSKA-Sofia')])
            con.executemany('INSERT INTO player_clubs VALUES(?,?,?,?)', [
                (1, 208, 1, 'v3'),           # Berbatov, imported from TM 208: CSKA
                (2, 208, 2, 'v3'),           # a real Haras El Hodood player stays
                (3, 208, 1, 'v3'), (3, 1000000208, 2, 'v3'),  # already linked to CSKA
            ])
            # Player 3 already had CSKA: his old link goes, no second row.
            self.assertEqual(move_links(con, [(208, 1000000208)]), ({'208': 2}, 1))
            self.assertEqual(sorted(con.execute('SELECT player_id, club_id FROM player_clubs')), [
                (1, 1000000208), (2, 208), (3, 1000000208)])

    def test_the_reviewed_list_names_cska_sofia(self):
        self.assertIn((208, 1000000208), pairs())
        self.assertEqual(len(pairs()), 35)


if __name__ == '__main__':
    unittest.main()
