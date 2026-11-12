"""Passaparola clue questions: describe a known player, ask for his surname.

The older families ("Adının devamı 'Kimmich' olan futbolcunun tam adı?", "'Joshua …'
adlı futbolcunun eksik isim parçası?") gave half the answer away. A clue question
names what a fan knows instead: nationality, position, birth year and the clubs he
spent most time at. "K · Alman orta saha (1995). En uzun süre oynadığı kulüpler:
Bayern Munich, RB Leipzig. Soyadı?" -> KIMMICH. The full name is accepted too.
Letters few surnames start with (Ş, İ, Ü ...) also ask for the given name, which
Turkish names often start with: "Ş · ... Adı?" -> ŞENOL.

A clue is kept only when no other player of the database with that nationality,
position and initial played for all the named clubs. Levels follow the online
modes' gameplay rating (tools/pvp/build_catalog.py): 82+ easy, 76+ normal, 70+
hard; Turkish players count six points higher, since the game is played in Türkiye.
Letters with few famous holders (Ç Ğ İ Ö Ş Ü) reach down to 62 and are split into
thirds by rating.

Output: tools/daily_words/passaparola_clues.json. Run with --check in CI.
"""
import argparse
from collections import Counter, defaultdict
from datetime import date
import gzip
import json
from pathlib import Path
import sqlite3
import sys

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from build_catalog import ALPHABET, DB, ROOT, normalize, read  # noqa: E402
from generate_passaparola import POSITION, SCARCE, letter_of, split_name  # noqa: E402

OUT = HERE / 'passaparola_clues.json'
REVIEWED_AT = '2026-11-12'
PER_TIER = 20
TURKISH = {'Türkiye', 'Turkey'}
NATIONAL = {'İngiltere': 'İngiliz', 'Fransa': 'Fransız', 'Almanya': 'Alman', 'İspanya': 'İspanyol',
            'İtalya': 'İtalyan', 'Portekiz': 'Portekizli', 'Hollanda': 'Hollandalı', 'Belçika': 'Belçikalı',
            'Brezilya': 'Brezilyalı', 'Arjantin': 'Arjantinli', 'Türkiye': 'Türk'}


def nationality(label):
    return NATIONAL.get(label, label + ' milli takımından')


def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    labels = {c['key']: c['name'] for c in read('countries.json')}
    mismatch = {x['id'] for x in json.loads((ROOT / 'tools/data_platform_v4/club_offset_mismatch.json')
                                           .read_text(encoding='utf-8'))['ids']}
    clubs = {r['id']: dict(r) for r in con.execute('select * from clubs')}

    def cid(i):
        return i - 1000000000 if i >= 1000000000 and i not in mismatch and i - 1000000000 in clubs else i
    rating = {int(k): v['rating'] for k, v in json.loads(gzip.decompress(
        (ROOT / 'functions/config/pvp_catalog.json.gz').read_bytes()))['players'].items()}
    born = {r['player_id']: r['birth_year'] for r in con.execute('select player_id, birth_year from profiles')}
    # Days at each senior club (an open spell counts at most a year: open ends are often stale).
    stays = defaultdict(Counter)
    for r in con.execute('select player_id, club_id, start_date, end_date from career_spells '
                         'where start_date is not null'):
        k = cid(r['club_id']); c = clubs.get(k)
        if not c or c['entity_type'] != 'SENIOR' or not c['gameplay_eligible']:
            continue
        try:
            start = date.fromisoformat(r['start_date'][:10])
            days = (date.fromisoformat(r['end_date'][:10]) - start).days if r['end_date'] else \
                min(365, (date(2026, 11, 1) - start).days)
        except ValueError:
            continue
        stays[r['player_id']][k] += max(0, days)
    played = defaultdict(set)
    for r in con.execute('select player_id, club_id from player_clubs'):
        played[r['player_id']].add(cid(r['club_id']))
    people = [dict(r) for r in con.execute('select * from players')
              if r['id'] < 1000000000 and r['name'] and r['position'] in POSITION]
    # Who could a clue also describe: same nationality, position and initial.
    rivals = defaultdict(list)
    for p in people:
        parts = split_name(p['name'])
        for part, kind in zip(parts or (), ('given', 'family')):
            if letter_of(part):
                rivals[(kind, p['country'], p['position'], letter_of(part))].append(p['id'])
            for inner in ('ğ', 'ş'):  # "contains" letters: anyone with it anywhere in that part
                if inner in part.lower():
                    rivals[(kind, p['country'], p['position'], 'in:' + inner)].append(p['id'])
    candidates = []
    for p in people:
        turkish = p['country'] in TURKISH
        score = rating.get(p['id'], 0) + (6 if turkish else 0)
        if score < 62 or not (p['answer_eligible'] and p['playable']) or p['country'] not in labels:
            continue
        parts = split_name(p['name'])
        if not parts:
            continue
        top = [k for k, _ in sorted(stays[p['id']].items(), key=lambda kv: (-kv[1], kv[0]))[:3]
               if stays[p['id']][k] >= 180]
        if len(top) < 2:
            continue
        label = labels[p['country']]
        year = born.get(p['id'])
        who = f"{nationality(label)} {POSITION[p['position']].lower()}" + (f" ({year})" if year else '')
        who = who[0].upper() + who[1:]
        def clue(kind, part, letter, rule):
            named = top[:2]
            key = 'in:' + letter.lower() if rule == 'contains' else letter_of(part)
            others = [i for i in rivals[(kind, p['country'], p['position'], key)] if i != p['id']]
            if any(set(named) <= played[i] for i in others):
                named = top
                if len(named) < 3 or any(set(named) <= played[i] for i in others):
                    return
            where = ', '.join(clubs[k]['name'].strip() for k in named)
            ask = 'Soyadı?' if kind == 'family' else 'Adı?'
            lead = f"İçinde {letter} geçen {'soyadı' if kind == 'family' else 'ad'}. " if rule == 'contains' else ''
            prompt = f"{lead}{who}. En uzun süre oynadığı kulüpler: {where}. {ask}"
            candidates.append((score, kind, p, letter, part, prompt, rule))

        for kind, part in zip(('given', 'family'), parts):
            # Ğ is asked inside a name; Ş too when it is not the first letter (Yokuşlu,
            # Barış), as few names start with it.
            options = [('Ğ', 'contains')] if 'ğ' in part.lower() else [(letter_of(part), 'start_with')]
            if 'ş' in part[1:].lower():
                options.append(('Ş', 'contains'))
            for letter, rule in options:
                if letter and score >= (62 if letter in SCARCE else 70):
                    clue(kind, part, letter, rule)
    # Surnames first; a given name only fills a (letter, level) that surnames leave short.
    candidates.sort(key=lambda c: (c[1] != 'family', -c[0], c[2]['id']))
    count, chosen, asked = Counter(), [], set()
    for score, kind, p, letter, part, prompt, rule in candidates:
        tier = 0 if letter in SCARCE else 1 if score >= 82 else 2 if score >= 76 else 3
        cap = 3 * PER_TIER if tier == 0 else PER_TIER
        if p['id'] in asked or count[letter, tier] >= (cap if kind == 'family' else min(cap, 4)):
            continue
        asked.add(p['id']); count[letter, tier] += 1
        chosen.append(dict(id=f"pa-c{p['id']}", revision=1, letter=letter,
            rule=rule, category='player', prompt=prompt, answer=part,
            # The full name too when it obeys the letter rule, as the server checks the rule first.
            acceptedAnswers=sorted(a for a in {normalize(part), normalize(p['name'])}
                                   if (normalize(letter) in a if rule == 'contains' else a.startswith(normalize(letter)))),
            difficulty=tier,
            proof=dict(kind='v4_identity', playerId=p['id'], name=p['name'], country=p['country'],
                       source=p['source'], reviewedAt=REVIEWED_AT),
            explanation=f"{p['name']}. Bu soruda istenen cevap: {part}."))
    seen, size = Counter(), Counter(q['letter'] for q in chosen if q['difficulty'] == 0)
    for q in chosen:  # best-known first: thirds by rating inside a scarce letter
        if q['difficulty'] == 0:
            q['difficulty'] = 1 + seen[q['letter']] * 3 // size[q['letter']]
            seen[q['letter']] += 1
    order = {l: i for i, l in enumerate(ALPHABET)}
    chosen.sort(key=lambda q: (order[q['letter']], q['difficulty'], q['id']))
    return dict(reviewedAt=REVIEWED_AT, generator='tools/daily_words/generate_passaparola_clues.py',
                questions=chosen)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    text = json.dumps(data, ensure_ascii=False, indent=1) + '\n'
    if args.check:
        assert OUT.read_text(encoding='utf-8') == text, f'Passaparola clue drift: {OUT}'
    else:
        OUT.write_text(text, encoding='utf-8', newline='\n')
    c = Counter((q['letter'], q['difficulty']) for q in data['questions'])
    print(len(data['questions']), 'clue questions')
    print({l: [c[l, t] for t in (1, 2, 3)] for l in ALPHABET})
