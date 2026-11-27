import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

from apply_famous_players import ROOT, REVIEW, REVISION, LINK_SOURCE, apply as apply_players
from apply_pageview_ranks import REVISION as RANKS
from apply_club_twins import REVISION as TWINS

DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
MANIFEST = ROOT / 'assets/runtime/linkball_game_data_v4_manifest.json'


def shared(con, a, b):
    return {n for (n,) in con.execute('''SELECT p.name FROM players p
        JOIN player_clubs x ON x.player_id=p.id AND x.club_id=? JOIN player_clubs y ON y.player_id=p.id AND y.club_id=?''', (a, b))}


class FamousPlayersTests(unittest.TestCase):
    def test_players_have_identity_links_and_careers(self):
        review = json.loads(REVIEW.read_text(encoding='utf-8'))
        self.assertGreater(len(review['players']), 3000)
        with sqlite3.connect(DB) as con:
            for p in review['players']:
                self.assertEqual(con.execute('SELECT name,country,source,answer_eligible FROM players WHERE id=?',
                                             (p['id'],)).fetchone(), (p['name'], p['countries'][0], 'reviewed-player', 1))
                self.assertEqual({c for (c,) in con.execute('SELECT country FROM player_countries WHERE player_id=?', (p['id'],))},
                                 set(p['countries']))
                self.assertTrue(con.execute('SELECT 1 FROM player_search_terms WHERE player_id=?', (p['id'],)).fetchone())
                self.assertTrue(con.execute('SELECT 1 FROM player_clubs WHERE player_id=?', (p['id'],)).fetchone())

    def test_reported_rivalries_find_their_players(self):
        with sqlite3.connect(DB) as con:
            self.assertTrue({'Michael Owen', 'Peter Beardsley', 'Phil Chisnall', 'Paul Ince'} <= shared(con, 985, 31))
            self.assertTrue({'Peter Beardsley', 'Nick Barmby', 'Abel Xavier'} <= shared(con, 29, 31))
            self.assertTrue({'Sol Campbell', 'William Gallas', 'Pat Jennings', 'David Bentley'} <= shared(con, 148, 11))

    def test_no_reserve_side_or_lookalike_club_links(self):
        review = json.loads(REVIEW.read_text(encoding='utf-8'))
        by_name = {p['name']: {c['name'] for c in p['clubs']} for p in review['players']}
        ids = {p['name']: {c['id'] for c in p['clubs']} for p in review['players']}
        # Arsenal de Sarandí (4673) is not the London Arsenal (11).
        self.assertIn(4673, ids['Jorge Burruchaga'])
        self.assertNotIn(11, ids['Jorge Burruchaga'])
        self.assertEqual(by_name['Jamie Carragher'], {'Liverpool FC'})
        # Reserve sides never become first-team links: Owen's career has no Liverpool reserves row.
        self.assertEqual(by_name['Michael Owen'],
                         {'Liverpool FC', 'Real Madrid', 'Newcastle United', 'Manchester United', 'Stoke City'})
        # Japan's players are kept only with a big European league club.
        japan = [p for p in review['players'] if p['countries'][0] == 'Japan']
        self.assertLess(len(japan), 60)

    def test_ranks_place_legends_and_merge_twins(self):
        with sqlite3.connect(DB) as con:
            rank = dict(con.execute('SELECT name,selection_rank FROM players WHERE source=? AND name IN (?,?,?)',
                                    ('reviewed-player', 'Paolo Maldini', 'Burak Yılmaz', 'Michael Owen')))
            self.assertTrue(all(r <= 3000 for r in rank.values()), rank)
            # V4's own ranks are never renumbered (fixed tiers keep their meaning).
            self.assertEqual(con.execute("SELECT name FROM players WHERE source='v4' AND selection_rank=3").fetchone()[0],
                             'Lionel Messi')
            # Napoli's split rows: Osimhen now on the primary SSC Napoli row, the twin left empty.
            self.assertIn((6195,), con.execute('''SELECT club_id FROM player_clubs pc JOIN players p ON p.id=pc.player_id
                WHERE p.name='Victor Osimhen' ''').fetchall())
            self.assertEqual(con.execute('SELECT COUNT(*) FROM player_clubs WHERE club_id=15795').fetchone()[0], 0)
            self.assertEqual(con.execute('SELECT name FROM clubs WHERE id=4673').fetchone()[0], 'Arsenal de Sarandí')
        manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        ids = [r['id'] for r in manifest['reviewedAdditions']]
        at = ids.index(REVISION)
        self.assertEqual(ids[at:at + 3], [REVISION, RANKS, TWINS])

    def test_idempotency_and_evidence_guard(self):
        with tempfile.TemporaryDirectory() as td:
            db, manifest, evidence = [Path(td) / name for name in ('data.sqlite', 'manifest.json', 'review.json')]
            for source, dest in [(DB, db), (MANIFEST, manifest), (REVIEW, evidence)]:
                shutil.copy2(source, dest)
            # The manifest now points past this revision: re-applying it is a recorded no-op only on
            # its own output, so check against a manifest whose current hash is the database.
            self.assertEqual(json.loads(manifest.read_text())['database']['sha256'],
                             __import__('apply_roster_expansion').digest(db))
            evidence.write_text('{}')
            with self.assertRaises(ValueError):
                apply_players(db, manifest, evidence)


if __name__ == '__main__':
    unittest.main()
