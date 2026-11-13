"""Compile reviewed V4 identities and 180 immutable daily / weekly packs.
No runtime randomness, inferred aliases, live team claims or unreviewed fallback.

Packs listed in frozen_packs.json (every day and week up to 12 November 2026, the ones a player may
already have seen) are replayed verbatim and are never regenerated; only later dates are derived, so
extending the calendar can never rewrite a pack a player may already have seen. (The server also pins
a pack the first time anyone opens it.)

From 13 November 2026 packs follow the gameplay rating of the online modes:
- Passaparola asks clue questions only (generate_passaparola_clues.py: nationality, position, birth
  year and longest clubs, then the surname), never the same player twice in a pack, and the player
  least recently asked first. The older "Adının devamı 'Kimmich' …" questions stay only for the
  frozen packs.
- Anagram rounds: easy the most famous 4-6 letter names, hard the least known 7-10 letter ones,
  normal 6-8 from the rest (nobody twice in the calendar); the round's level is stored in the pack.
- Lingo player targets: rating 76+; country targets: football nations (two or more players 75+) until they run out. No target twice.
"""
import argparse
from collections import Counter, defaultdict
import gzip
from datetime import date, timedelta
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
OUT = ROOT / 'functions/config/daily_words_catalog.json'
ALPHABET = list('ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ')
START = date(2026, 10, 17)
DAYS = 180


def normalize(s):
    s = s.translate(str.maketrans({'ı': 'i', 'İ': 'I', 'ø': 'o', 'Ø': 'O', 'ł': 'l', 'Ł': 'L',
        'ß': 'ss', 'ẞ': 'SS', 'æ': 'ae', 'Æ': 'AE', 'œ': 'oe', 'Œ': 'OE',
        'đ': 'd', 'Đ': 'D', 'ð': 'd', 'Ð': 'D'}))
    return re.sub('[^A-Z]', '', unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().upper())


def sha(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def read(name):
    return json.loads((HERE / name).read_text())


def mix(answer, seed):
    chars = [c for _, c in sorted(enumerate(answer), key=lambda p: sha([seed, p[0]]))]
    result = ''.join(chars)
    if result == answer:
        for n in range(1, len(answer)):
            result = answer[n:] + answer[:n]
            if result != answer:
                break
    assert result != answer and Counter(result) == Counter(answer)
    return result


def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    people = {r['id']: dict(r) for r in con.execute('select * from players')}
    countries = read('countries.json')
    names = {c['key']: c['name'] for c in countries}
    players = []
    for entry in read('players.json')['players']:
        p = people[entry['id']]
        assert p['name'] == entry['name'] and p['country'] and p['position']
        token = normalize(entry['answer'])
        assert 4 <= len(token) <= 10 and len(set(token)) > 1
        aliases = sorted(set([token, normalize(p['name'])]))
        # Canonical token and full display name only: no automatic last-word alias.
        players.append(dict(id=p['id'], name=p['name'], answer=token, aliases=aliases,
            country=p['country'], countryLabel=names.get(p['country'], p['country']), position=p['position'],
            difficulty=entry['difficulty'], quality='V4_IDENTITY_REVIEWED',
            proof=dict(table='players', id=p['id'], source=p['source'], reviewedAt='2026-10-17')))
    assert len(players) >= 270 and len({p['id'] for p in players}) == len(players)
    assert len({p['answer'] for p in players}) == len(players)
    # Whole V4 surname/mononym collision audit, with the reviewed legacy choices.
    old = read('practice_legacy.json')
    overrides = {p['id']: p['answer'] for p in old}
    collisions = defaultdict(set)
    for p in people.values():
        if p['id'] >= 1000000000 and p['id'] - 1000000000 in people:
            continue
        parts = p['name'].split()
        candidate = ''.join(parts[-2:]) if len(parts) > 1 and parts[-2].lower() in ['de','van','di','ben','el','ter'] else parts[-1]
        collisions[normalize(overrides.get(p['id'], candidate))].add(p['id'])
    for p in players:
        assert collisions[p['answer']] == {p['id']}, (p['name'], collisions[p['answer']])
    clues = read('passaparola_clues.json')['questions']
    questions = read('passaparola.json')['questions'] + read('passaparola_generated.json')['questions'] + clues
    assert len({q['id'] for q in questions}) == len(questions)
    clue_ids = {q['id'] for q in clues}
    for q in questions:
        assert q['letter'] in ALPHABET and q['revision'] >= 1 and q['proof'] and q['prompt']
        # Clue questions also ask Ş inside a name (Yokuşlu), as few names start with it.
        assert q['rule'] == ('contains' if q['letter'] == 'Ğ' else 'start_with') or \
            q['id'] in clue_ids and q['letter'] == 'Ş' and q['rule'] == 'contains'

        assert normalize(q['answer']) in q['acceptedAnswers']
        for a in q['acceptedAnswers']:
            assert a == normalize(a)
            assert normalize(q['letter']) in a if q['rule'] == 'contains' else a.startswith(normalize(q['letter']))
        if q['rule'] == 'contains':
            assert q['letter'].lower() in q['answer'].lower()
        if q['proof']['kind'] == 'v4_identity':
            p = people[q['proof']['playerId']]
            assert p['country'] == q['proof']['country']
            if q['category'] == 'player':
                assert p['name'] == q['proof']['name']
    assert min(Counter(q['letter'] for q in questions).values()) >= 6
    # Every (letter, tier) slot a new pack can request must have a clue question.
    assert all(any(q['letter'] == l and q['difficulty'] == t for q in clues) for l in ALPHABET for t in (1, 2, 3))
    assert set(q['letter'] for q in questions) == set(ALPHABET)
    rating = {int(k): v['rating'] for k, v in json.loads(gzip.decompress(
        (ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))['players'].items()}
    # A Lingo country is a football nation: two or more players rated 75+ (no Laos).
    football_nations = Counter(r['country'] for r in con.execute('select id, country from players')
                               if rating.get(r['id'], 0) >= 75)
    lingo = []
    for p in players:
        if len(p['answer']) <= 9:
            lingo.append(dict(id=f'lp-{p["id"]}', category='player', answer=p['answer'], display=p['name'],
                hint=f"Ülke: {p['countryLabel']}", proof=p['proof']))
    for entry in read('clubs.json'):
        c = dict(con.execute('select * from clubs where id=?', (entry['id'],)).fetchone())
        assert c['name'] == entry['name'] and c['entity_type'] == 'SENIOR' and c['country']
        lingo.append(dict(id=f'lc-{c["id"]}', category='club', answer=entry['answer'], display=c['name'],
            hint=f"Ülke: {names.get(c['country'], c['country'])}", proof=dict(table='clubs', id=c['id'])))
    for c in countries:
        token = normalize(c['name'])
        if c.get('lingo', True) and 4 <= len(token) <= 9:
            lingo.append(dict(id='ln-' + normalize(c['key']), category='country', answer=token,
                display=c['name'], hint='Kıta: ' + c['continent'], proof=dict(kind='country_name_review', key=c['key'])))
    # Do not publish a target token shared by distinct entities in its category.
    counts = Counter((q['category'], q['answer']) for q in lingo)
    lingo = [q for q in lingo if counts[q['category'], q['answer']] == 1]
    # A dictionary may contain ambiguous legitimate guesses; targets may not.
    dictionaries = {cat: sorted({q['answer'] for q in lingo if q['category'] == cat}) for cat in ['player','club','country']}
    for p in people.values():
        for candidate in [p['name'].split()[-1], p['name']]:
            token = normalize(candidate)
            if 4 <= len(token) <= 9:
                dictionaries['player'].append(token)
    dictionaries = {k: sorted(set(v)) for k,v in dictionaries.items()}
    # Vocabulary is part of the pinned package, so a later release cannot reject yesterday's legal guess.
    lingo_used = {}  # target id -> day offset it was last asked
    frozen = read('frozen_packs.json')
    frozen_players = {a['playerId'] for d in frozen['daily'].values() for a in d['anagram']}
    # Anagram levels: the reviewed players' word-length groups fill the calendar exactly,
    # so levels start from them and then trade players: a better-known player moves to
    # the easier level when both words fit the other level's length (easy 4-6, normal
    # 6-8, hard 7-10). Easy ends with the most famous names it can hold, hard with the
    # least known. Nobody appears twice in the calendar.
    windows = {1: (4, 6), 2: (6, 8), 3: (7, 10)}
    fits = lambda p, t: windows[t][0] <= len(p['answer']) <= windows[t][1]
    level = {p['id']: p['difficulty'] for p in players if p['id'] not in frozen_players}
    by_id = {p['id']: p for p in players}
    r_of = lambda i: rating.get(i, 0)
    changed = True
    while changed:
        changed = False
        for easier, harder in [(1, 2), (2, 3), (1, 3)]:
            low = sorted((i for i, t in level.items() if t == easier), key=lambda i: (r_of(i), i))
            high = sorted((i for i, t in level.items() if t == harder), key=lambda i: (-r_of(i), i))
            for a in low:
                b = next((b for b in high if r_of(b) > r_of(a) and level[b] == harder and
                          fits(by_id[b], easier) and fits(by_id[a], harder)), None)
                if b is not None:
                    level[a], level[b] = harder, easier; changed = True; break
    anagram_groups = {t: sorted([by_id[i] for i, l in level.items() if l == t], key=lambda p: sha(['an', p['id']]))
                      for t in [1, 2, 3]}
    fresh_days = DAYS - len(frozen['daily'])
    for t in [1, 2, 3]:
        assert len(anagram_groups[t]) >= fresh_days and all(fits(p, t) for p in anagram_groups[t])
    assert frozen_players <= {p['id'] for p in players}
    assert {d['lingoId'] for d in frozen['daily'].values()} <= {q['id'] for q in lingo}
    assert all(i in {q['id'] for q in questions} for d in frozen['daily'].values() for i in d['passaIds'])
    assert all(i in {q['id'] for q in questions} for w in frozen['weekly'].values() for i in w['questionIds'])
    fresh_index = 0
    daily, weekly = {}, {}
    last_used = defaultdict(lambda: -10000)
    player_used = defaultdict(lambda: -10000)
    by_id = {q['id']: q for q in questions}
    who = lambda q: q['proof'].get('playerId') or q['id']
    def remember(ids, offset):
        for i in ids:
            last_used[i] = offset; player_used[who(by_id[i])] = offset
    def pack(letters, tiers, offset):
        # Clue questions only; one player once per pack; the least recently asked
        # question and player first.
        result, players_in = [], set()
        for letter,tier in zip(letters,tiers):
            choices = [q for q in clues if q['letter']==letter and q['difficulty']==tier and who(q) not in players_in]
            if not choices:
                choices = [q for q in clues if q['letter']==letter and who(q) not in players_in]
            q = min(choices,key=lambda q:(last_used[q['id']],player_used[who(q)],sha([offset,q['id']])))
            result.append(q['id']); players_in.add(who(q)); remember([q['id']], offset)
        return result
    monday = START-timedelta(days=START.weekday())
    for offset in range(-START.weekday(),DAYS):
        day = START + timedelta(days=offset); key = day.isoformat()
        if day.weekday()==0 or day==monday:
            n=(day-monday).days//7; letters=ALPHABET[n%29:]+ALPHABET[:n%29]
            if key in frozen['weekly']:
                chosen=frozen['weekly'][key]['questionIds']
                remember(chosen, offset)
            else:
                chosen=pack(letters,[1]*10+[2]*13+[3]*6,offset)
            weekly[key]=dict(questionIds=chosen)
        if offset<0:continue
        if key in frozen['daily']:
            daily[key]=frozen['daily'][key]
            lingo_used[daily[key]['lingoId']] = offset
            remember(daily[key]['passaIds'], offset)
            continue
        category=['player','club','country','player','club','country','player'][day.weekday()]
        tier=[1,2,1,2,3,1,2][day.weekday()]
        lo,hi={1:(4,6),2:(6,8),3:(7,9)}[tier]
        unused=[q for q in lingo if q['category']==category and q['id'] not in lingo_used]
        fresh=[q for q in unused if lo<=len(q['answer'])<=hi]
        known=lambda q: (category != 'player' or rating.get(q['proof']['id'], 0) >= 76) and             (category != 'country' or football_nations[q['proof']['key']] >= 2)
        # Known players and football nations first, at the day's length, then at any
        # length; the rest only once those run out.
        candidates=[q for q in fresh if known(q)] or [q for q in unused if known(q)] or fresh
        assert candidates, ('Insufficient reviewed Lingo vocabulary',key,category,tier)
        q=min(candidates,key=lambda q:sha([key,q['id']]))
        lingo_used[q['id']] = offset
        a=[anagram_groups[t][fresh_index] for t in [1,2,3]]; fresh_index+=1
        letters=[ALPHABET[(offset*7+i)%29] for i in range(7)]
        daily[key]=dict(lingoId=q['id'], lingoDifficulty=tier,
            anagram=[dict(playerId=p['id'], difficulty=t, scrambled=mix(p['answer'],key+'|'+str(p['id'])))
                     for t, p in zip([1, 2, 3], a)],
            passaIds=pack(letters,[1,1,1,2,2,2,3],offset))
    data=dict(schema=1, starts=START.isoformat(), ends=(START+timedelta(days=DAYS-1)).isoformat(),
        databaseSha256=hashlib.sha256(DB.read_bytes()).hexdigest(), alphabet=ALPHABET, players=players,
        lingo=lingo, dictionaries=dictionaries, questions=questions, daily=daily, weekly=weekly)
    data['version']='dw-v1-'+sha(data)[:16]
    # Keep all 64 old entries byte-equivalent in meaning: unfinished practice decks keep working.
    practice=list(old); ids={p['id'] for p in old}; words={p['answer'] for p in old}
    for p in players:
        if p['id'] not in ids and p['answer'] not in words:
            practice.append({k:p[k] for k in ['id','name','answer','country','position','aliases']})
            ids.add(p['id']);words.add(p['answer'])
    return data,practice


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data,practice=build()
    for path,value in [(OUT,data),(ROOT/'assets/data/anagram_catalog.json',practice)]:
        text=json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n'
        if args.check:
            assert path.read_text()==text, f'Catalog drift: {path}'
        else:
            path.write_text(text)
    print(json.dumps(dict(version=data['version'],players=len(data['players']),questions=len(data['questions']),
        daily=len(data['daily']),weekly=len(data['weekly']),practice=len(practice)),ensure_ascii=False))
