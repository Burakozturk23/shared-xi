#!/usr/bin/env python3
"""Cross-runtime fixtures: raw V4 -> Dart solo models versus private PvP catalog."""
import gzip, json, pathlib, random, re, sqlite3, subprocess, sys
from build_catalog import ROOT, DB, country, key, position_group

catalog = json.loads(gzip.decompress((ROOT/'functions/config/pvp_catalog.json.gz').read_bytes()))
c = sqlite3.connect(f'file:{DB}?mode=ro', uri=True); c.row_factory = sqlite3.Row
source = {str(r['id']):dict(r) for r in c.execute('select p.*,pr.detailed_position from players p left join profiles pr on pr.player_id=p.id')}
script = '''const E=require('./functions/pvp_engine'),c=E.catalog;const cases=[];
for(let i=0;i<8;i++) {
 const q=E.puzzle(c,'club_manager','parity'+i),f=i%2?'442':'433';
 const ids=Object.entries(E.FORMATIONS[f]).flatMap(([pos,n])=>q.pool.map(id=>c.players[id])
   .filter(p=>p.position===pos).sort((a,b)=>a.cost-b.cost).slice(0,n).map(p=>p.id));
 const squad={playerIds:ids,formation:f,tactics:{press:i/7,tempo:1-i/7,width:.5}};
 cases.push({...squad,power:E.power(c,squad)});
} console.log(JSON.stringify(cases));'''
cases = json.loads(subprocess.check_output(['node','-e',script],cwd=ROOT,text=True))
ids = {p for t in cases for p in t['playerIds']}
ranked = sorted(catalog['players'],key=lambda i:(catalog['players'][i]['rank'],i))
ids.update(ranked[:48]); ids.update(random.Random(1019).sample(ranked,80))
seen = set()
for i,r in source.items():
    signature=(r['position'],r['detailed_position'])
    if i in catalog['players'] and signature not in seen:
        ids.add(i);seen.add(signature)
def year(s):
    m=re.search(r'\d{4}',s or ''); return int(m[0]) if m else None
players=[]; club_ids=set()
for i in sorted(ids,key=int):
    r=source[i]
    clubs=[x[0] for x in c.execute('select club_id from player_clubs where player_id=?',(i,))]
    countries=[x[0] for x in c.execute('select country from player_countries where player_id=? order by ord',(i,))]
    timeline=[{'clubId':x['club_id'],'startYear':year(x['start_date']),'endYear':year(x['end_date'])}
      for x in c.execute('select * from career_spells where player_id=? order by sequence',(i,)) if year(x['start_date'])]
    raw={'id':int(i),'name':r['name'],'position':r['position'],'detailedPosition':r['detailed_position'],
      'countries':countries or ([r['country']] if r['country'] else []),'clubs':clubs,
      'careerTimeline':timeline,'peakMarketValue':r['peak_market_value'] or 0}
    expected=catalog['players'][i]
    players.append({'raw':raw,'expected':{k:expected[k] for k in ['id','clubs','countries','position','rating','cost']}})
    club_ids.update(clubs);club_ids.update(x['clubId'] for x in timeline)
clubs=[{'id':i,'name':catalog['clubs'][str(i)]['name'],'league':catalog['clubs'][str(i)]['league'],
  'country':catalog['clubs'][str(i)]['country']} for i in sorted(club_ids) if str(i) in catalog['clubs']]
block=(ROOT/'lib/utils/country_names.dart').read_text().split('_aliases = {',1)[1].split('};',1)[0]
aliases=[m.group(2) for m in re.finditer(r"(['\"])(.*?)\1\s*:",block)]
body=json.dumps({'year':catalog['ratingYear'],'version':catalog['version'],'clubs':clubs,'players':players,
  'cases':cases,'countryAliases':[{'raw':x,'expected':country(x)} for x in aliases]},ensure_ascii=False,indent=2)+'\n'
output=ROOT/'tools/pvp/fixtures/parity.json'
if '--check' in sys.argv: assert output.read_text()==body,'PvP cross-runtime vector drift'
else: output.parent.mkdir(exist_ok=True);output.write_text(body)
print(f'{len(players)} real V4 players, {len(cases)} team powers, {len(aliases)} country aliases')
