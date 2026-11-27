"""Deterministic Passaparola question generator (V4 identities only).

Reads the bundled V4 SQLite file and emits tools/daily_words/passaparola_generated.json.
Two question families, both answerable from the V4 canonical identity row alone:
  A  full name  -> "Ülke: X. Mevki: Y. Adının devamı 'Soyad' olan futbolcunun tam adı?"
  B  name part  -> "Ülke: X. Mevki: Y. 'Ad …' adlı futbolcunun eksik isim parçası?"
A prompt is emitted only when no other V4 player shares its (country, position, visible part).
No runtime randomness; output is a pure function of the database and countries.json.
Run with --check in CI to prove the committed file is not stale.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import sqlite3
import sys

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from build_catalog import ALPHABET, DB, normalize, read  # noqa: E402

OUT = HERE / 'passaparola_generated.json'
REVIEWED_AT = '2026-10-29'
POSITION = {'Attack': 'Forvet', 'Midfield': 'Orta saha', 'Defender': 'Defans', 'Goalkeeper': 'Kaleci'}
PARTICLES = {'de', 'van', 'di', 'ben', 'el', 'ter', 'dos', 'da', 'von', 'le', 'la', 'del'}
SUFFIXES = {'junior', 'jr', 'jr.', 'filho', 'neto', 'sr', 'sr.', 'ii', 'iii', 'senior'}
TURKISH_KEYS = {'Türkiye', 'Turkey'}
PER_TIER = 14          # questions kept per (letter, difficulty)
MIN_VALUE = 3_000_000  # peak market value floor (EUR); Turkish players use a lower floor
TURKISH_MIN_VALUE = 700_000
# Letters with few famous holders: lower value floor, and tiers by rank inside the letter.
SCARCE = set('ÇĞİÖŞÜ')
SCARCE_MIN_VALUE = 1_000_000
SCARCE_TURKISH_MIN_VALUE = 150_000


def letter_of(text):
    first = text[0]
    if first in 'ÇĞŞÖÜİ':
        return first
    if first in 'ıI':
        return 'I'
    token = normalize(first)
    return token if token in ALPHABET else None


def split_name(name):
    parts = name.split()
    if len(parts) < 2:
        return None
    cut = 2 if len(parts) > 2 and parts[-2].lower() in PARTICLES else 1
    given, family = ' '.join(parts[:-cut]), ' '.join(parts[-cut:])
    if not given or family.lower() in SUFFIXES or len(normalize(family)) < 3:
        return None
    return given, family


def tier_for(value, turkish):
    if value >= 40_000_000 or (turkish and value >= 12_000_000):
        return 1
    if value >= 15_000_000 or (turkish and value >= 4_000_000):
        return 2
    return 3


def build():
    con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    people = [dict(r) for r in con.execute('select * from players')]
    people = [p for p in people if p['id'] < 1000000000 and p['name'] and p['position'] in POSITION]
    labels = {c['key']: c['name'] for c in read('countries.json')}
    used = {q['proof']['playerId'] for q in read('passaparola.json')['questions'] if q['proof'].get('playerId')}
    family_of = defaultdict(set)   # (country label, position, surname token) -> ids
    given_of = defaultdict(set)    # (country label, position, given-name token) -> ids
    for p in people:
        parts = split_name(p['name'])
        if not parts:
            continue
        label = labels.get(p['country'], p['country'])
        family_of[(label, p['position'], normalize(parts[1]))].add(p['id'])
        given_of[(label, p['position'], normalize(parts[0]))].add(p['id'])
    candidates = []
    for p in people:
        turkish = p['country'] in TURKISH_KEYS
        value = p['peak_market_value'] or 0
        if not (p['answer_eligible'] and p['playable']) or p['id'] in used or p['country'] not in labels:
            continue
        if value < min(TURKISH_MIN_VALUE if turkish else MIN_VALUE, SCARCE_TURKISH_MIN_VALUE if turkish else SCARCE_MIN_VALUE):
            continue
        parts = split_name(p['name'])
        if not parts:
            continue
        given, family = parts
        label = labels[p['country']]
        pos = POSITION[p['position']]
        if family_of[(label, p['position'], normalize(family))] == {p['id']}:
            letter = letter_of(p['name'])
            if letter and letter != 'Ğ':
                candidates.append((value, p['id'], 'A', letter, p, label, pos, given, family, turkish))
        if given_of[(label, p['position'], normalize(given))] == {p['id']}:
            letter = letter_of(family)
            if letter and letter != 'Ğ':
                candidates.append((value, p['id'], 'B', letter, p, label, pos, given, family, turkish))
        # Ğ appears inside names; ask for the part that contains it (contains-rule).
        for fam, text in (('A', p['name']), ('B', family)):
            if 'ğ' in text.lower() and (fam == 'A' and family_of[(label, p['position'], normalize(family))] == {p['id']}
                    or fam == 'B' and given_of[(label, p['position'], normalize(given))] == {p['id']}):
                candidates.append((value, p['id'], fam, 'Ğ', p, label, pos, given, family, turkish))
    # Greedy, best-known first: one family per player, ≤ PER_TIER per (letter, tier).
    candidates.sort(key=lambda c: (-c[0], c[1], c[2]))
    taken, count, chosen = set(), Counter(), []
    for value, pid, fam, letter, p, label, pos, given, family, turkish in candidates:
        scarce = letter in SCARCE
        if value < ((SCARCE_TURKISH_MIN_VALUE if turkish else SCARCE_MIN_VALUE) if scarce
                    else (TURKISH_MIN_VALUE if turkish else MIN_VALUE)):
            continue
        tier = tier_for(value, turkish)
        if scarce:
            tier = 0  # assigned by rank below
            if pid in taken or count[letter, 0] >= 3 * PER_TIER:
                continue
        elif pid in taken or count[letter, tier] >= PER_TIER:
            continue
        taken.add(pid)
        count[letter, tier] += 1
        if fam == 'A':
            prompt = f"Ülke: {label}. Mevki: {pos}. Adının devamı '{family}' olan futbolcunun tam adı?"
            answer = p['name']
        else:
            prompt = f"Ülke: {label}. Mevki: {pos}. '{given} …' adlı futbolcunun eksik isim parçası?"
            answer = family
        chosen.append(dict(id=f"pa-g{pid}-{fam}", revision=1, letter=letter,
            rule='contains' if letter == 'Ğ' else 'start_with', category='player', prompt=prompt, answer=answer,
            acceptedAnswers=[normalize(answer)], difficulty=tier,
            proof=dict(kind='v4_identity', playerId=pid, name=p['name'], country=p['country'], source=p['source'],
                reviewedAt=REVIEWED_AT),
            explanation=f"{p['name']} · {label}. Bu soruda istenen cevap: {answer}."))
    seen, size = Counter(), Counter(q['letter'] for q in chosen)
    for q in chosen:  # chosen is already best-known first: thirds by rank inside the letter
        if q['letter'] in SCARCE:
            q['difficulty'] = 1 + seen[q['letter']] * 3 // size[q['letter']]
            seen[q['letter']] += 1
    order = {l: i for i, l in enumerate(ALPHABET)}
    chosen.sort(key=lambda q: (order[q['letter']], q['difficulty'], q['id']))
    return dict(reviewedAt=REVIEWED_AT, generator='tools/daily_words/generate_passaparola.py', questions=chosen)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    text = json.dumps(data, ensure_ascii=False, indent=1) + '\n'
    if args.check:
        assert OUT.read_text() == text, f'Generated Passaparola drift: {OUT}'
    else:
        OUT.write_text(text)
    c = Counter((q['letter'], q['difficulty']) for q in data['questions'])
    print(len(data['questions']), 'questions; min per letter',
          min(sum(c[l, t] for t in (1, 2, 3)) for l in ALPHABET))
    print({l: [c[l, t] for t in (1, 2, 3)] for l in ALPHABET})
