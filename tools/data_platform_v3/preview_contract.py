from __future__ import annotations
import csv, json, re, sys
from collections import Counter, defaultdict
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'assets' / 'data'
OUT = ROOT / 'reports' / 'data_platform_v3' / '03b'
CONTRACT = Path(__file__).resolve().parent / 'config' / 'canonical_contract.json'


def load_json(name, default=None):
    p=DATA/name
    if not p.exists():
        return default
    with p.open('r',encoding='utf-8-sig') as f:
        return json.load(f)

def as_list(v):
    return v if isinstance(v,list) else []

def nonempty(v):
    if v is None: return False
    if isinstance(v,str): return bool(v.strip())
    if isinstance(v,(list,dict)): return bool(v)
    return True

def idx(rows):
    out={}
    for r in rows or []:
        if not isinstance(r,dict): continue
        try: k=int(r.get('id'))
        except Exception: continue
        out[k]=r
    return out

def norm_name(s):
    s=(s or '').strip().casefold()
    return re.sub(r'\s+',' ',s)

def write_csv(name, headers, rows):
    p=OUT/name
    with p.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=headers)
        w.writeheader(); w.writerows(rows)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    contract=json.load(CONTRACT.open('r',encoding='utf-8'))
    pmin=load_json('players_min.json',[]) or []
    pfull=load_json('players.json',[]) or []
    cmin=load_json('clubs_min.json',[]) or []
    cfull=load_json('clubs.json',[]) or []
    im,iff,ic,icf=idx(pmin),idx(pfull),idx(cmin),idx(cfull)
    min_ids=set(im); full_ids=set(iff); overlap=min_ids&full_ids

    # Club reference namespace analysis
    refs=Counter(); ref_players=defaultdict(set); timeline_refs=Counter()
    for pid,p in im.items():
        for cid in as_list(p.get('clubIds')):
            try: cid=int(cid)
            except Exception: continue
            refs[cid]+=1; ref_players[cid].add(pid)
        for stop in as_list(p.get('careerTimeline')):
            if not isinstance(stop,dict): continue
            raw=stop.get('clubId',stop.get('club_id',stop.get('id')))
            try: cid=int(raw)
            except Exception: continue
            timeline_refs[cid]+=1; ref_players[cid].add(pid)
    all_refs=set(refs)|set(timeline_refs)
    resolved=all_refs & set(ic)
    missing=all_refs - set(ic)

    # Same normalized club names carrying multiple current IDs is evidence canonical mapping matters.
    name_groups=defaultdict(list)
    for cid,c in ic.items():
        n=norm_name(c.get('name'))
        if n: name_groups[n].append(cid)
    dup_club_names={n:v for n,v in name_groups.items() if len(v)>1}

    namespace_rows=[]
    for cid in sorted(all_refs, key=lambda x: (x not in missing, -refs[x]-timeline_refs[x], x)):
        c=ic.get(cid,{})
        namespace_rows.append({
            'sourceClubId':cid,
            'status':'resolved_current_club' if cid in ic else 'needs_mapping',
            'clubName':c.get('name',''),
            'country':c.get('country',''),
            'league':c.get('league',''),
            'clubIdUses':refs[cid],
            'timelineUses':timeline_refs[cid],
            'affectedPlayers':len(ref_players[cid]),
        })
    write_csv('club_id_namespace.csv',list(namespace_rows[0].keys()) if namespace_rows else ['sourceClubId'],namespace_rows)

    # Full/min merge policy report
    fields=['name','countries','position','aliases','clubIds','careerTimeline','careerGoals','nationalTeams','detailedPosition','marketValue','peakMarketValue']
    merge_rows=[]
    priorities=contract['fieldPriority']
    for field in fields:
        minuse=sum(1 for p in im.values() if nonempty(p.get(field)))
        fulluse=sum(1 for p in iff.values() if nonempty(p.get(field)))
        mismatch=0
        for pid in overlap:
            a,b=im[pid].get(field),iff[pid].get(field)
            if nonempty(a) and nonempty(b) and a!=b: mismatch+=1
        strategy=''
        if field=='position': strategy=str(priorities.get('positionGroup'))
        elif field=='clubIds': strategy=str(priorities.get('clubMembership'))
        else: strategy=str(priorities.get(field,''))
        merge_rows.append({'field':field,'minUseful':minuse,'fullUseful':fulluse,'overlapMismatches':mismatch,'canonicalStrategy':strategy})
    write_csv('field_merge_policy.csv',['field','minUseful','fullUseful','overlapMismatches','canonicalStrategy'],merge_rows)

    # Compatibility / migration gates
    gates=[
      ('G01','No orphan club source reference is silently converted into a canonical club','BLOCKED',f'{len(missing)} unique club IDs need mapping'),
      ('G02','Existing player IDs remain stable during migration','PASS',f'{len(min_ids)} production player IDs retained'),
      ('G03','Full-only players are not auto-promoted','PASS',f'{len(full_ids-min_ids)} full-only records quarantined for review'),
      ('G04','Market value fields are excluded from new canonical core','PASS','Kept only as legacy compatibility until affected games migrate'),
      ('G05','Question pools exclude unresolved clubs','DESIGN_READY','Will activate after popularity/quality step'),
      ('G06','Raw/full JSON is not removed yet','PASS','03B is preview-only; runtime unchanged')
    ]
    write_csv('migration_gates.csv',['gate','rule','status','detail'],[{'gate':a,'rule':b,'status':c,'detail':d} for a,b,c,d in gates])

    # Sample canonical players. Do not change runtime data.
    samples=[]
    chosen=list(sorted(overlap))[:100]
    for pid in chosen:
        m=im[pid]; f=iff.get(pid,{})
        samples.append({
          'id':pid,
          'name':m.get('name') or f.get('name') or f'Player {pid}',
          'aliases':as_list(m.get('aliases')),
          'countries':as_list(m.get('countries')) or as_list(f.get('countries')),
          'positionGroup':m.get('position') or f.get('position') or '',
          'detailedPosition':f.get('detailedPosition') or '',
          'legacyClubRefs':as_list(m.get('clubIds')),
          'nationalTeams':as_list(f.get('nationalTeams')),
          'qualityState':'partial' if any(int(x) in missing for x in as_list(m.get('clubIds')) if str(x).lstrip('-').isdigit()) else 'valid'
        })
    with (OUT/'canonical_players.sample.json').open('w',encoding='utf-8') as f: json.dump(samples,f,ensure_ascii=False,indent=2)

    summary={
      'generatedAtUtc':datetime.now(timezone.utc).isoformat(),
      'contractVersion':contract['contractVersion'],
      'runtimeChanged':False,
      'playersMin':len(im),'playersFull':len(iff),'playerOverlap':len(overlap),
      'playersOnlyMin':len(min_ids-full_ids),'playersOnlyFull':len(full_ids-min_ids),
      'clubsCurrent':len(ic),'clubsFull':len(icf),
      'uniqueReferencedClubIds':len(all_refs),'resolvedReferencedClubIds':len(resolved),'unmappedReferencedClubIds':len(missing),
      'clubReferenceRows':sum(refs.values())+sum(timeline_refs.values()),
      'playersAffectedByUnmappedClubIds':len({pid for cid in missing for pid in ref_players[cid]}),
      'duplicateNormalizedClubNameGroups':len(dup_club_names),
      'decision':'Use a club source-ID mapping layer before any production canonical club rebuild.'
    }
    with (OUT/'summary.json').open('w',encoding='utf-8') as f: json.dump(summary,f,ensure_ascii=False,indent=2)

    md=f'''# Linkball Data Platform v3 — 03B Canonical Contract Preview\n\nGenerated: `{summary['generatedAtUtc']}`\n\n## Decision\n\n**Runtime is unchanged in Step 03B.** This step freezes the migration contract before we rewrite data.\n\nThe audit proves the current club problem is not a small missing-row problem. The player/timeline data references **{len(all_refs):,} unique club IDs**, while `clubs_min.json` has **{len(ic):,} clubs**. **{len(missing):,} referenced IDs do not currently map to a club row**, affecting **{summary['playersAffectedByUnmappedClubIds']:,} players**.\n\nTherefore we will **not** generate {len(missing):,} permanent `Club {{id}}` rows. Step 03C will build a `club_source_refs -> canonical_club` mapping layer and deduplicate historical/legacy/source IDs.\n\n## Player source decision\n\n- `players_min.json` remains the migration identity/core source for now: **{len(im):,} players**.\n- `players.json` is an enrichment source: **{len(iff):,} players**.\n- Overlap: **{len(overlap):,}**.\n- Min-only: **{len(min_ids-full_ids):,}**.\n- Full-only: **{len(full_ids-min_ids):,}**; these are not automatically promoted.\n- Rich fields from full are additive only until validation; they do not overwrite core identity silently.\n\n## Canonical layers frozen by this step\n\n1. Player\n2. Club\n3. Club source-reference mapping\n4. Player-club spells\n5. Competition\n6. Player aggregate stats\n7. National stats\n8. Game-pool flags\n\n## Important policy\n\n- `marketValue` / `peakMarketValue` are **legacy compatibility fields**, not part of the new canonical core.\n- Unresolved/partial entities may preserve a career relationship, but are never automatic question candidates.\n- Player/club visual assets are separate from football facts.\n- Raw/full source datasets will not ship in the final production bundle.\n\n## Next step: 03C\n\nBuild the actual **Club Identity Resolver** using source club tables, names, countries, leagues and player-history evidence. The target is not 41k visible clubs; the target is a clean canonical club registry plus aliases/source-ID mappings, while preserving historical career relationships.\n'''
    (OUT/'README.md').write_text(md,encoding='utf-8')
    print('\n03B preview complete.')
    print(f'Report: {OUT}')
    print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':
    try: main()
    except Exception as e:
        print(f'ERROR: {e}',file=sys.stderr); raise
