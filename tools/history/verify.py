"""Verify distributed packs without requiring the private input ZIPs."""
import gzip
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile

ROOT=Path(__file__).resolve().parents[2]
def main():
    manifest=json.loads((ROOT/'assets/history/manifest.json').read_text())
    assert manifest['schema_version']==1
    with tempfile.TemporaryDirectory() as tmp:
        for name,info in manifest['packs'].items():
            chunks=[]
            for part in info['parts']:
                chunk=(ROOT/part['asset']).read_bytes()
                assert len(chunk)==part['bytes'] and hashlib.sha256(chunk).hexdigest()==part['sha256']
                chunks.append(chunk)
            compressed=b''.join(chunks)
            del chunks
            assert len(compressed)==info['compressed_bytes']
            assert hashlib.sha256(compressed).hexdigest()==info['compressed_sha256']
            raw=gzip.decompress(compressed)
            assert len(raw)==info['bytes']
            assert hashlib.sha256(raw).hexdigest()==info['sha256']
            path=Path(tmp)/(name+'.sqlite');path.write_bytes(raw)
            del raw,compressed
            db=sqlite3.connect(path)
            assert db.execute('PRAGMA integrity_check').fetchone()==('ok',)
            assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
            assert db.execute('PRAGMA user_version').fetchone()==(1,)
            for table,count in info['counts'].items():
                if table in ('international','conflicting_matches'):continue
                assert db.execute(f'SELECT count(*) FROM {table}').fetchone()[0]==count,(name,table)
            if name=='matches':
                assert db.execute('SELECT count(*) FROM selections').fetchone()==(37,)
                assert db.execute('SELECT count(*) FROM matches WHERE date>?',(manifest['cutoff'],)).fetchone()==(0,)
                assert db.execute('SELECT count(*) FROM matches m WHERE NOT EXISTS (SELECT 1 FROM match_sources s WHERE s.match_id=m.id)').fetchone()==(0,)
                assert db.execute('SELECT count(*) FROM goals g JOIN matches m ON m.id=g.match_id WHERE g.team_id NOT IN (m.home_id,m.away_id)').fetchone()==(0,)
                # Istanbul: every score phase must survive the import independently.
                rows=db.execute("SELECT home_score,away_score,et_home,et_away,pen_home,pen_away FROM matches WHERE date='2005-05-25' AND competition='uefa.champions'").fetchall()
                assert any(r==(3,3,3,3,3,2) or r==(3,3,3,3,2,3) for r in rows),rows
            else:
                assert db.execute("SELECT count(*) FROM squad_entries WHERE status NOT IN ('listed','past')").fetchone()==(0,)
                assert db.execute("SELECT count(*) FROM squad_entries WHERE status='past'").fetchone()[0]>0
            db.close();print(name,'integrity, hashes, counts and semantics verified')
if __name__=='__main__':main()
