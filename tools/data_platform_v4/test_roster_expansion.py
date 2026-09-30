import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from apply_roster_expansion import ROOT,apply,digest,load_review,ID_OFFSET,norm

class ExpansionTests(unittest.TestCase):
    def fixture(self, directory):
        root=Path(directory);db=root/'data.sqlite';manifest=root/'manifest.json';review=root/'review.json';part=root/'part.json'
        with sqlite3.connect(ROOT/'assets/runtime/linkball_game_data_v4.sqlite') as source,sqlite3.connect(db) as con:
            for (sql,) in source.execute("SELECT sql FROM sqlite_master WHERE type='table' AND sql IS NOT NULL AND name NOT LIKE 'sqlite_%'"):
                con.execute(sql)
            con.execute("INSERT INTO players(id,name,selection_rank,source) VALUES(1,'Existing Player',1,'v4')")
            con.execute("INSERT INTO clubs(id,canonical_key,name) VALUES(1,'test','Test FC')")
            con.execute("INSERT INTO player_clubs VALUES(1,1,2,'v4')")
            con.execute("INSERT INTO player_search_terms VALUES(1,'existing player','existingplayer','name',100)")
            con.execute("INSERT INTO metadata VALUES('player_count','1')")
        row={'sourcePlayerId':'10','playerId':None,'clubId':1,'club':'Test FC','name':'Çağrı Öztürk','names':['Çağrı Öztürk','Cagri Ozturk Full'],'birthYear':2000,'nationality':'Turkey','position':'M','status':'new_player'}
        part.write_text(json.dumps([row]));data={'id':'test-expansion','baseSha256':digest(db),'newPlayers':1,'newLinks':1,'reviewedUtc':'2026-09-29','parts':[{'file':part.name,'sha256':digest(part)}]};review.write_text(json.dumps(data))
        manifest.write_text(json.dumps({'database':{'sha256':digest(db)},'counts':{}}))
        return db,manifest,review

    def test_expansion_search_preservation_and_idempotency(self):
        with tempfile.TemporaryDirectory() as td:
            db,manifest,review=self.fixture(td);apply(db,manifest,review)
            with sqlite3.connect(db) as c:
                self.assertEqual(c.execute('SELECT name FROM players WHERE id=1').fetchone()[0],'Existing Player')
                self.assertEqual(c.execute('SELECT COUNT(*) FROM players').fetchone()[0],2)
                self.assertEqual(c.execute('SELECT player_id FROM player_search_terms WHERE compact_term=?',('cagriozturk',)).fetchone()[0],ID_OFFSET+10)
                self.assertEqual(c.execute('SELECT country FROM players WHERE id=?',(ID_OFFSET+10,)).fetchone()[0],'Türkiye')
                self.assertEqual(c.execute('SELECT COUNT(*) FROM career_spells').fetchone()[0],0)
                self.assertEqual(c.execute('SELECT COUNT(*) FROM transfers').fetchone()[0],0)
            before=(db.read_bytes(),manifest.read_bytes());apply(db,manifest,review)
            self.assertEqual((db.read_bytes(),manifest.read_bytes()),before)

    def test_wrong_base_or_evidence_is_atomic(self):
        for wrong_base in (True,False):
            with tempfile.TemporaryDirectory() as td:
                db,manifest,review=self.fixture(td);before=(db.read_bytes(),manifest.read_bytes());data=json.loads(review.read_text())
                if wrong_base:data['baseSha256']='wrong'
                else:data['newLinks']=5
                review.write_text(json.dumps(data))
                with self.assertRaises(ValueError):apply(db,manifest,review)
                self.assertEqual((db.read_bytes(),manifest.read_bytes()),before)

    def test_bundled_new_players_are_answerable_and_searchable(self):
        review=ROOT/'tools/data_platform_v4/patches/roster-expansion-2026-09-29.json'
        if not review.exists():self.skipTest('Review has not been generated yet')
        evidence=load_review(review);m=json.loads((ROOT/'assets/runtime/linkball_game_data_v4_manifest.json').read_text())
        with sqlite3.connect(ROOT/'assets/runtime/linkball_game_data_v4.sqlite') as c:
            self.assertEqual(c.execute('SELECT COUNT(*) FROM players').fetchone()[0],m['counts']['players'])
            self.assertEqual(c.execute("SELECT COUNT(*) FROM players WHERE source='worldcup26-roster'").fetchone()[0],evidence['newPlayers'])
            for r in evidence['rows']:
                if r['status']!='new_player':continue
                pid=ID_OFFSET+int(r['sourcePlayerId'])
                self.assertEqual(c.execute('SELECT answer_eligible FROM players WHERE id=?',(pid,)).fetchone(),(1,))
                self.assertTrue(c.execute('SELECT 1 FROM player_search_terms WHERE player_id=?',(pid,)).fetchone())
                self.assertTrue(c.execute('SELECT 1 FROM player_clubs WHERE player_id=? AND club_id=?',(pid,r['clubId'])).fetchone())
                self.assertFalse(c.execute('SELECT 1 FROM career_spells WHERE player_id=?',(pid,)).fetchone())
                self.assertFalse(c.execute('SELECT 1 FROM transfers WHERE player_id=?',(pid,)).fetchone())
                # Same predicate as the V4 per-club answer and player-search queries.
                self.assertTrue(c.execute("SELECT 1 FROM players p WHERE p.id=? AND (p.selection_rank BETWEEN 1 AND 30000 OR (p.source='worldcup26-roster' AND p.answer_eligible=1))",(pid,)).fetchone())

if __name__=='__main__':unittest.main()
