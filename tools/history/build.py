"""Build deterministic, source-attributed historical sidecars from the user's ZIPs.

No downloads, fuzzy identity joins, current-roster mutation, or StatsBomb raw data.
The archives are read in-place (never extract executable files or trust ZIP paths).
"""
from __future__ import annotations
import argparse
import collections
import csv
import datetime as dt
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import sqlite3
import tempfile
import unicodedata
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = 1
COUNTRIES = dict(eng='England', de='Germany', ger='Germany', es='Spain', spain='Spain',
 fr='France', france='France', it='Italy', italy='Italy', nl='Netherlands', holland='Netherlands',
 netherl='Netherlands', tr='Türkiye', turkey='Türkiye', sco='Scotland', scots='Scotland',
 pt='Portugal', portugal='Portugal', be='Belgium', belgium='Belgium', gr='Greece', greece='Greece',
 at='Austria', austria='Austria', ch='Switzerland', switz='Switzerland', br='Brazil', brazil='Brazil',
 ar='Argentina', arg='Argentina', ru='Russia', russia='Russia', us='USA', usa='USA')
COUNTRIES.update({'GER':'Germany','ENG':'England','ITA':'Italy','ESP':'Spain','NED':'Netherlands',
 'FRA':'France','POR':'Portugal','GRE':'Greece','TUR':'Türkiye','SCO':'Scotland','SUI':'Switzerland'})
ALIASES = {31:['Liverpool'],281:['Manchester City FC','Man City'],985:['Manchester United FC','Man United'],
 5:['Milan','Milan AC'],46:['Internazionale','Internazionale Milano','Inter'],610:['Ajax','AFC Ajax'],
 27:['Bayern München','Bayern Munich','FC Bayern München'],131:['Barcelona'],631:['Chelsea'],
 11:['Arsenal'],506:['Juventus'],418:['Real Madrid CF'],148:['Tottenham'],16:['Dortmund'],
 18:["M\u0027Gladbach",'Mönchengladbach'],141:['Galatasaray SK'],36:['Fenerbahçe','Fenerbahce SK'],
 265:['Panathinaikos']}
SOURCES = {
 'international':('International football results','https://github.com/martj42/international_results',
 'CC0-1.0','Men’s international results. Scores include extra time where played; exclude shootouts. Goal coverage is partial.'),
 'footballdata':('Football-Data CSV cache','https://github.com/footballcsv/cache.footballdata',
 'CC0-1.0','Snapshot supplied by user; upstream football-data.co.uk. Preserve provenance and review source errors.'),
 'wfb':('WorldFootball CSV cache','https://github.com/footballcsv/cache.wfb',
 'CC0-1.0','Snapshot supplied by user; upstream worldfootball.net. Historical results, not live fixtures.'),
 'germany':('football.csv Germany','https://github.com/footballcsv/deutschland','CC0-1.0','User-supplied historical snapshot.'),
 'england':('football.csv England','https://github.com/footballcsv/england','CC0-1.0','User-supplied historical snapshot.'),
 'spain':('football.csv Spain','https://github.com/footballcsv/espana','CC0-1.0','User-supplied historical snapshot.'),
 'ucl':('football.csv European Cup','https://github.com/footballcsv/europe-champions-league','CC0-1.0',
 'European Cup / Champions League. FT, extra time and shootout scores are kept separately.'),
 'squads':('Football Squads CSV cache','https://github.com/footballcsv/cache.footballsquads','CC0-1.0',
 'Season/tournament squad snapshots, not match lineups. Past players and current/previous/new club fields remain distinct.')}
ARCHIVES = {'archive.zip':'international','cache.footballdata-master.zip':'footballdata',
 'cache.wfb-master.zip':'wfb','deutschland-master.zip':'germany','england-master.zip':'england',
 'espana-master.zip':'spain','europe-champions-league-master.zip':'ucl','cache.footballsquads-master.zip':'squads'}

def norm(s):
    return ' '.join(re.sub(r'[^a-z0-9]+',' ',unicodedata.normalize('NFKD',s.casefold().replace('ı','i')).encode('ascii','ignore').decode()).split())

def ident(*parts):
    return hashlib.sha256('\x1f'.join(map(str,parts)).encode()).hexdigest()[:24]

def date_value(s):
    s=s.strip()
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}',s):
        return dt.date.fromisoformat(s).isoformat()
    m=re.search(r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})',s)
    if m: return dt.datetime.strptime(' '.join(m.groups()),'%d %b %Y').date().isoformat()
    m=re.search(r'([A-Za-z]{3})\s+(\d{1,2})\s+(\d{4})',s)
    if m: return dt.datetime.strptime(' '.join(m.groups()),'%b %d %Y').date().isoformat()
    raise ValueError('unknown_date')

def score(s):
    if not s or s.strip() in ('?','-','—'):return (None,None)
    m=re.fullmatch(r'\s*(\d{1,2})\s*[-–:]\s*(\d{1,2})(?:\s*\([^)]*\))*\s*',s)
    if not m:raise ValueError('invalid_score')
    return tuple(map(int,m.groups()))

def boolean(s):
    if s.upper() not in ('TRUE','FALSE'):raise ValueError('invalid_boolean')
    return int(s.upper()=='TRUE')

COMMON = '''
PRAGMA user_version=1;
PRAGMA foreign_keys=ON;
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE sources(id TEXT PRIMARY KEY,name TEXT NOT NULL,url TEXT NOT NULL,license TEXT NOT NULL,note TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE teams(id INTEGER PRIMARY KEY,name TEXT NOT NULL,kind TEXT NOT NULL,country TEXT NOT NULL,canonical_club_id INTEGER,search TEXT NOT NULL);
'''
MATCH_SCHEMA = '''
CREATE TABLE matches(id INTEGER PRIMARY KEY,kind TEXT NOT NULL,competition TEXT NOT NULL,season TEXT NOT NULL,date TEXT NOT NULL,
 home_id INTEGER NOT NULL REFERENCES teams(id),away_id INTEGER NOT NULL REFERENCES teams(id),
 home_score INTEGER NOT NULL,away_score INTEGER NOT NULL,ht_home INTEGER,ht_away INTEGER,et_home INTEGER,et_away INTEGER,
 pen_home INTEGER,pen_away INTEGER,shootout_winner_id INTEGER REFERENCES teams(id),first_shooter_id INTEGER REFERENCES teams(id),neutral INTEGER,city TEXT,country TEXT,
 round TEXT,score_basis TEXT NOT NULL,conflict INTEGER NOT NULL DEFAULT 0,goals_complete INTEGER NOT NULL DEFAULT 0,
 CHECK(home_id<>away_id),CHECK(home_score>=0 AND away_score>=0));
CREATE TABLE match_sources(match_id INTEGER NOT NULL REFERENCES matches(id),source_id TEXT NOT NULL REFERENCES sources(id),
 path TEXT NOT NULL,row_number INTEGER NOT NULL,home_label TEXT NOT NULL,away_label TEXT NOT NULL,raw_record TEXT NOT NULL,
 PRIMARY KEY(match_id,source_id,path,row_number)) WITHOUT ROWID;
CREATE TABLE goals(id INTEGER PRIMARY KEY,match_id INTEGER NOT NULL REFERENCES matches(id),team_id INTEGER NOT NULL REFERENCES teams(id),
 scorer TEXT NOT NULL,minute TEXT,own_goal INTEGER NOT NULL,penalty INTEGER NOT NULL,source_row INTEGER NOT NULL);
CREATE TABLE former_names(current TEXT,former TEXT,start_date TEXT,end_date TEXT,PRIMARY KEY(current,former,start_date)) WITHOUT ROWID;
CREATE TABLE selections(id INTEGER PRIMARY KEY,category TEXT NOT NULL,title TEXT NOT NULL,date TEXT NOT NULL,
 home TEXT NOT NULL,away TEXT NOT NULL,match_id INTEGER REFERENCES matches(id),status TEXT NOT NULL);
'''
SQUAD_SCHEMA = '''
CREATE TABLE rosters(id INTEGER PRIMARY KEY,team_id INTEGER NOT NULL REFERENCES teams(id),context TEXT NOT NULL,season TEXT NOT NULL,
 source_id TEXT NOT NULL REFERENCES sources(id),path TEXT NOT NULL,search TEXT NOT NULL);
CREATE TABLE squad_entries(id INTEGER PRIMARY KEY,roster_id INTEGER NOT NULL REFERENCES rosters(id),name TEXT NOT NULL,
 nationality TEXT,position TEXT,shirt TEXT,birth_date_text TEXT,height TEXT,weight TEXT,birth_place TEXT,status TEXT NOT NULL,related_club TEXT,relation TEXT,source_row INTEGER NOT NULL);
'''

class Builder:
    def __init__(self, directory:Path, cutoff:str):
        self.directory=directory
        self.cutoff=date_value(cutoff)
        self.report={'schema_version':VERSION,'cutoff':cutoff,'inputs':{},'counts':{},'rejected':{},'examples':{},'warnings':{}}
        self.counts=collections.Counter();self.rejected=collections.Counter();self.examples={}
        self.teams={"matches":{},"squads":{}}; self.canonical={}; self.exact=collections.defaultdict(set)
        con=sqlite3.connect(f'file:{ROOT}/assets/runtime/linkball_game_data_v4.sqlite?mode=ro',uri=True)
        for cid,name,country in con.execute('SELECT id,name,country FROM clubs WHERE entity_type="SENIOR"'):
            country={'Turkey':'Türkiye','United States':'USA'}.get(country,country or '')
            self.canonical[cid]=(name,country)
            self.exact[(norm(name),country)].add(cid)
        con.close()
        for cid,labels in ALIASES.items():
            assert cid in self.canonical, cid
            for label in labels:self.exact[(norm(label),self.canonical[cid][1])].add(cid)
        self.dbs={}
        for kind,schema in [('matches',MATCH_SCHEMA),('squads',SQUAD_SCHEMA)]:
            db=sqlite3.connect(directory/f'{kind}.sqlite');db.executescript(COMMON+schema)
            db.executemany('INSERT INTO sources VALUES(?,?,?,?,?)',[(k,*v) for k,v in SOURCES.items()])
            db.execute('INSERT INTO metadata VALUES(?,?)',('schema_version',str(VERSION)))
            db.execute('INSERT INTO metadata VALUES(?,?)',('cutoff',self.cutoff));self.dbs[kind]=db
        self.match_keys={};self.match_ids={};self.next_roster=0

    def reject(self,source,reason,path,row):
        k=source+':'+reason;self.rejected[k]+=1
        examples=self.examples.setdefault(k,[])
        if len(examples)<8:examples.append({'path':path,'row':row})

    def team(self,label,kind,country='',dbkind='matches'):
        label=label.strip()
        # Competition participation counts and country markers are not team names.
        if '›' in label:
            label,tag=label.split('›',1);label=label.strip(); country=COUNTRIES.get(tag.strip().split()[0],tag.strip().split()[0])
        if not label or label in ('?','-'):raise ValueError('missing_team')
        country={'Turkey':'Türkiye','United States':'USA'}.get(country,country)
        cid=None
        if kind=='club':
            ids=self.exact.get((norm(label),country),set())
            if len(ids)==1:cid=next(iter(ids))
        key=f'club:tm:{cid}' if cid is not None else kind+':'+ident(country,norm(label))
        key=self.teams[dbkind].setdefault(key,len(self.teams[dbkind])+1)
        name=self.canonical[cid][0] if cid is not None else label
        search=norm(name+' '+label)
        db=self.dbs[dbkind]
        db.execute('INSERT OR IGNORE INTO teams VALUES(?,?,?,?,?,?)',(key,name,kind,country,cid,search))
        return key

    def add_match(self,source,path,row,kind,comp,season,date,home,away,hs,aws,team_country='',**extra):
        date=date_value(date)
        if date>self.cutoff:raise ValueError('future_match')
        hi=self.team(home,kind,team_country);ai=self.team(away,kind,team_country)
        if hi==ai:raise ValueError('same_team')
        if hs is None or aws is None:raise ValueError('unplayed_match')
        natural_key=(kind,comp,date,hi,ai)
        key=self.match_ids.setdefault(natural_key,len(self.match_ids)+1)
        raw_record=extra.pop('raw_record',{})
        db=self.dbs['matches'];old=db.execute('SELECT home_score,away_score FROM matches WHERE id=?',(key,)).fetchone()
        if old:
            self.counts['merged_duplicate_records']+=1
            if old!=(hs,aws):
                db.execute('UPDATE matches SET conflict=1 WHERE id=?',(key,));self.counts['conflicting_records']+=1
            # Prefer the first snapshot but fill independently sourced nullable detail.
            for col in ('ht_home','ht_away','et_home','et_away','pen_home','pen_away'):
                if extra.get(col) is not None:
                    db.execute(f'UPDATE matches SET {col}=COALESCE({col},?) WHERE id=?',(extra[col],key))
        else:
            cols=['id','kind','competition','season','date','home_id','away_id','home_score','away_score',*extra.keys()]
            db.execute(f'INSERT INTO matches({",".join(cols)}) VALUES({",".join("?" for _ in cols)})',
                       [key,kind,comp,season,date,hi,ai,hs,aws,*extra.values()])
        db.execute('INSERT INTO match_sources VALUES(?,?,?,?,?,?,?)',(key,source,path,row,home,away,json.dumps(raw_record,ensure_ascii=False,separators=(',',':'))))
        self.counts[source+'_accepted']+=1
        return key

    def club_file(self,source,path,text):
        p=PurePosixPath(path);comp='uefa.champions' if source=='ucl' or p.stem=='uefa.cl' else p.stem
        season=next((x for x in p.parts if re.fullmatch(r'\d{4}-\d{2,4}',x)),p.parent.name)
        country=COUNTRIES.get(comp.split('.')[0],comp.split('.')[0]) if not comp.startswith('uefa.') else ''
        for line,row in enumerate(csv.DictReader(io.StringIO(text)),2):
            self.counts[source+'_rows']+=1
            try:
                if None in row:raise ValueError('column_count')
                h,a=score(row['FT']);hh,ha=score(row.get('HT',''));eh,ea=score(row.get('ET',''));ph,pa=score(row.get('P',''))
                self.add_match(source,path,line,'club',comp,season,row['Date'],row['Team 1'],row['Team 2'],h,a,country,
                 raw_record=row,ht_home=hh,ht_away=ha,et_home=eh,et_away=ea,pen_home=ph,pen_away=pa,
                 round=' · '.join(x for x in (row.get('Stage'),row.get('Round') or row.get('Matchday')) if x),
                 score_basis='90_minutes' if eh is not None else 'source_ft')
            except (ValueError,KeyError,TypeError) as e:self.reject(source,str(e),path,line)

    def international(self,z):
        db=self.dbs['matches']
        for line,r in enumerate(csv.DictReader(io.StringIO(z.read('results.csv').decode('utf-8-sig'))),2):
            self.counts['international_rows']+=1
            try:
                key=self.add_match('international','results.csv',line,'international',r['tournament'],r['date'][:4],r['date'],r['home_team'],r['away_team'],
                  int(r['home_score']),int(r['away_score']),raw_record=r,neutral=boolean(r['neutral']),city=r['city'],country=r['country'],score_basis='including_extra_time')
                mk=(r['date'],r['home_team'],r['away_team']);self.match_keys.setdefault(mk,[]).append(key)
            except (ValueError,KeyError,TypeError) as e:self.reject('international',str(e),'results.csv',line)
        for path in ('goalscorers.csv','shootouts.csv'):
            for line,r in enumerate(csv.DictReader(io.StringIO(z.read(path).decode('utf-8-sig'))),2):
                self.counts[path+'_rows']+=1
                try:
                    keys=set(self.match_keys.get((r['date'],r['home_team'],r['away_team']),[]))
                    if len(keys)!=1:raise ValueError('unresolved_match')
                    key=next(iter(keys))
                    if path=='goalscorers.csv':
                        if r['team'] not in (r['home_team'],r['away_team']):raise ValueError('non_participant')
                        if not r['scorer'].strip():raise ValueError('missing_scorer')
                        minute=r['minute'].strip()
                        if minute=='NA':minute=''
                        if minute and not re.fullmatch(r'\d{1,3}(?:\+\d{1,2})?',minute):raise ValueError('invalid_minute')
                        db.execute('INSERT INTO goals(match_id,team_id,scorer,minute,own_goal,penalty,source_row) VALUES(?,?,?,?,?,?,?)',
                          (key,self.team(r['team'],'international'),r['scorer'],minute or None,boolean(r['own_goal']),boolean(r['penalty']),line))
                    else:
                        if r['winner'] not in (r['home_team'],r['away_team']):raise ValueError('non_participant')
                        db.execute('UPDATE matches SET shootout_winner_id=? WHERE id=?',(self.team(r['winner'],'international'),key))
                    if path=='shootouts.csv' and r.get('first_shooter') in (r['home_team'],r['away_team']):
                        db.execute('UPDATE matches SET first_shooter_id=? WHERE id=?',(self.team(r['first_shooter'],'international'),key))
                    self.counts[path+'_accepted']+=1
                except (ValueError,KeyError,TypeError) as e:self.reject('international',str(e),path,line)
        for r in csv.DictReader(io.StringIO(z.read('former_names.csv').decode('utf-8-sig'))):
            db.execute('INSERT INTO former_names VALUES(?,?,?,?)',(r['current'],r['former'],date_value(r['start_date']),date_value(r['end_date'])))
        db.execute('CREATE INDEX IF NOT EXISTS goal_match ON goals(match_id,team_id,id)')
        # Coverage is marked only when all recorded goals agree with the final scores.
        db.execute('''UPDATE matches SET goals_complete=1 WHERE kind='international' AND home_score+away_score>0
         AND home_score=(SELECT count(*) FROM goals g WHERE g.match_id=matches.id AND g.team_id=matches.home_id)
         AND away_score=(SELECT count(*) FROM goals g WHERE g.match_id=matches.id AND g.team_id=matches.away_id)''')

    def squad_file(self,path,text):
        lines=text.splitlines();title=next((x.lstrip('= ').strip() for x in lines if x.startswith('= ') and not x.startswith('==')),None)
        if not title or ' - ' not in title:self.reject('squads','missing_title',path,1);return
        team,context=title.split(' - ',1);parts=PurePosixPath(path).parts
        national=parts[1]=='national';kind='international' if national else 'club'
        country='' if national else COUNTRIES.get(parts[1],parts[1].title())
        season=next((x for x in parts if re.fullmatch(r'\d{4}-\d{4}',x)),context)
        db=self.dbs['squads'];tid=self.team(team,kind,country,'squads');self.next_roster+=1;rid=self.next_roster
        db.execute('INSERT INTO rosters VALUES(?,?,?,?,?,?,?)',(rid,tid,context,season,'squads',path,norm(team+' '+context+' '+season)))
        status='listed';header=None
        for i,line in enumerate(lines,1):
            if line.startswith('=='):status='past';header=None;continue
            if line.startswith('Number,'):
                header=[h.strip().replace('Namea','Name').replace('Date o-f Birth','Date of Birth').replace('Date of Birth-','Date of Birth') for h in line.split(',')];continue
            if not line.strip() or header is None:continue
            self.counts['squads_rows']+=1
            # Cache is deliberately unquoted comma-separated text, including feet/inches.
            fields=[x.strip() for x in line.split(',')]
            if len(fields)!=len(header):self.reject('squads','column_count',path,i);continue
            r=dict(zip(header,fields));name=r.get('Name','').strip()
            if not name or name in ('-','?') or name.startswith('='):self.reject('squads','missing_name',path,i);continue
            rel=next((x for x in ('Previous Club','New Club','Current Club') if x in r),'')
            db.execute('INSERT INTO squad_entries(roster_id,name,nationality,position,shirt,birth_date_text,height,weight,birth_place,status,related_club,relation,source_row) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',
              (rid,name,r.get('Nat'),r.get('Pos'),r.get('Number'),r.get('Date of Birth'),r.get('Height'),r.get('Weight'),r.get('Birth Place'),status,r.get(rel),rel,i))
            self.counts['squads_accepted']+=1

    def selections(self,path):
        data=json.loads(Path(path).read_text(encoding='utf-8-sig'));db=self.dbs['matches'];summary=[]
        assert len(data['maclar'])==37 and len({x['matchId'] for x in data['maclar']})==37
        for r in data['maclar']:
            expected='international' if r['kategori']=='milli' else 'club'
            # Match only using independently imported results and unique team aliases.
            options=db.execute('''SELECT m.id,h.name,a.name,h.canonical_club_id,a.canonical_club_id FROM matches m
             JOIN teams h ON h.id=m.home_id JOIN teams a ON a.id=m.away_id WHERE m.date=? AND m.kind=? AND m.conflict=0''',(r['tarih'],expected)).fetchall()
            def fits(label,name,cid):return norm(label)==norm(name) or (cid in ALIASES and norm(label) in {norm(x) for x in ALIASES[cid]})
            matches=[x[0] for x in options if (fits(r['evSahibi'],x[1],x[3]) and fits(r['deplasman'],x[2],x[4])) or
                         (fits(r['evSahibi'],x[2],x[4]) and fits(r['deplasman'],x[1],x[3]))]
            matches=list(set(matches));mid=matches[0] if len(matches)==1 else None
            status='independent_result' if mid else 'catalog_only'
            db.execute('INSERT INTO selections VALUES(?,?,?,?,?,?,?,?)',(r['matchId'],r['kategori'],r['baslik'],r['tarih'],r['evSahibi'],r['deplasman'],mid,status))
            summary.append({'statsbomb_id':r['matchId'],'status':status,'match_id':mid,'events_available':False,'lineups_available':False})
        self.report['statsbomb']={'requested':37,'raw_events':0,'raw_lineups':0,'linked_results':sum(x['match_id'] is not None for x in summary),'selections':summary,
          'note':'Selection metadata only. No StatsBomb raw events/lineups were supplied or distributed. Do not treat season squads as starting lineups.'}

    def finish(self,out):
        self.dbs['matches'].executescript('''CREATE INDEX match_date ON matches(date DESC,id);
         CREATE INDEX match_scope ON matches(kind,competition,date DESC,id);
         CREATE INDEX match_home ON matches(home_id,date DESC);CREATE INDEX match_away ON matches(away_id,date DESC);
         CREATE INDEX IF NOT EXISTS goal_match ON goals(match_id,team_id,id);CREATE INDEX source_match ON match_sources(match_id);
         CREATE INDEX match_season ON matches(competition,season);''')
        self.dbs['squads'].executescript('''CREATE INDEX roster_team ON rosters(team_id,season DESC,id);
         CREATE INDEX roster_season ON rosters(season DESC,id);CREATE INDEX squad_roster ON squad_entries(roster_id,id);''')
        manifest={'schema_version':VERSION,'cutoff':self.cutoff,'packs':{},'sources':{k:dict(zip(('name','url','license','note'),v)) for k,v in SOURCES.items()}}
        for kind,db in self.dbs.items():
            db.execute('CREATE INDEX team_search ON teams(search)');db.commit()
            assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
            assert not db.execute('PRAGMA foreign_key_check').fetchall()
            tables=['teams','matches','goals','former_names','selections'] if kind=='matches' else ['teams','rosters','squad_entries']
            counts={t:db.execute(f'SELECT count(*) FROM {t}').fetchone()[0] for t in tables}
            if kind=='matches':
                counts['conflicting_matches']=db.execute('SELECT count(*) FROM matches WHERE conflict=1').fetchone()[0]
                counts['international']=db.execute("SELECT count(*) FROM matches WHERE kind='international'").fetchone()[0]
            db.execute('VACUUM');db.close()
            raw=(self.directory/f'{kind}.sqlite').read_bytes();compressed=gzip.compress(raw,compresslevel=9,mtime=0)
            parts=[]
            for index,offset in enumerate(range(0,len(compressed),6_000_000)):
                chunk=compressed[offset:offset+6_000_000];asset=f'assets/history/{kind}.sqlite.gz.part{index+1}'
                (out/asset).parent.mkdir(parents=True,exist_ok=True);(out/asset).write_bytes(chunk)
                parts.append({'asset':asset,'bytes':len(chunk),'sha256':hashlib.sha256(chunk).hexdigest()})
            manifest['packs'][kind]={'parts':parts,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),
               'compressed_bytes':len(compressed),'compressed_sha256':hashlib.sha256(compressed).hexdigest(),'counts':counts}
            print(kind,counts,'compressed',len(compressed),'uncompressed',len(raw))
        self.report['counts']=dict(sorted(self.counts.items()));self.report['rejected']=dict(sorted(self.rejected.items()));self.report['examples']=self.examples
        (out/'assets/history/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        (out/'docs/history/import-report.json').parent.mkdir(parents=True,exist_ok=True)
        (out/'docs/history/import-report.json').write_text(json.dumps(self.report,ensure_ascii=False,indent=2)+'\n')

    def run(self,archive,selections,out):
        with zipfile.ZipFile(archive) as outer:
            for member in sorted(outer.infolist(),key=lambda x:x.filename):
                if member.is_dir():continue
                name=PurePosixPath(member.filename).name
                if name not in ARCHIVES:raise ValueError('Unexpected nested archive: '+name)
                raw=outer.read(member);source=ARCHIVES[name]
                with zipfile.ZipFile(io.BytesIO(raw)) as z:
                    files=[x for x in z.infolist() if not x.is_dir()]
                    self.report['inputs'][source]={'file':name,'sha256':hashlib.sha256(raw).hexdigest(),'files':len(files),'bytes':sum(x.file_size for x in files)}
                    if source=='international':self.international(z);continue
                    if not any(PurePosixPath(x.filename).name=='LICENSE.md' and z.read(x).startswith(b'CC0') for x in files):raise ValueError('Missing expected archive license')
                    for f in sorted(files,key=lambda x:x.filename):
                        if f.file_size>10_000_000:raise ValueError('Oversize input')
                        if source=='squads' and f.filename.endswith('.txt'):
                            self.squad_file(f.filename,z.read(f).decode('utf-8-sig',errors='strict'))
                        elif source!='squads' and f.filename.endswith('.csv'):
                            self.club_file(source,f.filename,z.read(f).decode('utf-8-sig',errors='strict'))
                    self.dbs['squads' if source=='squads' else 'matches'].commit()
        self.selections(selections);self.finish(out)

def main():
    p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);p.add_argument('--selection',type=Path,default=ROOT/'tools/history/statsbomb_selection.json');p.add_argument('--cutoff',required=True);p.add_argument('--output',type=Path,default=ROOT)
    args=p.parse_args()
    with tempfile.TemporaryDirectory(prefix='linkball-history-') as tmp:
        b=Builder(Path(tmp),args.cutoff);b.directory=Path(tmp);b.run(args.archive,args.selection,args.output)
if __name__=='__main__':main()
