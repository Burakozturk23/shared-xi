#!/usr/bin/env python3
"""Fetch the evidence for build_famous_players.py (network; never writes the database).

1. Wikidata (QLever mirror): men footballers (P106 Q937857) with 25+ sitelinks, their
   English Wikipedia title, birth year, sport country (P1532) and citizenship (P27).
2. Match against V4 names and aliases (word order free, birth year within one; a
   surname with the exact birth year also counts): the rest are candidates.
3. English Wikipedia infobox senior careers for candidates AND matched players,
   50 titles per request (revision pinned).
4. Club title map: for matched players, each Wikipedia club title votes for the V4
   clubs that player is linked to; a title maps to its top club with 60%+ of its
   players (and a shared word, or 8+ votes at 80%). Redirects of unmapped titles.
5. English Wikipedia views of the last 60 days for candidates and matched players, the
   evidence apply_pageview_ranks.py places players by (--pageviews reruns only this step).

Run: py -3 tools/data_platform_v4/fetch_famous_players.py
"""
import collections
import concurrent.futures
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

import fetch_wikipedia_careers as W
from build_famous_players import CANDIDATES, CAREERS, CLUBMAP, DB, PATCHES, fold, tokens, youth

QLEVER = 'https://qlever.dev/api/wikidata'
HEADERS = {'User-Agent': 'LinkballDataTool/1.0 (offline football data review)'}
MATCHED = PATCHES / 'famous-players-matched-2026-11-23.json'
PAGEVIEWS = PATCHES / 'pageviews-2026-11-23.json'
RANK_ARTICLES = PATCHES / 'rank-articles-2026-11-23.json'
TR_PAGEVIEWS = PATCHES / 'pageviews-tr-2026-11-23.json'
# Asked for by name although under the sitelink threshold: Wikidata id -> English Wikipedia title.
MANUAL = {'Q3378748': 'Phil Chisnall'}
BIG_FOUR = (141, 36, 114, 449)  # Galatasaray, Fenerbahçe, Beşiktaş, Trabzonspor
MIN_SITELINKS = 25
PREFIX = '''PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX schema: <http://schema.org/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
'''


def sparql(query):
    req = urllib.request.Request(QLEVER, data=urllib.parse.urlencode({'query': PREFIX + query}).encode(),
                                 headers={**HEADERS, 'Accept': 'application/sparql-results+json'})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)['results']['bindings']


def qid(b, k):
    return b[k]['value'].rsplit('/', 1)[1]


def wikidata():
    counts = {qid(b, 'p'): int(b['n']['value']) for b in sparql(
        f'SELECT ?p (COUNT(DISTINCT ?s) AS ?n) WHERE {{ ?p wdt:P106 wd:Q937857 . ?s schema:about ?p . }} '
        f'GROUP BY ?p HAVING (COUNT(DISTINCT ?s) >= {MIN_SITELINKS})')}
    rows, ids = {}, sorted(counts)
    for i in range(0, len(ids), 1500):
        values = ' '.join('wd:' + x for x in ids[i:i + 1500])
        for b in sparql(f'''SELECT ?p ?label ?article (MIN(?b) AS ?born) (SAMPLE(?g) AS ?sex) (COUNT(DISTINCT ?t) AS ?teams)
            WHERE {{ VALUES ?p {{ {values} }}
            OPTIONAL {{ ?article schema:about ?p ; schema:isPartOf <https://en.wikipedia.org/> . }}
            OPTIONAL {{ ?p rdfs:label ?label . FILTER(LANG(?label)="en") }}
            OPTIONAL {{ ?p wdt:P569 ?b }} OPTIONAL {{ ?p wdt:P21 ?g }} OPTIONAL {{ ?p wdt:P54 ?t }}
            }} GROUP BY ?p ?label ?article'''):
            art = b.get('article', {}).get('value')
            rows[qid(b, 'p')] = dict(qid=qid(b, 'p'), links=counts[qid(b, 'p')], name=b.get('label', {}).get('value', ''),
                                     title=urllib.parse.unquote(art.rsplit('/wiki/', 1)[1]).replace('_', ' ') if art else None,
                                     born=b.get('born', {}).get('value', '')[:4], sex=b.get('sex', {}).get('value', '').rsplit('/', 1)[-1],
                                     teams=int(b['teams']['value']), sport=[], citizen=[])
        for b in sparql(f'''SELECT ?p ?kind ?name WHERE {{ VALUES ?p {{ {values} }}
            {{ ?p wdt:P1532 ?c . BIND("sport" AS ?kind) }} UNION {{ ?p wdt:P27 ?c . BIND("citizen" AS ?kind) }}
            ?c rdfs:label ?name . FILTER(LANG(?name)="en") }}'''):
            rows[qid(b, 'p')][b['kind']['value']].append(b['name']['value'])
        time.sleep(1)
    for r in rows.values():
        r['sport'], r['citizen'] = sorted(set(r['sport'])), sorted(set(r['citizen']))
    return [r for r in rows.values() if r['title'] and r['sex'] != 'Q6581072' and r['teams'] >= 2]


def match(rows):
    import sqlite3
    con = sqlite3.connect(DB.resolve().as_uri() + '?mode=ro', uri=True)
    def words(s):
        return [t for t in re.sub(r'[^a-z0-9 ]', ' ', fold(s).replace('-', ' ')).split() if t]
    full, by_word, born = collections.defaultdict(set), collections.defaultdict(set), {}
    for i, n in con.execute('SELECT id,name FROM players UNION ALL SELECT player_id,alias FROM player_aliases'):
        w = words(n)
        full[' '.join(sorted(w))].add(i)
        for t in w:
            if len(t) >= 4:
                by_word[t].add(i)
    born.update(con.execute('SELECT player_id,birth_year FROM profiles'))
    missing, matched = [], {}
    for r in rows:
        y = int(r['born']) if r['born'].isdigit() else None
        names = [r['name'], re.sub(r'\s*\(.*\)$', '', r['title'])]
        found = {i for n in names for i in full.get(' '.join(sorted(words(n))), ())
                 if not y or not born.get(i) or abs(born[i] - y) <= 1}
        if not found and y:
            found = {i for n in names for t in words(n) if len(t) >= 4 for i in by_word.get(t, ()) if born.get(i) == y}
        if found:
            if len(found) == 1:
                matched[r['title']] = next(iter(found))
        else:
            missing.append(r)
    return missing, matched


def careers(titles):
    out = {}
    for i in range(0, len(titles), 50):
        q = W.call(action='query', prop='revisions', rvprop='ids|content', rvslots='main', redirects='1',
                   titles='|'.join(titles[i:i + 50]))['query']
        hop = {x['from']: x['to'] for x in q.get('normalized', []) + q.get('redirects', [])}
        pages = {p['title']: p for p in q['pages'] if not p.get('missing') and 'revisions' in p}
        for t in titles[i:i + 50]:
            p = pages.get(hop.get(hop.get(t, t), hop.get(t, t)))
            if not p:
                continue
            rev = p['revisions'][0]
            box = W.infobox(rev['slots']['main']['content'])
            f = W.fields(box) if box else {}
            out[t] = dict(title=p['title'], revid=rev['revid'], birthDate=W.born(f.get('birth_date', '')),
                          fullName=W.clean(f.get('fullname', '')) or None, position=W.clean(f.get('position', '')) or None,
                          senior=W.senior(f) if box else None)
    return out


def clubmap(pages, matched):
    import sqlite3
    con = sqlite3.connect(DB.resolve().as_uri() + '?mode=ro', uri=True)
    names = dict(con.execute('SELECT id,name FROM clubs'))
    links = collections.defaultdict(set)
    for p, c in con.execute('SELECT player_id,club_id FROM player_clubs'):
        links[p].add(c)
    votes, seen = collections.defaultdict(collections.Counter), collections.Counter()
    for title, pid in matched.items():
        for row in (pages.get(title) or {}).get('senior') or []:
            t = row['title'] or row['label']
            if not t or youth(t):
                continue
            seen[t] += 1
            for c in links[pid]:
                votes[t][c] += 1
    out = {}
    for t, cnt in votes.items():
        (club, v), *rest = cnt.most_common(2)
        if v >= 2 and v / seen[t] >= .6 and v > (rest[0][1] if rest else 0) and (
                tokens(t) & tokens(names[club]) or (v >= 8 and v / seen[t] >= .8)):
            out[t] = club
    unmapped = sorted({r['title'] for p in pages.values() for r in (p.get('senior') or [])
                       if r['title'] and r['title'] not in out})
    redirects = {}
    for i in range(0, len(unmapped), 50):
        q = W.call(action='query', redirects='1', titles='|'.join(unmapped[i:i + 50]))['query']
        hop = {x['from']: x['to'] for x in q.get('normalized', []) + q.get('redirects', [])}
        for t in unmapped[i:i + 50]:
            to = hop.get(hop.get(t, t), hop.get(t, t))
            if to != t:
                redirects[t] = to
    return dict(titles=dict(sorted(out.items())), redirects=dict(sorted(redirects.items())))


def pageviews(titles):
    """Total English Wikipedia views of the last 60 days per title (MediaWiki PageViewInfo, 50 per request)."""
    out = {}
    for i in range(0, len(titles), 50):
        chunk, params = titles[i:i + 50], dict(action='query', prop='pageviews', pvipdays='60', redirects='1')
        params['titles'] = '|'.join(chunk)
        seen = {}
        while True:
            data = W.call(**params)
            q = data['query']
            hop = {x['from']: x['to'] for x in q.get('normalized', []) + q.get('redirects', [])}
            for p in q['pages']:
                if 'pageviews' in p:
                    seen[p['title']] = sum(v or 0 for v in p['pageviews'].values())
            if 'continue' not in data:
                break
            params.update(data['continue'])
        for t in chunk:
            out[t] = seen.get(hop.get(hop.get(t, t), hop.get(t, t)), 0)
    return dict(sorted(out.items()))


def manual():
    """Candidate rows for MANUAL players (same fields as wikidata())."""
    values = ' '.join('wd:' + q for q in MANUAL)
    rows = {q: dict(qid=q, links=0, name='', title=t, born='', sex='', teams=0, sport=[], citizen=[]) for q, t in MANUAL.items()}
    for b in sparql(f'''SELECT ?p ?label (MIN(?b) AS ?born) (COUNT(DISTINCT ?s) AS ?n) WHERE {{ VALUES ?p {{ {values} }}
        ?s schema:about ?p . OPTIONAL {{ ?p rdfs:label ?label . FILTER(LANG(?label)="en") }} OPTIONAL {{ ?p wdt:P569 ?b }}
        }} GROUP BY ?p ?label'''):
        rows[qid(b, 'p')].update(name=b.get('label', {}).get('value', ''), born=b.get('born', {}).get('value', '')[:4],
                                 links=int(b['n']['value']))
    for b in sparql(f'''SELECT ?p ?kind ?name WHERE {{ VALUES ?p {{ {values} }}
        {{ ?p wdt:P1532 ?c . BIND("sport" AS ?kind) }} UNION {{ ?p wdt:P27 ?c . BIND("citizen" AS ?kind) }}
        ?c rdfs:label ?name . FILTER(LANG(?name)="en") }}'''):
        rows[qid(b, 'p')][b['kind']['value']].append(b['name']['value'])
    return list(rows.values())


def rank_articles(matched):
    """Players apply_pageview_ranks.py must place (added after V4's ranking, or unranked) that the
    sitelink match did not tie to an article: their name as the title, kept only when it is a
    football biography."""
    import sqlite3
    con = sqlite3.connect(DB.resolve().as_uri() + '?mode=ro', uri=True)
    have = set(matched.values())
    want = {i: n for i, n in con.execute(
        "SELECT id,name FROM players WHERE (source='reviewed-player' OR selection_rank IS NULL)") if i not in have}
    pages = careers(sorted(set(want.values())))
    return {str(i): pages[n]['title'] for i, n in sorted(want.items()) if n in pages and pages[n].get('senior')}


def turkish_titles(matched, articles):
    """English titles of players this game's Turkish audience knows better than the English Wikipedia
    shows: Türkiye players and anyone who played for Galatasaray, Fenerbahçe, Beşiktaş or Trabzonspor."""
    import sqlite3
    con = sqlite3.connect(DB.resolve().as_uri() + '?mode=ro', uri=True)
    turks = {i for (i,) in con.execute("SELECT id FROM players WHERE country IN ('Türkiye','Turkey')")}
    turks |= {i for (i,) in con.execute('SELECT player_id FROM player_clubs WHERE club_id IN (%s)' % ','.join(map(str, BIG_FOUR)))}
    titles = {t for t, i in matched.items() if i in turks} | {t for i, t in articles.items() if int(i) in turks}
    cands = json.loads(CANDIDATES.read_text(encoding='utf-8'))
    pages = json.loads(CAREERS.read_text(encoding='utf-8'))['pages']
    cmap = json.loads(CLUBMAP.read_text(encoding='utf-8'))['titles']
    def played_big_four(title):
        return any(cmap.get(r['title']) in BIG_FOUR for r in (pages.get(title) or {}).get('senior') or [])
    return sorted(titles | {r['title'] for r in cands if 'Turkey' in r['sport'] + r['citizen'] or played_big_four(r['title'])})


def tr_pageviews(titles):
    """The same 60-day views on the Turkish Wikipedia (an article of the same title, or a redirect)."""
    api = W.API
    W.API = 'https://tr.wikipedia.org/w/api.php'
    try:
        return pageviews(titles)
    finally:
        W.API = api


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    import sys
    if sys.argv[1:] == ['--extras']:  # MANUAL players and rank articles onto the saved evidence.
        cands = [r for r in json.loads(CANDIDATES.read_text(encoding='utf-8')) if r['qid'] not in MANUAL] + manual()
        save(CANDIDATES, sorted(cands, key=lambda r: (-r['links'], r['qid'])))
        matched = json.loads(MATCHED.read_text(encoding='utf-8'))
        evidence = json.loads(CAREERS.read_text(encoding='utf-8'))
        evidence['pages'].update(careers(sorted(MANUAL.values())))
        evidence['pages'] = dict(sorted(evidence['pages'].items()))
        save(CAREERS, evidence)
        articles = rank_articles(matched)
        save(RANK_ARTICLES, articles)
        views = json.loads(PAGEVIEWS.read_text(encoding='utf-8'))
        views.update(pageviews(sorted((set(articles.values()) | set(MANUAL.values())) - set(views))))
        save(PAGEVIEWS, dict(sorted(views.items())))
        save(TR_PAGEVIEWS, tr_pageviews(turkish_titles(matched, articles)))
        raise SystemExit
    rows = wikidata()
    missing, matched = match(rows)
    missing += [r for r in manual() if r['qid'] not in {m['qid'] for m in missing}]
    save(CANDIDATES, sorted(missing, key=lambda r: (-r['links'], r['qid'])))
    save(MATCHED, dict(sorted(matched.items())))
    pages = careers(sorted({r['title'] for r in missing} | set(matched)))
    save(CAREERS, dict(source='https://en.wikipedia.org', pages=dict(sorted(pages.items()))))
    save(CLUBMAP, clubmap(pages, matched))
    articles = rank_articles(matched)
    save(RANK_ARTICLES, articles)
    save(PAGEVIEWS, pageviews(sorted({r['title'] for r in missing} | set(matched) | set(articles.values()))))
    save(TR_PAGEVIEWS, tr_pageviews(turkish_titles(matched, articles)))
    print(len(rows), 'famous;', len(missing), 'missing;', len(matched), 'matched')
