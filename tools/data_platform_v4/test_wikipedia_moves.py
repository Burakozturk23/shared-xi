import json
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path

from apply_reviewed_corrections import DB, MANIFEST, apply
from build_wikipedia_moves import OUT, REVISION


def career(con, pid):
    return con.execute('SELECT club_id,start_date,end_date,confidence FROM career_spells WHERE player_id=? '
                       'ORDER BY start_date, sequence', (pid,)).fetchall()


def moved(con, pid, frm, to):
    return bool(con.execute('SELECT 1 FROM transfers WHERE player_id=? AND from_club_id=? AND to_club_id=? '
                            'AND transfer_date=?', (pid, frm, to, '2026-07-01')).fetchone())


class WikipediaMovesTests(unittest.TestCase):
    def test_reviewed_corrections_are_in_the_database(self):
        with sqlite3.connect(DB) as con:
            # Kehrer: Monaco -> Ajax on loan; Doekhi: Union Berlin -> Lazio.
            self.assertEqual(career(con, 228948)[-1][:2], (610, '2026-07-01'))
            self.assertTrue(moved(con, 228948, 1000000162, 610))
            self.assertTrue(moved(con, 387047, 89, 398))
            # Morata: no loan return to Milan; Como -> Leganés.
            self.assertEqual([s[0] for s in career(con, 128223)[-2:]], [1047, 1244])
            self.assertFalse(con.execute("SELECT 1 FROM transfers WHERE event_id='tm:128223:2026-06-30:1047:5'").fetchone())
            # Another player's roster row: Murillo is at Al-Shamal, not Riestra.
            self.assertEqual(career(con, 131102)[-1], (10775, '2023-07-01', None, 'REVIEWED_YEAR'))
            self.assertFalse(con.execute('SELECT 1 FROM player_clubs WHERE player_id=131102 AND club_id=19775').fetchone())
            # A second row of the same club is not a move.
            self.assertFalse(con.execute('SELECT 1 FROM career_spells WHERE player_id=157396 AND club_id=6571').fetchone())
            # Ziyech: Al-Duhail, Wydad, then Botafogo, in order.
            self.assertEqual([s[0] for s in career(con, 217111)[-3:]], [26091, 1000006603, 9030])
            # Talisca, Darwin Núñez (Al-Diriyah, a new club), Tadić's Al Wahda before NEC.
            self.assertTrue(moved(con, 258626, 36, 1000002524))
            self.assertTrue(moved(con, 546543, 1114, 5000000024))
            self.assertEqual(con.execute('SELECT name,country FROM clubs WHERE id=5000000024').fetchone(),
                             ('Al-Diriyah', 'Saudi Arabia'))
            self.assertTrue(moved(con, 36139, 1000000161, 467))
            # Fekir's Al Jazira link is no longer Universitatea Craiova (the id 2524 collision).
            self.assertFalse(con.execute('SELECT 1 FROM player_clubs WHERE player_id=203496 AND club_id=2524').fetchone())

    def test_reviewed_stops_do_not_overlap_the_stop_before(self):
        review = json.loads(OUT.read_text(encoding='utf-8'))
        with sqlite3.connect(DB) as con:
            for p in review['players']:
                for op in p['ops']:
                    if op['op'] != 'addSpell' or op['confidence'] != 'REVIEWED_YEAR':
                        continue
                    # Against the stops that were there; loans inside an added owner spell (Diallo at
                    # Al-Arabi, on loan at Al-Duhail) overlap it by nature.
                    before = con.execute('SELECT MAX(end_date) FROM career_spells WHERE player_id=? AND start_date<? '
                                         "AND end_date!='' AND confidence!='REVIEWED_YEAR'",
                                         (p['playerId'], op['start'])).fetchone()[0]
                    self.assertLessEqual(before or '', op['start'], p['name'])

    def test_every_added_club_is_named_in_the_infobox(self):
        review = json.loads(OUT.read_text(encoding='utf-8'))
        wiki = {p['playerId']: p for p in json.loads(
            (OUT.parent / 'wikipedia-careers-2026-11-12.json').read_text(encoding='utf-8'))['players']}
        with sqlite3.connect(DB) as con:
            names = dict(con.execute('SELECT id,name FROM clubs'))
        from build_current_club_review import same_club
        for p in review['players']:
            for op in p['ops']:
                if op['op'] == 'addSpell':
                    rows = wiki[p['playerId']]['senior']
                    self.assertTrue(any(same_club(names[op['clubId']], r['label']) or
                                        same_club(names[op['clubId']], r['title'] or '') for r in rows),
                                    (p['name'], names[op['clubId']]))

    def test_idempotency_and_evidence_guard(self):
        with tempfile.TemporaryDirectory() as td:
            db, manifest, evidence = [Path(td) / name for name in ('data.sqlite', 'manifest.json', 'review.json')]
            for source, dest in [(DB, db), (MANIFEST, manifest), (OUT, evidence)]:
                shutil.copy2(source, dest)
            before = (db.read_bytes(), manifest.read_bytes())
            self.assertEqual(apply(evidence, db, manifest)['id'], REVISION)
            self.assertEqual(before, (db.read_bytes(), manifest.read_bytes()))
            evidence.write_text(evidence.read_text(encoding='utf-8').replace('Monaco', 'Monako'), encoding='utf-8')
            with self.assertRaises(ValueError):
                apply(evidence, db, manifest)


if __name__ == '__main__':
    unittest.main()
