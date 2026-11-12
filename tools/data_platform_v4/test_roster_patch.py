import json
import sqlite3
import unittest
from build_roster_patch import load_snapshot
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SNAPSHOT=ROOT/'tools/data_platform_v4/patches/rosters-2026-09-29.json'
PATCH=ROOT/'tools/data_platform_v4/patches/v4-2026-09-29.1.json'

class RosterPatchTests(unittest.TestCase):
    def test_patch_only_adds_links_and_updates_revision(self):
        patch=json.loads(PATCH.read_text())
        for op in patch['operations']:
            self.assertIn(op['sql'],[
                'INSERT INTO player_clubs(player_id,club_id,trust,source) VALUES(?,?,?,?)',
                "INSERT OR REPLACE INTO metadata(key,value) VALUES('data_revision',?)",
                "UPDATE metadata SET value=? WHERE key='player_club_rows'"])
        self.assertEqual(len(patch['operations'])-2,len({tuple(op['args'][:2]) for op in patch['operations'][:-2]}))

    def test_all_accepted_links_exist_with_identity_evidence(self):
        evidence=load_snapshot(SNAPSHOT)
        with sqlite3.connect(ROOT/'assets/runtime/linkball_game_data_v4.sqlite') as c:
            # Links the 2026-11-12 Wikipedia review showed to be another player with the same name.
            removed={(x['playerId'],op['clubId']) for x in json.loads((ROOT/'tools/data_platform_v4/patches/wikipedia-moves-2026-11-12.json').read_text(encoding='utf-8'))['players'] for op in x['ops'] if op['op']=='removePlayerClub'}
            additions=[r for r in evidence['rows'] if r['status']=='add' and (r['playerId'],r['clubId']) not in removed]
            self.assertGreater(len(additions),0)
            for r in additions:
                self.assertEqual(c.execute('SELECT p.name,pr.birth_year FROM players p JOIN profiles pr ON pr.player_id=p.id WHERE p.id=?',(r['playerId'],)).fetchone(),(r['canonicalName'],r['birthYear']))
                self.assertEqual(c.execute('SELECT trust,source FROM player_clubs WHERE player_id=? AND club_id=?',(r['playerId'],r['clubId'])).fetchone(),(2,'roster:worldcup26:2026-09-29'))
            # Only existing identities: no new entities or fabricated career events.
            self.assertEqual(c.execute("SELECT COUNT(*) FROM players WHERE source = 'v4'").fetchone()[0],30135)
            self.assertEqual(c.execute('SELECT COUNT(*) FROM clubs').fetchone()[0],4311 + sum(r.get('newClubs', 0) for r in json.loads((ROOT/'assets/runtime/linkball_game_data_v4_manifest.json').read_text()).get('reviewedAdditions', [])))
            self.assertEqual(c.execute("SELECT COUNT(*) FROM transfers WHERE trust!='REVIEWED_SEASON'").fetchone()[0],33992)  # 2 loan returns removed in v4-2026-11-12.1
            self.assertEqual(c.execute('SELECT COUNT(*) FROM career_spells').fetchone()[0],37966 + sum(r.get('newCareerSpells', 0) for r in json.loads((ROOT/'assets/runtime/linkball_game_data_v4_manifest.json').read_text()).get('reviewedAdditions', [])))
            self.assertEqual(
                c.execute(
                    "SELECT COUNT(*) FROM player_clubs WHERE source NOT IN ("
                    "'roster:worldcup26:2026-09-29.2',"
                    "'reviewed:notable:2026-09-30',"
                    "'reviewed:legend-portraits:2026-10-01',"
                    "'reviewed:season-portraits:2026-10-01',"
                    "'reviewed:portrait-audit:2026-10-04',"
                    "'reviewed:avatar-careers:2026-10-05',"
                    "'reviewed:summer-2026:2026-11-12'"
                    ")"
                ).fetchone()[0],
                165563 + len(additions)
                # Placeholder clubs (Transfermarkt "without club") removed later.
                - sum(c['removedLinks'] for c in json.loads(
                    (ROOT/'assets/runtime/linkball_game_data_v4_manifest.json').read_text()).get('corrections', []))
                # Base links a reviewed correction removed (Fekir's Al Jazira stored as Craiova).
                - sum(r.get('removedBaseLinks', 0) for r in json.loads(
                    (ROOT/'assets/runtime/linkball_game_data_v4_manifest.json').read_text()).get('reviewedAdditions', [])),
            )
            for r in evidence['rows']:
                if r['status'] in ('review','conflicting_rosters') and r.get('playerId'):
                    self.assertFalse(c.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=? AND source=?',(r['playerId'],r['clubId'],'roster:worldcup26:2026-09-29')).fetchone())

if __name__=='__main__':unittest.main()
