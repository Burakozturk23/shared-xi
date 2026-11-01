"""Closed-career negative evidence, canonical V4 IDs, deterministic questions."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
OUT = ROOT / 'functions/config/fake_club_catalog.json'


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    review = json.loads((ROOT / 'tools/fake_club/coverage.json').read_text())
    rawclubs = {r['id']: dict(r) for r in con.execute('select * from clubs')}

    def cid(i):
        return i - 1000000000 if i >= 1000000000 and i - 1000000000 in rawclubs else i

    clubs = {cid(i): dict(id=cid(i), name=rawclubs[cid(i)]['name'],
        country=rawclubs[cid(i)]['country'], league=rawclubs[cid(i)]['competition'],
        badgeKey=rawclubs[cid(i)]['badge_key'], popularity=rawclubs[cid(i)]['popularity_seed'])
        for i in rawclubs if rawclubs[cid(i)]['entity_type'] == 'SENIOR'
        and rawclubs[cid(i)]['country'] and rawclubs[cid(i)]['competition']
        and rawclubs[cid(i)]['gameplay_eligible'] and '\\' not in rawclubs[cid(i)]['name']}
    questions, careers, rejected = [], [], Counter()
    # Each fake club appears at most this many times in the whole catalog.
    fake_uses, FAKE_CAP = Counter(), 5
    for p in review['players']:
        pid = p['playerId']
        person = con.execute('select * from players where id=?', (pid,)).fetchone()
        if not person or p['coverage'] != 'REVIEWED_COMPLETE_RETIRED' or not p['sources']:
            rejected['incomplete_coverage'] += 1
            continue
        source_links = {cid(r[0]) for r in con.execute('select club_id from player_clubs where player_id=? and trust>=2', (pid,))}
        real = set(map(cid, p['seniorClubIds']))
        assert real <= source_links, f'Review not backed by V4: {pid}'
        # Exclude ALL known career associations, not just the three displayed clubs
        # or high-trust/popular/senior links; uncertainty can only remove candidates.
        excluded = real | {cid(r[0]) for r in con.execute('select club_id from player_clubs where player_id=?', (pid,))}
        excluded |= {cid(r[0]) for r in con.execute('select club_id from career_spells where player_id=?', (pid,))}
        for r in con.execute('select from_club_id,to_club_id from transfers where player_id=?', (pid,)):
            excluded.update(map(cid, r))
        displayed = sorted(real & clubs.keys())
        if len(displayed) < 3:
            rejected['fewer_than_three_displayable_clubs'] += 1
            continue
        career = dict(playerId=pid, seniorClubIds=sorted(real), excludedClubIds=sorted(excluded),
            coverage=p['coverage'], sources=p['sources'], reviewedAt=p['reviewedAt'])
        careers.append(career)
        # Finite offline generation. Up to four distinct triples per retired player.
        triples = sorted(itertools.combinations(displayed, 3), key=digest)[:4]
        for triple in triples:
            countries = {clubs[i]['country'] for i in triple}
            # A league name is only meaningful with its country ("Bundesliga").
            leagues = {(clubs[i]['country'], clubs[i]['league']) for i in triple}
            pops = [clubs[i]['popularity'] for i in triple]
            mean = sum(pops) / 3
            fake = [c for c in clubs.values() if c['id'] not in excluded and c['popularity'] >= 10]
            # No tier gives the fake away by an odd country, and from normal up
            # it is never simply the least known of the four.
            rules = {
                'easy': lambda c: c['country'] in countries,
                'normal': lambda c: (c['country'], c['league']) in leagues,
                'hard': lambda c: (c['country'], c['league']) in leagues and abs(c['popularity'] - mean) <= 20
                    and c['popularity'] >= min(pops),
                'legend': lambda c: (c['country'], c['league']) in leagues and abs(c['popularity'] - mean) <= 10
                    and c['popularity'] >= min(pops),
            }
            # Relax one step at a time only when fewer than two candidates remain.
            chain = {'easy': ['easy'], 'normal': ['normal', 'easy'], 'hard': ['hard', 'normal', 'easy'],
                     'legend': ['legend', 'hard', 'normal', 'easy']}
            for difficulty in ['easy', 'normal', 'hard', 'legend']:
                for step, rule in enumerate(chain[difficulty]):
                    eligible = [c for c in fake if rules[rule](c) and fake_uses[c['id']] < FAKE_CAP]
                    if len(eligible) >= 2: break
                if step: rejected[f'tier_relaxed_{difficulty}'] += 1
                ordered = sorted(eligible, key=lambda c: (fake_uses[c['id']], digest([pid, triple, difficulty, c['id']])))
                for candidate in ordered[:2]:
                    fake_uses[candidate['id']] += 1
                    fid = candidate['id']
                    key = digest([pid, triple, fid, difficulty])[:24]
                    evidence = dict(coverage=p['coverage'], sources=p['sources'], reviewedAt=p['reviewedAt'])
                    questions.append(dict(key=key, playerId=pid, player=dict(id=pid, name=person['name'],
                        country=person['country'], avatarKey=person['avatar_key']),
                        realClubIds=list(triple), fakeClubId=fid, difficulty=difficulty, evidence=evidence,
                        options=[clubs[i] for i in sorted([*triple, fid], key=lambda i: digest([key, i]))]))
    data = dict(schema=1, databaseSha256=hashlib.sha256(DB.read_bytes()).hexdigest(),
        reviewSha256=digest(review), careers=careers, questions=questions,
        quality=dict(players=len(careers), questions=len(questions), difficulties=dict(Counter(q['difficulty'] for q in questions)),
            maxFakeUses=max(fake_uses.values()), distinctFakes=len(fake_uses),
            rejected=dict(rejected), policy='complete_retired_career_allowlist_only'))
    data['version'] = 'fc-v1-' + digest(data)[:16]
    for q in questions:
        q['questionId'] = data['version'] + '-' + q.pop('key')
        q['dataVersion'] = data['version']
        q['trust'] = 'REVIEWED_COMPLETE_RETIRED'
    assert len(careers) >= 30 and len(questions) >= 100
    for q in questions:
        ids = [c['id'] for c in q['options']]
        assert len(set(ids)) == 4 and sum(i in q['realClubIds'] for i in ids) == 3
        assert q['fakeClubId'] not in next(c['excludedClubIds'] for c in careers if c['playerId'] == q['playerId'])
    return data


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    encoded = json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n'
    if args.check:
        assert OUT.read_text(encoding='utf-8') == encoded, 'Catalog drift'
    else:
        OUT.write_text(encoded, encoding='utf-8')
    print(json.dumps(data['quality'], ensure_ascii=False))
