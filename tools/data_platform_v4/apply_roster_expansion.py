#!/usr/bin/env python3
"""Apply a reviewed roster expansion to a hash-pinned V4 package, offline."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import tempfile
import unicodedata

ROOT=Path(__file__).resolve().parents[2]
SOURCE='worldcup26-roster'
ID_OFFSET=3_000_000_000


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def norm(s):
    s=(s or '').casefold().translate(str.maketrans({'ı':'i','ø':'o','ł':'l','đ':'d','ð':'d','þ':'th','æ':'ae','œ':'oe','ß':'ss'}))
    s=''.join(x for x in unicodedata.normalize('NFKD',s) if not unicodedata.combining(x))
    return re.sub(r'\s+',' ',re.sub('[^a-z0-9 ]',' ',s)).strip()


def load_review(path):
    path=Path(path);data=json.loads(path.read_text(encoding='utf-8'));data['rows']=[]
    for part in data['parts']:
        p=path.parent/part['file']
        if digest(p)!=part['sha256']:raise ValueError('Evidence part hash mismatch')
        data['rows'].extend(json.loads(p.read_text(encoding='utf-8')))
    return data


def add_search(con,pid,label,kind,priority):
    term=norm(label)
    if term:con.execute('INSERT OR IGNORE INTO player_search_terms VALUES(?,?,?,?,?)',(pid,term,term.replace(' ',''),kind,priority))


def apply(database,manifest_path,review_path):
    database,manifest_path=Path(database),Path(manifest_path)
    review=load_review(review_path);manifest=json.loads(manifest_path.read_text(encoding='utf-8'));before=digest(database)
    if before!=manifest['database']['sha256']:raise ValueError('Manifest hash mismatch')
    previous=next((e for e in manifest.get('expansions',[]) if e['id']==review['id']),None)
    if previous:
        if previous['outputSha256']!=before:raise ValueError('Applied expansion output changed')
        return previous
    if before!=review['baseSha256']:raise ValueError('Review database hash mismatch')
    rows=[r for r in review['rows'] if r['status'] in ('new_player','add_link','existing')]
    new_by_source={r['sourcePlayerId']:r for r in rows if r['status']=='new_player'}
    if len(new_by_source)!=review['newPlayers']:raise ValueError('New-player count mismatch')
    with tempfile.TemporaryDirectory(dir=database.parent) as td:
        output=Path(td)/database.name;shutil.copy2(database,output)
        with sqlite3.connect(output) as con:
            con.execute('PRAGMA foreign_keys=ON')
            old_counts={t:con.execute('SELECT COUNT(*) FROM '+t).fetchone()[0] for t in ['players','clubs','player_clubs','transfers','career_spells']}
            rank=con.execute('SELECT MAX(selection_rank) FROM players').fetchone()[0]
            links_added=0
            for sid,r in sorted(new_by_source.items(),key=lambda x:int(x[0])):
                pid=ID_OFFSET+int(sid)
                if con.execute('SELECT 1 FROM players WHERE id=?',(pid,)).fetchone():raise ValueError('ID collision')
                if not r['birthYear'] or not r['nationality'] or not norm(r['name']):raise ValueError('Incomplete new identity')
                rank+=1
                nationality={'Turkey':'Türkiye','Congo DR':'DR Congo','Ivory Coast':"Cote d'Ivoire",'United States':'United States'}.get(r['nationality'],r['nationality'])
                position={'G':'GK','GK':'GK','D':'DF','M':'MF','F':'FW'}.get(r.get('position'))
                con.execute('''INSERT INTO players(id,name,country,position,selection_score,selection_rank,answer_eligible,playable,source)
                    VALUES(?,?,?,?,0,?,1,1,?)''',(pid,r['name'],nationality,position,rank,SOURCE))
                con.execute('INSERT INTO profiles(player_id,birth_year,citizenship,position_group,source_last_season,identity_confidence) VALUES(?,?,?,?,?,?)',(pid,r['birthYear'],nationality,position,2026,'ROSTER_SOURCE_ID'))
                con.execute('INSERT INTO player_countries VALUES(?,?,?)',(pid,0,nationality))
                con.executemany('INSERT INTO player_tags VALUES(?,?)',[(pid,'answer'),(pid,'playable')])
                add_search(con,pid,r['name'],'name',100)
                add_search(con,pid,norm(r['name']).split()[-1],'surname',60)
            processed=set()
            for r in rows:
                pid=ID_OFFSET+int(r['sourcePlayerId']) if r['status']=='new_player' else r['playerId']
                club=con.execute('SELECT name FROM clubs WHERE id=?',(r['clubId'],)).fetchone()
                if not club or club[0]!=r['club']:raise ValueError('Club mapping mismatch')
                if (pid,r['clubId']) not in processed:
                    inserted=con.execute('INSERT OR IGNORE INTO player_clubs(player_id,club_id,trust,source) VALUES(?,?,2,?)',(pid,r['clubId'],'roster:worldcup26:2026-09-29.2')).rowcount
                    links_added+=inserted;processed.add((pid,r['clubId']))
                canonical=con.execute('SELECT name FROM players WHERE id=?',(pid,)).fetchone()[0]
                existing={norm(a[0]) for a in con.execute('SELECT alias FROM player_aliases WHERE player_id=?',(pid,))};existing.add(norm(canonical))
                order=con.execute('SELECT COALESCE(MAX(ord),-1)+1 FROM player_aliases WHERE player_id=?',(pid,)).fetchone()[0]
                for label in r['names']:
                    if norm(label) and norm(label) not in existing:
                        con.execute('INSERT INTO player_aliases VALUES(?,?,?,?)',(pid,order,label,norm(label)));order+=1;existing.add(norm(label))
                        add_search(con,pid,label,'alias',80)
            if links_added!=review['newLinks']:raise ValueError(f'Link count mismatch: {links_added}')
            total=old_counts['players']+len(new_by_source)
            if con.execute('SELECT COUNT(*) FROM players').fetchone()[0]!=total:raise ValueError('Player count mismatch')
            for t in ('clubs','transfers','career_spells'):
                if con.execute('SELECT COUNT(*) FROM '+t).fetchone()[0]!=old_counts[t]:raise ValueError('Unexpected '+t+' change')
            for key,value in [('player_count',str(total)),('player_club_rows',str(old_counts['player_clubs']+links_added)),('data_revision',review['id'])]:
                con.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)',(key,value))
            if con.execute('PRAGMA integrity_check').fetchone()[0]!='ok' or con.execute('PRAGMA foreign_key_check').fetchall():raise ValueError('Integrity failure')
            if con.execute('SELECT COUNT(DISTINCT player_id) FROM player_search_terms').fetchone()[0]!=total:raise ValueError('Unsearchable player')
            if con.execute('SELECT COUNT(DISTINCT player_id) FROM player_clubs').fetchone()[0]!=total:raise ValueError('Player without club')
        after=digest(output)
        manifest['database'].update(sha256=after,bytes=output.stat().st_size,sizeMB=round(output.stat().st_size/1024**2,2))
        for key in ('players','unique_player_ids','players_with_clubs','search_players'):manifest['counts'][key]=total
        manifest['revision']=review['id'];manifest['updatedUtc']=review['reviewedUtc']
        result={'id':review['id'],'baseSha256':before,'outputSha256':after,'newPlayers':len(new_by_source),'newLinks':links_added,'definition':str(review_path)}
        manifest.setdefault('expansions',[]).append(result)
        next_manifest=Path(td)/manifest_path.name;next_manifest.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        os.replace(output,database);os.replace(next_manifest,manifest_path)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('review');p.add_argument('--database',default=ROOT/'assets/runtime/linkball_game_data_v4.sqlite');p.add_argument('--manifest',default=ROOT/'assets/runtime/linkball_game_data_v4_manifest.json');a=p.parse_args()
    print(json.dumps(apply(a.database,a.manifest,a.review),indent=2))
