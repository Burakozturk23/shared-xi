"""Compile reviewed V4 identities and 90 immutable daily / 14 weekly packs.
No runtime randomness, inferred aliases, live team claims or unreviewed fallback.
"""
import argparse
from collections import Counter, defaultdict
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
DAYS = 90


def normalize(s):
    s = s.translate(str.maketrans({'ı': 'i', 'İ': 'I', 'ø': 'o', 'Ø': 'O', 'ł': 'l', 'Ł': 'L',
        'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'đ': 'd', 'Đ': 'D'}))
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
    questions = read('passaparola.json')['questions']
    assert len({q['id'] for q in questions}) == len(questions)
    for q in questions:
        assert q['letter'] in ALPHABET and q['revision'] >= 1 and q['proof'] and q['prompt']
        assert q['rule'] == ('contains' if q['letter'] == 'Ğ' else 'start_with')
        assert normalize(q['answer']) in q['acceptedAnswers']
        for a in q['acceptedAnswers']:
            assert a == normalize(a)
            assert normalize(q['letter']) in a if q['rule'] == 'contains' else a.startswith(normalize(q['letter']))
        if q['rule'] == 'contains':
            assert 'ğ' in q['answer'].lower()
        if q['proof']['kind'] == 'v4_identity':
            p = people[q['proof']['playerId']]
            assert p['country'] == q['proof']['country']
            if q['category'] == 'player':
                assert p['name'] == q['proof']['name']
    assert min(Counter(q['letter'] for q in questions).values()) >= 6
    assert set(q['letter'] for q in questions) == set(ALPHABET)
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
        if 4 <= len(token) <= 9:
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
    lingo_used = set()
    anagram_groups = {t: sorted([p for p in players if p['difficulty'] == t], key=lambda p: sha(['an',p['id']])) for t in [1,2,3]}
    for t,(lo,hi) in enumerate([(4,6),(6,8),(7,10)],1):
        assert len(anagram_groups[t]) >= DAYS
        assert all(lo <= len(p['answer']) <= hi for p in anagram_groups[t])
    daily, weekly = {}, {}
    last_used = defaultdict(lambda: -10000)
    def pack(letters, tiers, offset):
        result = []
        for letter,tier in zip(letters,tiers):
            choices = [q for q in questions if q['letter']==letter and q['difficulty']==tier]
            q = min(choices,key=lambda q:(last_used[q['id']],sha([offset,q['id']])))
            result.append(q['id']);last_used[q['id']] = offset
        return result
    monday = START-timedelta(days=START.weekday())
    for offset in range(-START.weekday(),DAYS):
        day = START + timedelta(days=offset); key = day.isoformat()
        if day.weekday()==0 or day==monday:
            n=(day-monday).days//7; letters=ALPHABET[n%29:]+ALPHABET[:n%29]
            chosen=pack(letters,[1]*10+[2]*13+[3]*6,offset)
            weekly[key]=dict(questionIds=chosen)
        if offset<0:continue
        category=['player','club','country','player','club','country','player'][day.weekday()]
        tier=[1,2,1,2,3,1,2][day.weekday()]
        lo,hi={1:(4,6),2:(6,8),3:(7,9)}[tier]
        candidates=[q for q in lingo if q['category']==category and q['id'] not in lingo_used and lo<=len(q['answer'])<=hi]
        assert candidates, ('Insufficient reviewed Lingo vocabulary',key,category,tier)
        q=min(candidates,key=lambda q:sha([key,q['id']]))
        lingo_used.add(q['id'])
        a=[anagram_groups[t][offset] for t in [1,2,3]]
        letters=[ALPHABET[(offset*7+i)%29] for i in range(7)]
        daily[key]=dict(lingoId=q['id'], lingoDifficulty=tier,
            anagram=[dict(playerId=p['id'], scrambled=mix(p['answer'],key+'|'+str(p['id']))) for p in a],
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
