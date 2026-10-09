import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from build import Builder, date_value, score

class HistoricalImportTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.b=Builder(Path(self.tmp.name),'2026-10-09')
    def tearDown(self):
        for db in self.b.dbs.values():db.close()
        self.tmp.cleanup()
    def test_dates_and_score_phases(self):
        self.assertEqual(date_value('(Wed) 25 May 2005 (W21)'),'2005-05-25')
        self.assertEqual(date_value('Sat Aug 7 1993'),'1993-08-07')
        self.assertEqual(score('3-3 (a.e.t.)'),(3,3))
        self.assertEqual(score('?'),(None,None))
        with self.assertRaises(ValueError):score('cancelled')
        self.b.club_file('ucl','ucl/2004-05/cl.csv','Round,Date,Team 1,FT,HT,Team 2,ET,P\nFinal,2005-05-25,Liverpool FC › ENG (15),3-3,0-3,AC Milan › ITA (20),3-3 (a.e.t.),3-2 (pen.)\n')
        r=self.b.dbs['matches'].execute('SELECT home_score,away_score,ht_home,ht_away,et_home,et_away,pen_home,pen_away FROM matches').fetchone()
        self.assertEqual(r,(3,3,0,3,3,3,3,2))
    def test_conflict_and_provenance(self):
        params=('club','eng.1','2020-21','2021-01-01','Liverpool','Chelsea')
        first=self.b.add_match('england','a.csv',2,*params,2,1,'England',score_basis='source_ft',raw_record={'FT':'2-1'})
        second=self.b.add_match('wfb','b.csv',2,*params,3,1,'England',score_basis='source_ft',raw_record={'FT':'3-1'})
        self.assertEqual(first,second)
        db=self.b.dbs['matches']
        self.assertEqual(db.execute('SELECT conflict FROM matches').fetchone(),(1,))
        self.assertEqual(db.execute('SELECT count(*) FROM match_sources').fetchone(),(2,))
        self.assertEqual({json.loads(x[0])['FT'] for x in db.execute('SELECT raw_record FROM match_sources')},{'2-1','3-1'})
    def test_names_are_country_scoped(self):
        a=self.b.team('Liverpool','club','England')
        b=self.b.team('Liverpool','club','Uruguay')
        self.assertNotEqual(a,b)
        self.assertEqual(self.b.dbs['matches'].execute('SELECT canonical_club_id FROM teams WHERE id=?',(a,)).fetchone(),(31,))
        self.assertIsNone(self.b.dbs['matches'].execute('SELECT canonical_club_id FROM teams WHERE id=?',(b,)).fetchone()[0])
    def test_roster_semantics_and_ambiguous_columns(self):
        self.b.squad_file('cache/eng/2020-2021/national/team.txt', '''= Team - National League 2020/2021
Number, Name, Nat, Pos, Height, Weight, Date of Birth, Birth Place, Previous Club
1, Listed Player, ENG, G, 6'01", 80, 01-01-90, London, A
2, Ambiguous, ENG, M, , , , Town, Country, B
== Past Players
Number, Name, Nat, Pos, Height, Weight, Date of Birth, Birth Place, New Club
3, Past Player, ENG, D, , , 02-02-90, Leeds, C
''')
        db=self.b.dbs['squads']
        self.assertEqual(db.execute('SELECT kind FROM teams').fetchone(),('club',))
        self.assertEqual(db.execute('SELECT name,status,relation FROM squad_entries ORDER BY id').fetchall(),[('Listed Player','listed','Previous Club'),('Past Player','past','New Club')])
        self.assertEqual(self.b.rejected['squads:column_count'],1)
    def test_national_venue_does_not_change_identity_and_unknown_minute(self):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as z:
            z.writestr('results.csv','date,home_team,away_team,home_score,away_score,tournament,city,country,neutral\n2020-01-01,England,Germany,1,0,Friendly,Paris,France,TRUE\n')
            z.writestr('goalscorers.csv','date,home_team,away_team,team,scorer,minute,own_goal,penalty\n2020-01-01,England,Germany,England,Player,NA,FALSE,FALSE\n')
            z.writestr('shootouts.csv','date,home_team,away_team,winner,first_shooter\n')
            z.writestr('former_names.csv','current,former,start_date,end_date\n')
        with zipfile.ZipFile(stream) as z:self.b.international(z)
        db=self.b.dbs['matches']
        self.assertEqual(db.execute('SELECT count(*) FROM teams').fetchone(),(2,))
        self.assertEqual(db.execute('SELECT goals_complete,country FROM matches').fetchone(),(1,'France'))
        self.assertIsNone(db.execute('SELECT minute FROM goals').fetchone()[0])
    def test_future_and_self_match_rejected(self):
        with self.assertRaisesRegex(ValueError,'future_match'):
            self.b.add_match('england','x',1,'club','eng.1','2027','2027-01-01','A','B',1,0,score_basis='source_ft')
        with self.assertRaisesRegex(ValueError,'same_team'):
            self.b.add_match('england','x',1,'club','eng.1','2020','2020-01-01','A','A',1,0,score_basis='source_ft')

if __name__=='__main__':unittest.main()
