"""Fake Club questions: canonical V4 IDs, reviewed negative evidence, deterministic.

Two pools. Retired legends and coaches (coverage.json, closed careers) make the
legend tier only, the last rounds. Active players (active_coverage.json, careers
checked against Wikipedia) make easy, normal and hard by how well known they are,
so a match goes from the best-known current stars to the legends.
"""
import argparse
from collections import Counter
import hashlib
import itertools
import json
from pathlib import Path
import sqlite3
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
OUT = ROOT / 'functions/config/fake_club_catalog.json'
TRUST = ('REVIEWED_COMPLETE_RETIRED', 'REVIEWED_WIKIPEDIA_CURRENT')
# Active players' tier by the online modes' gameplay rating (the database selection rank
# misses many stars): 84+ easy, 80+ normal, the rest hard.
EASY_RATING, NORMAL_RATING = 84, 80
# Clubs on the online club list (pvp catalog) and how many of the three a tier shows,
# as career_transfer_online.js FAKE_KNOWN requires.
NEED_KNOWN = {'easy': 2, 'normal': 2, 'hard': 1}
_PVP = json.loads(__import__('gzip').decompress((ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))
KNOWN = {int(k.split(':')[1]) for k in _PVP['clubOptions']}
RATING = {int(k): v['rating'] for k, v in _PVP['players'].items()}
# A fake club is one a fan knows, so spotting it takes knowing the career, not
# noticing the one unfamiliar name (UD Melilla next to Bayern, Barcelona, Dortmund):
# easy and normal fakes come from the online club lists, hard and legend ones may
# also be a club ten or more stars (78+) played for (Boca Juniors, Leeds, Málaga).
FAKE_KNOWN = KNOWN | {int(k.split(':')[1]) for k in _PVP['gridClubs']}

sys.path.insert(0, str(ROOT / 'tools/data_platform_v4'))
from build_current_club_review import YOUTH, norm, same_club, tokens  # noqa: E402

# Words many clubs share; the rest name one club ("juventus", "alkmaar").
COMMON = {'real', 'united', 'city', 'athletic', 'atletico', 'sporting', 'club', 'olympique', 'borussia',
          'inter', 'saint', 'union', 'royal', 'deportivo', 'dynamo', 'lokomotiv', 'spartak', 'sport',
          'calcio', 'football', 'stade', 'futebol', 'racing', 'county', 'town', 'rovers', 'wanderers',
          'albion', 'hotspur', 'athletico', 'nacional', 'national', 'kickers', 'young', 'boys'}
RESERVE = ('next gen', 'futuro', 'atletic', 'atletico b', 'castilla', 'reserves', 'u19', 'u21', 'u23')


def core(name):
    return {t for t in tokens(name) if t not in COMMON and len(t) > 2}


def reserve_side(name):
    n = norm(name)
    return bool(YOUTH.search(n)) or n.startswith('jong ') or any(w in n for w in RESERVE) or         n in ('sevilla atletico',)


def fold(name):
    """The coach table's normalized_name: lower case without accents ("joachim low")."""
    name = unicodedata.normalize('NFKD', name.replace('ı', 'i').replace('İ', 'I'))
    return ' '.join(''.join(c for c in name if not unicodedata.combining(c)).casefold().split())


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    review = json.loads((ROOT / 'tools/fake_club/coverage.json').read_text(encoding='utf-8'))
    active = json.loads((ROOT / 'tools/fake_club/active_coverage.json').read_text(encoding='utf-8'))
    rawclubs = {r['id']: dict(r) for r in con.execute('select * from clubs')}

    # TM ids that collide with a different club keep their own id (reviewed list).
    offset_mismatch = {x['id'] for x in __import__('json').loads((__import__('pathlib').Path(__file__).resolve().parents[2] / 'tools/data_platform_v4/club_offset_mismatch.json').read_text(encoding='utf-8'))['ids']}

    def cid(i):
        return i - 1000000000 if i >= 1000000000 and i not in offset_mismatch and i - 1000000000 in rawclubs else i

    clubs = {cid(i): dict(id=cid(i), name=rawclubs[cid(i)]['name'],
        country=rawclubs[cid(i)]['country'], league=rawclubs[cid(i)]['competition'],
        badgeKey=rawclubs[cid(i)]['badge_key'], popularity=rawclubs[cid(i)]['popularity_seed'])
        for i in rawclubs if rawclubs[cid(i)]['entity_type'] == 'SENIOR'
        and rawclubs[cid(i)]['country'] and rawclubs[cid(i)]['competition']
        and rawclubs[cid(i)]['gameplay_eligible'] and '\\' not in rawclubs[cid(i)]['name']}
    # Clubs a person coached: never a fake option ("Ancelotti never played for Napoli" is true
    # but reads as a trap, he coached them). From the coach table and the reviewed tenures.
    tenures = json.loads((ROOT / 'tools/pvp/coach_tenures.json').read_text(encoding='utf-8'))['coaches']
    coached_by_name = {}
    for r in con.execute('select normalized_name, payload_json from coaches'):
        payload = json.loads(r['payload_json'] or '{}')
        ids = {cid(int(x)) for x in payload.get('clubIds') or []}
        ids |= {cid(int(t['clubId'])) for t in tenures.get(payload.get('id'), [])}
        coached_by_name.setdefault(r['normalized_name'], set()).update(ids)
    questions, careers, rejected, trust = [], [], Counter(), {}
    # Each fake club appears at most this many times in the whole catalog.
    fake_uses, FAKE_CAP = Counter(), 14
    stars = Counter()
    for pid_, club in con.execute('select player_id, club_id from player_clubs'):
        if RATING.get(pid_, 0) >= 78: stars[cid(club)] += 1
    fan = FAKE_KNOWN | {k for k, n in stars.items() if n >= 10}
    # Active players by how well known they are; legends only in the last tier.
    def tier_of(p):
        if p['coverage'] == 'REVIEWED_COMPLETE_RETIRED':
            return 'legend'
        r = RATING.get(p['playerId'], 0)
        return 'easy' if r >= EASY_RATING else 'normal' if r >= NORMAL_RATING else 'hard'
    for p in review['players'] + active['players']:
        pid = p['playerId']
        person = con.execute('select * from players where id=?', (pid,)).fetchone()
        if not person or p['coverage'] not in TRUST or not p['sources']:
            rejected['incomplete_coverage'] += 1
            continue
        source_links = {cid(r[0]) for r in con.execute('select club_id from player_clubs where player_id=? and trust>=2', (pid,))}
        real = set(map(cid, p['seniorClubIds']))
        if p['coverage'] == 'REVIEWED_COMPLETE_RETIRED':
            assert real <= source_links, f'Review not backed by V4: {pid}'
        # Exclude ALL known career associations, not just the three displayed clubs
        # or high-trust/popular/senior links; uncertainty can only remove candidates.
        excluded = real | {cid(r[0]) for r in con.execute('select club_id from player_clubs where player_id=?', (pid,))}
        excluded |= {cid(r[0]) for r in con.execute('select club_id from career_spells where player_id=?', (pid,))}
        for r in con.execute('select from_club_id,to_club_id from transfers where player_id=?', (pid,)):
            excluded.update(map(cid, r))
        coached = coached_by_name.get(fold(person['name']), set()) - real
        if coached: rejected['coached_clubs_excluded'] += len(coached)
        excluded |= coached
        # An infobox club the database does not link is never the fake (matched by name).
        unlinked = p.get('unlinkedClubNames', [])
        excluded |= {i for i, c in clubs.items() if any(same_club(c['name'], n) for n in unlinked)}
        # Never a club that shares a distinctive name with one he played for: a second
        # database row of the same club (AZ), or its reserve side (Juventus Next Gen).
        own = set().union(*(core(rawclubs[i]['name']) for i in excluded if i in rawclubs), *map(core, unlinked))
        excluded |= {i for i, c in clubs.items() if core(c['name']) & own or reserve_side(c['name'])}
        displayed = sorted(real & clubs.keys())
        if len(displayed) < 3:
            rejected['fewer_than_three_displayable_clubs'] += 1
            continue
        career = dict(playerId=pid, seniorClubIds=sorted(real), excludedClubIds=sorted(excluded),
            coverage=p['coverage'], sources=p['sources'], reviewedAt=p['reviewedAt'])
        tier = tier_of(p)
        # The duel shows easy and normal careers through clubs on the online club list
        # (two of three) and hard ones through one: a player without enough of them
        # moves down a tier, one with none is left out.
        best_known = len(set(displayed) & KNOWN)
        while tier != 'legend' and best_known < NEED_KNOWN[tier]:
            tier = {'easy': 'normal', 'normal': 'hard', 'hard': None}[tier]
            if tier is None:
                break
        if tier is None:
            rejected['active_without_known_clubs'] += 1
            continue
        career['tier'] = tier
        careers.append(career)
        # Finite offline generation: up to four distinct triples per person. Easy and
        # normal show the clubs people know them for (most known, then most popular, first).
        trios = itertools.combinations(displayed, 3)
        triples = sorted(trios, key=lambda t: (-len(set(t) & KNOWN), -sum(clubs[i]['popularity'] or 0 for i in t),
                                               digest(t)) if tier != 'legend' else digest(t))[:4]
        if tier != 'legend':
            triples = [t for t in triples if len(set(t) & KNOWN) >= NEED_KNOWN[tier]]
        for triple in triples:
            countries = {clubs[i]['country'] for i in triple}
            # A league name is only meaningful with its country ("Bundesliga").
            leagues = {(clubs[i]['country'], clubs[i]['league']) for i in triple}
            pops = [clubs[i]['popularity'] for i in triple]
            mean = sum(pops) / 3
            fake = [c for c in clubs.values() if c['id'] not in excluded and c['id'] in fan]
            # No tier gives the fake away by an odd country; easy and normal fakes are
            # on the online club lists, hard and legend ones in the same league as a real club.
            rules = {
                'easy': lambda c: c['country'] in countries and c['id'] in FAKE_KNOWN,
                'normal': lambda c: (c['country'], c['league']) in leagues and c['id'] in FAKE_KNOWN,
                'hard': lambda c: (c['country'], c['league']) in leagues,
                'legend': lambda c: (c['country'], c['league']) in leagues,
            }
            # Relax one step at a time only when fewer than two candidates remain.
            chain = {'easy': ['easy'], 'normal': ['normal', 'easy'], 'hard': ['hard', 'normal', 'easy'],
                     'legend': ['legend', 'hard', 'normal', 'easy']}
            for difficulty in [tier]:
                for step, rule in enumerate(chain[difficulty]):
                    # Hard and legend never fall back to the least known club of the four.
                    eligible = [c for c in fake if rules[rule](c) and fake_uses[c['id']] < FAKE_CAP]
                    if len(eligible) >= 2: break
                if step: rejected[f'tier_relaxed_{difficulty}'] += 1
                ordered = sorted(eligible, key=lambda c: (fake_uses[c['id']], digest([pid, triple, difficulty, c['id']])))
                for candidate in ordered[:2]:
                    fake_uses[candidate['id']] += 1
                    fid = candidate['id']
                    key = digest([pid, triple, fid, difficulty])[:24]
                    evidence = dict(coverage=p['coverage'], sources=p['sources'], reviewedAt=p['reviewedAt'])
                    trust[key] = p['coverage']
                    questions.append(dict(key=key, playerId=pid, player=dict(id=pid, name=person['name'],
                        country=person['country'], avatarKey=person['avatar_key']),
                        realClubIds=list(triple), fakeClubId=fid, difficulty=difficulty, evidence=evidence,
                        options=[clubs[i] for i in sorted([*triple, fid], key=lambda i: digest([key, i]))]))
    data = dict(schema=1, databaseSha256=hashlib.sha256(DB.read_bytes()).hexdigest(),
        reviewSha256=digest(review), activeReviewSha256=digest(active), careers=careers, questions=questions,
        quality=dict(players=len(careers), questions=len(questions), difficulties=dict(Counter(q['difficulty'] for q in questions)),
            maxFakeUses=max(fake_uses.values()), distinctFakes=len(fake_uses),
            rejected=dict(rejected), tiers=dict(Counter(c['tier'] for c in careers)),
            policy='legends_last_active_by_fame'))
    data['version'] = 'fc-v1-' + digest(data)[:16]
    for q in questions:
        q['questionId'] = data['version'] + '-' + q.pop('key')
        q['dataVersion'] = data['version']
        q['trust'] = trust[q['questionId'].rsplit('-', 1)[1]]
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
        OUT.write_text(encoded, encoding='utf-8', newline='\n')
    print(json.dumps(data['quality'], ensure_ascii=False))
