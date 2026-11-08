"""Grid teknik direktör kriteri: 50 coaches' club tenures from Wikidata, once.

Reads tools/pvp/coach_pool.json, looks up missing Wikidata ids by name, fetches each
coach's club tenures (P6087 "coach of sports team" on the person, and P286 "head
coach" on the club) with start/end qualifiers, maps clubs to database club ids and
writes tools/pvp/coach_tenures.json plus a report of everything dropped.
Spec: docs/superpowers/specs/2026-11-08-grid-teknik-direktor-design.md

Run: py -3 tools/pvp/fetch_coach_tenures.py
"""
import json
import os
import re
import sqlite3
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(__file__)
ROOT = os.path.dirname(os.path.dirname(HERE))
DB = os.path.join(ROOT, 'assets', 'runtime', 'linkball_game_data_v4.sqlite')
POOL = os.path.join(HERE, 'coach_pool.json')
ALIASES = os.path.join(HERE, 'coach_club_aliases.json')
MANUAL = os.path.join(HERE, 'coach_tenures_manual.json')
OUT = os.path.join(HERE, 'coach_tenures.json')
REPORT = os.path.join(HERE, 'coach_tenures_report.md')
UA = 'LinkballDataTool/1.0 (https://github.com/Burakozturk23/shared-xi; one-off coach tenure import)'
AFFIXES = {'fc', 'sk', 'jk', 'cf', 'ac', 'afc', 'sc', 'cd', 'fk', 'sl', 'as', 'ssc', 'sv', 'vfb', 'vfl', 'rc', 'ca',
           'se', 'the', 'club', 'calcio', 'acf', 'sad', 'futbol', 'kulubu', 'spor', 'bk', 'if', 'us', 'ss', 'afc',
           # Long Portuguese/Spanish/Italian forms ("Clube de Regatas do Flamengo" ~ "CR Flamengo").
           'clube', 'de', 'do', 'da', 'del', 'della', 'di', 'cr', 'regatas'}
COUNTRY = {'turkey': 'turkiye', 'unitedkingdom': {'england', 'scotland', 'wales', 'northernireland'},
           'unitedstatesofamerica': 'unitedstates', 'peoplesrepublicofchina': 'china', 'kingdomofthenetherlands':
           'netherlands', 'netherlands': 'netherlands'}


def fold(s):
    s = str(s or '').replace('ı', 'i').replace('İ', 'I')
    return unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()


def norm(s):
    return re.sub(r'[^a-z0-9]', '', fold(s))


def club_key(s):
    # "S.L. Benfica" → "sl benfica": dotted abbreviations are one word, then dropped as an affix.
    words = [w for w in re.split(r'[^a-z0-9]+', fold(s).replace('.', '')) if w and w not in AFFIXES]
    return ''.join(words)


def same_country(wikidata, db):
    a, b = norm(wikidata), norm(db)
    if not a or not b:
        return False
    want = COUNTRY.get(a, a)
    return b in want if isinstance(want, set) else b == want


def day(value):
    return value[:10] if value else None


def parse_tenures(sparql):
    """SPARQL JSON → [{qid, label, country, start, end}] (dates as YYYY-MM-DD or None)."""
    rows = []
    for b in sparql['results']['bindings']:
        rows.append({'qid': b['club']['value'].rsplit('/', 1)[-1], 'label': b.get('clubLabel', {}).get('value', ''),
                     'country': b.get('countryLabel', {}).get('value', ''),
                     'start': day(b.get('start', {}).get('value')), 'end': day(b.get('end', {}).get('value'))})
    return rows


# Season items, youth/reserve sides and federations are not the senior club.
NOT_SENIOR = re.compile(r'(\b(19|20)\d\d\s*[–-]|\bseason\b|\bcastilla\b|\bjuvenil\b|\byouth\b|\bunder\s*\d|'
                        r'\bu\s?\d\d\b|\breserves?\b|\bacademy\b|\bprimavera\b|\bfederation\b|\bfederazione\b|'
                        r' at the |\s(b|ii|iii)$)')


OFFSET = 1_000_000_000  # The database repeats some clubs as OFFSET + id ("PSG" = "Paris Saint-Germain").
_TWINS = {}


def primaries(clubs):
    """club id → the id of its twin group's primary (most player links, then lowest id)."""
    cached = _TWINS.get(id(clubs))
    if cached and cached[0] is clubs:
        return cached[1]
    parent = {i: i for i in clubs}

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a, b):
        parent[find(a)] = find(b)

    by_name = {}
    for i, c in clubs.items():
        base = str(int(i) - OFFSET)
        if int(i) >= OFFSET and base in clubs:
            union(i, base)
        k, ctry = club_key(c['name']), norm(c['country'])
        if len(k) >= 3 and ctry:
            if (k, ctry) in by_name:
                union(i, by_name[(k, ctry)])
            else:
                by_name[(k, ctry)] = i
    groups = {}
    for i in clubs:
        groups.setdefault(find(i), []).append(i)
    out = {}
    for members in groups.values():
        best = min(members, key=lambda i: (-clubs[i].get('links', 0), int(i)))
        for i in members:
            out[i] = best
    _TWINS[id(clubs)] = (clubs, out)
    return out


def club_twins(clubs):
    """{primary id: [other ids of the same club]} for clubs recorded more than once."""
    out = {}
    for i, best in primaries(clubs).items():
        if i != best:
            out.setdefault(best, []).append(i)
    return {k: sorted(v, key=int) for k, v in out.items()}


def map_club(label, country, clubs, aliases, qid=None):
    """Database club id (twin group primary) for a Wikidata club, or None. Aliases (QID → club id) win."""
    if qid and qid in aliases:
        return aliases[qid]
    key = club_key(label)
    if not key or NOT_SENIOR.search(fold(label).strip()):
        return None
    prim = primaries(clubs)
    # A database name that folds to 1–2 letters ("L\\") would substring-match anything.
    local = [c for c in clubs.values() if same_country(country, c['country']) and len(club_key(c['name'])) >= 3]
    exact = {prim[c['id']] for c in local if club_key(c['name']) == key}
    if len(exact) == 1:
        return exact.pop()
    near = {prim[c['id']] for c in local if key in club_key(c['name']) or club_key(c['name']) in key}
    return near.pop() if len(near) == 1 and not exact else None


def season_bounds(start, end):
    """Wikidata year-only dates (YYYY-01-01) as season bounds: start Jul 1, end Jun 30 (whole year if
    that would end before it starts), the same convention as the manual tables."""
    sc, ec = start.endswith('-01-01'), bool(end) and end.endswith('-01-01')
    s = start[:4] + '-07-01' if sc else start
    e = end[:4] + '-06-30' if ec else end
    if e and e < s:
        if sc and ec:
            return start[:4] + '-01-01', end[:4] + '-12-31'
        if ec:
            e = end[:4] + '-12-31'
        elif sc:
            s = start[:4] + '-01-01'
    return s, e


def open_conflicts(coaches):
    """Coaches with open-ended tenures at two or more clubs (one of them is wrong data)."""
    return sorted(k for k, ts in coaches.items() if len({t['clubId'] for t in ts if not t['end']}) > 1)


def dropped(drops, club, start):
    return any(d['clubId'] == club and d.get('start') in (None, start) for d in drops)


def build_one(coach_id, name, rows, clubs, aliases, manual=None):
    """One coach's tenures and report lines. Never guesses: undated or unmapped rows are dropped.

    manual = {"add": {coachId: [tenure]}, "drop": {coachId: [{clubId, start?}]}} — owner-reviewed fixes
    (a drop without start removes every Wikidata row at that club)."""
    manual = manual or {}
    if coach_id in manual.get('replace', {}):
        # Owner-reviewed full career (Wikipedia statistics table) instead of Wikidata.
        tenures = [{'clubId': str(t['clubId']), 'start': t['start'], 'end': t.get('end')}
                   for t in manual['replace'][coach_id]]
        return sorted(tenures, key=lambda t: t['start']), [f'- {name}: görevler elle tablodan ({len(tenures)})']
    drops = manual.get('drop', {}).get(coach_id, [])
    tenures, report, seen = [], [], set()
    for r in rows:
        club = map_club(r['label'], r['country'], clubs, aliases, r['qid'])
        if club is not None and dropped(drops, club, r['start']):
            report.append(f'- {name}: "{r["label"]}" {r["start"]} elle çıkarıldı')
            continue
        if club is None:
            report.append(f'- {name}: "{r["label"]}" ({r["country"]}, {r["qid"]}) eşlenemedi')
            continue
        if not r['start']:
            report.append(f'- {name}: "{r["label"]}" başlangıç tarihi yok, atlandı')
            continue
        sig = (club, r['start'], r['end'])
        if sig in seen:
            continue
        seen.add(sig)
        tenures.append({'clubId': club, 'start': r['start'], 'end': r['end']})
    # Wikidata stores year-precision dates as YYYY-01-01; drop such a row when the same club has a
    # precise row starting that year (the coarse one would stretch the spell to January).
    tenures = [t for t in tenures if not (t['start'].endswith('-01-01') and any(
        o is not t and o['clubId'] == t['clubId'] and o['start'][:4] == t['start'][:4] and
        not o['start'].endswith('-01-01') for o in tenures))]
    for t in tenures:
        t['start'], t['end'] = season_bounds(t['start'], t['end'])
    for t in manual.get('add', {}).get(coach_id, []):
        tenures.append({'clubId': str(t['clubId']), 'start': t['start'], 'end': t.get('end')})
        report.append(f'- {name}: kulüp {t["clubId"]} {t["start"]}..{t.get("end") or ""} elle eklendi')
    tenures.sort(key=lambda t: t['start'])
    return tenures, report


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/sparql-results+json'})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode('utf-8'))


NAMES = """SELECT ?name ?coach WHERE {
  VALUES ?name { %(values)s }
  ?coach rdfs:label ?name ; wdt:P106 wd:Q628099 .
}"""


def sparql(query):
    """One SPARQL request (waits and retries on HTTP 429)."""
    url = 'https://query.wikidata.org/sparql?' + urllib.parse.urlencode({'query': query, 'format': 'json'})
    for attempt in range(8):
        try:
            return get(url)
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 7:
                raise
            time.sleep(70)


def find_qids(names):
    """Wikidata ids of association football managers by exact English label, one request."""
    values = ' '.join('"%s"@en' % n.replace('"', '') for n in names)
    out = {}
    for b in sparql(NAMES % {'values': values})['results']['bindings']:
        out.setdefault(b['name']['value'], b['coach']['value'].rsplit('/', 1)[-1])
    return out


def find_qid(name):
    q = urllib.parse.urlencode({'action': 'wbsearchentities', 'search': name, 'language': 'en', 'type': 'item',
                                'limit': 10, 'format': 'json'})
    for hit in get('https://www.wikidata.org/w/api.php?' + q).get('search', []):
        desc = fold(hit.get('description', ''))
        if any(w in desc for w in ('football', 'soccer', 'manager', 'coach')):
            return hit['id']
    return None


# One query for every coach (the public endpoint may allow only 1 request a minute).
QUERY = """SELECT ?coach ?club ?clubLabel ?countryLabel ?start ?end WHERE {
  VALUES ?coach { %(values)s }
  { ?coach p:P6087 ?st . ?st ps:P6087 ?club . }
  UNION { ?club p:P286 ?st . ?st ps:P286 ?coach . }
  OPTIONAL { ?st pq:P580 ?start . } OPTIONAL { ?st pq:P582 ?end . }
  OPTIONAL { ?club wdt:P17 ?country . }
  FILTER NOT EXISTS { ?club wdt:P31/wdt:P279* wd:Q6979593 . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}"""


def fetch_all(qids):
    """Rows per coach QID from one SPARQL request (waits and retries on HTTP 429)."""
    data = sparql(QUERY % {'values': ' '.join('wd:' + q for q in qids)})
    per = {}
    for b in data['results']['bindings']:
        per.setdefault(b['coach']['value'].rsplit('/', 1)[-1], []).append(b)
    return {q: parse_tenures({'results': {'bindings': per.get(q, [])}}) for q in qids}


def load_clubs():
    c = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    links = dict(c.execute('select club_id, count(*) from player_clubs group by club_id'))
    return {str(i): {'id': str(i), 'name': n, 'country': ctry or '', 'links': links.get(i, 0)}
            for i, n, ctry, kind in c.execute('select id,name,country,entity_type from clubs') if kind == 'SENIOR'}


def main():
    with open(POOL, encoding='utf-8') as f:
        pool = json.load(f)
    aliases = json.load(open(ALIASES, encoding='utf-8')) if os.path.exists(ALIASES) else {}
    manual = json.load(open(MANUAL, encoding='utf-8')) if os.path.exists(MANUAL) else {}
    clubs = load_clubs()
    out, report = {}, ['# Teknik direktör görev geçmişi raporu', '']
    missing = [c['name'] for c in pool if not c.get('wikidata') and not str(c.get('coachId')).startswith('manual_')]
    if missing:
        qids = find_qids(missing)
        for coach in pool:
            coach['wikidata'] = coach.get('wikidata') or qids.get(coach['name'])
        time.sleep(70)
    found = [c for c in pool if c['wikidata']]
    rows = fetch_all([c['wikidata'] for c in found])
    for coach in pool:
        if not coach['wikidata'] and not coach.get('coachId'):
            report.append(f'- {coach["name"]}: Wikidata kaydı bulunamadı')
            continue
        if not coach['wikidata']:
            report.append(f'- {coach["name"]}: Wikidata kaydı yok, yalnız elle eklenenler')
        coach['coachId'] = coach.get('coachId') or 'wd_' + coach['wikidata']
        tenures, lines = build_one(coach['coachId'], coach['name'], rows.get(coach['wikidata'], []), clubs,
                                 aliases, manual)
        prim = primaries(clubs)
        out[coach['coachId']] = [dict(t, clubId=prim.get(t['clubId'], t['clubId'])) for t in tenures]
        report += lines
        report.append(f'- {coach["name"]}: {len(tenures)} görev')
    with open(POOL, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(pool, f, ensure_ascii=False, indent=1)
        f.write('\n')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        for k in open_conflicts(out):
            report.append(f'- UYARI {k}: birden çok kulüpte bitişi olmayan görev; elle kontrol et')
        used = {t['clubId'] for ts in out.values() for t in ts}
        # Same club recorded under several ids: membership must count spells at any of them.
        twins = {k: v for k, v in club_twins(clubs).items() if k in used}
        json.dump({'version': 1, 'coaches': out, 'clubTwins': twins}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    with open(REPORT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(report) + '\n')
    print(f'{len(out)} coaches, {sum(map(len, out.values()))} tenures; report: {REPORT}')


if __name__ == '__main__':
    main()
