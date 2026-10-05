"""Export a deterministic, reviewed popular-club answer catalog for the server."""
import json
import re
import sqlite3
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def main():
    text=(ROOT/'lib/data/popular_clubs_pool.dart').read_text().split('const List<int> popularClubIds = [')[1].split('];')[0]
    ids=[int(n) for n in re.findall(r'^\s*(\d+),',text,re.M)]
    ids=[371 if i==465 else i for i in ids]  # Celtic's canonical club, not St Mirren.
    with sqlite3.connect(ROOT/'assets/runtime/linkball_game_data_v4.sqlite') as c:
        clubs={str(i):c.execute('SELECT name FROM clubs WHERE id=?',(i,)).fetchone()[0] for i in ids}
        pairs={};players={}
        for ai,a in enumerate(ids):
            for b in ids[ai+1:]:
                rows=c.execute('''SELECT p.id,p.name,p.country,p.position FROM players p
                  JOIN player_clubs a ON a.player_id=p.id JOIN player_clubs b ON b.player_id=p.id
                  WHERE a.club_id=? AND b.club_id=? AND p.answer_eligible=1 ORDER BY p.selection_rank,p.id''',(a,b)).fetchall()
                if len(rows)<4:continue
                pairs['-'.join(map(str,sorted([a,b])))]=[r[0] for r in rows]
                for pid,name,country,position in rows:
                    aliases=[r[0] for r in c.execute('SELECT alias FROM player_aliases WHERE player_id=?',(pid,))]
                    players[str(pid)]=dict(name=name,country=country,position=position,aliases=aliases)
    result=dict(version=1,clubs=clubs,pairs=pairs,players=players)
    (ROOT/'functions/config/daily_catalog.json').write_text(json.dumps(result,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n')
    print(len(clubs),'clubs',len(pairs),'pairs',len(players),'players')
if __name__=='__main__':main()
