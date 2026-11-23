#!/usr/bin/env python3
"""Build the reviewed patch of well-known footballers missing from V4, offline.

Evidence (patches/, fetched by fetch_famous_players.py):
- famous-players-candidates-2026-11-23.json: Wikidata men footballers with 25+
  sitelinks that no V4 player matches (name or alias, birth year within one),
  with their English Wikipedia title and sport country / citizenship.
- famous-players-careers-2026-11-23.json: each title's infobox senior career
  (revision pinned), the same parser as fetch_wikipedia_careers.py.
- famous-players-clubmap-2026-11-23.json: Wikipedia club title -> V4 club id,
  learned from the players V4 and Wikipedia already share (a title maps to the
  club most of its players are linked to, 60%+ of them), plus redirects.

A senior row maps to a club only through that map or an unambiguous name match
that is not one of the big clubs the map already owns ("Barcelona Sporting
Club" never becomes FC Barcelona); reserve and youth sides are dropped, clubs are
never created. A candidate is kept with at least one mapped club.

Run: py -3 tools/data_platform_v4/build_famous_players.py [--check]
"""
import argparse
import collections
import json
from pathlib import Path
import re
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
PATCHES = ROOT / 'tools/data_platform_v4/patches'
CANDIDATES = PATCHES / 'famous-players-candidates-2026-11-23.json'
CAREERS = PATCHES / 'famous-players-careers-2026-11-23.json'
CLUBMAP = PATCHES / 'famous-players-clubmap-2026-11-23.json'
OUT = PATCHES / 'famous-players-2026-11-23.json'
FIRST_ID = 4100000001
# Japan's many well-linked J.League players stay out unless they played in one of these leagues
# (outside Japan): the players this game's audience knows.
BIG_LEAGUES = {'Premier League', 'LaLiga', 'Serie A', 'Bundesliga', 'Ligue 1', 'Eredivisie', 'Liga Portugal',
               'Süper Lig', 'Scottish Premiership', 'Jupiler Pro League'}  # A new reviewed-player block after the 40000000xx reviews.

YOUTH = re.compile(r'(\s(II|III|B|C)$|-2\b|\breserves?\b|\bU-?\d\d\b|\bunder[- ]?\d\d\b|\byouth\b|\bacademy\b|'
                   r'\bprimavera\b|\bcastilla\b|\batl[eè]tic\b|\bnext gen\b|^jong\b|\bamateure?\b|\bsub-?\d\d\b|'
                   r'\bpromesas\b|\bmestalla\b|\bfilial\b|\bII\s|\bB\s\(|\bliefering\b)', re.I)
NOT_YOUTH = re.compile(r'willem ii', re.I)
GENERIC = set('fc cf sc sk ac afc cd club de do da football futebol futbol f c s k a sv fk the e y del la el as us ss '
              'rc rcd ca cr sd ud cp fbc bk if ff nk pfc ssc acf ec se ad cs 1 sl kv calcio clube regatas'.split())
# Wikidata country names -> the database's spelling. Former states resolve through citizenship.
COUNTRY = {'Turkey': 'Türkiye', 'South Korea': 'Korea, South', 'North Korea': 'Korea, North',
           'Ivory Coast': "Cote d'Ivoire", "People's Republic of China": 'China',
           'Democratic Republic of the Congo': 'DR Congo', 'Republic of the Congo': 'Congo',
           'United States of America': 'United States', 'Kingdom of the Netherlands': 'Netherlands',
           'West Germany': 'Germany', 'Czechia': 'Czech Republic', 'Republic of Ireland': 'Ireland'}
FORMER = {'Soviet Union', 'Yugoslavia', 'Czechoslovakia', 'East Germany', 'Serbia and Montenegro',
          'Socialist Federal Republic of Yugoslavia', 'Federal Republic of Yugoslavia', 'Commonwealth of Independent States',
          'Protectorate of Bohemia and Moravia', 'Kingdom of Yugoslavia', 'Russian Empire', 'Austria-Hungary',
          'Kingdom of Hungary', 'Kingdom of Italy', 'German Reich', 'Nazi Germany', 'Weimar Republic',
          'United Kingdom of Great Britain and Ireland', 'Mandatory Palestine', 'Ottoman Empire', 'Saar Protectorate'}
BLOCK = {'Wimbledon F.C.'}  # The historic club; AFC Wimbledon is a different one.
HOME = {'England', 'Scotland', 'Wales', 'Northern Ireland'}
SUCCESSOR = {'Soviet Union': 'Russia', 'Commonwealth of Independent States': 'Russia', 'Russian Empire': 'Russia',
             'Yugoslavia': 'Serbia', 'Socialist Federal Republic of Yugoslavia': 'Serbia', 'Kingdom of Yugoslavia': 'Serbia',
             'Federal Republic of Yugoslavia': 'Serbia', 'Serbia and Montenegro': 'Serbia',
             'Czechoslovakia': 'Czech Republic', 'Protectorate of Bohemia and Moravia': 'Czech Republic',
             'East Germany': 'Germany', 'German Reich': 'Germany', 'Nazi Germany': 'Germany', 'Weimar Republic': 'Germany',
             'Kingdom of Italy': 'Italy', 'Kingdom of Hungary': 'Hungary', 'Austria-Hungary': 'Austria',
             'Ottoman Empire': 'Türkiye', 'United Kingdom': 'England',
             'United Kingdom of Great Britain and Ireland': 'England'}


def fold(s):
    s = str(s or '').lower().translate(str.maketrans({'ı': 'i', 'ø': 'o', 'ß': 'ss', 'ł': 'l', 'æ': 'ae', 'đ': 'd'}))
    return ''.join(ch for ch in unicodedata.normalize('NFKD', s) if not unicodedata.combining(ch))


def tokens(s):
    s = re.sub(r'[^a-z0-9 ]', ' ', re.sub(r'\(.*?\)', '', fold(s)))
    return {t for t in s.split() if t not in GENERIC and len(t) > 1}


def youth(s):
    return bool(s) and bool(YOUTH.search(s)) and not NOT_YOUTH.search(s)


def position(raw):
    """The first position the infobox lists (link labels, not targets)."""
    s = fold(re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]', r'\1', raw or ''))
    hits = []
    for words, group in [('goalkeeper,keeper', 'Goalkeeper'), ('back,defender,sweeper,libero', 'Defender'),
                         ('midfield,playmaker', 'Midfield'), ('forward,striker,winger,attacker', 'Attack')]:
        at = [s.find(w) for w in words.split(',') if w in s]
        if at:
            hits.append((min(at), group))
    return min(hits)[1] if hits else None


def country(sport, citizen, known):
    def modern(names):
        out = []
        for n in names:
            n = COUNTRY.get(n, n)
            if n not in FORMER and n in known and n not in out:
                out.append(n)
        return out
    sport_m = modern(sport)
    home = [n for n in sport_m if n in HOME]
    cit = modern(c for c in citizen if c != 'United Kingdom')
    sport_m = [n for n in sport_m if n != 'United Kingdom']
    ordered = home + [n for n in sport_m if n in cit and n not in home] + [n for n in sport_m if n not in home and n not in cit]
    if not ordered:
        ordered = cit
    if not ordered:  # Only a former state (or the UK): its successor in the game's country list.
        ordered = [x for x in dict.fromkeys(SUCCESSOR.get(n) for n in list(sport) + list(citizen)) if x and x in known]
    return ordered


def build(database=DB):
    con = sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)
    clubs = {i: (n, t, g) for i, n, t, g in con.execute('SELECT id,name,entity_type,gameplay_eligible FROM clubs')}
    pool = {i: (n, tokens(n)) for i, (n, t, g) in clubs.items() if t == 'SENIOR' and g}
    home = dict(con.execute('SELECT id,country FROM clubs'))
    league = dict(con.execute('SELECT id,competition FROM clubs'))
    from apply_roster_expansion import norm
    born_v4 = dict(con.execute('SELECT player_id,birth_year FROM profiles'))
    owners = collections.defaultdict(set)
    for pid, label in con.execute('SELECT id,name FROM players UNION SELECT player_id,alias FROM player_aliases'):
        owners[norm(label).replace(' ', '')].add(pid)
    surname = collections.defaultdict(set)  # (surname, first three letters of the first name) -> V4 ids
    for pid, label in con.execute('SELECT id,name FROM players UNION SELECT player_id,alias FROM player_aliases'):
        words = norm(label).split()
        if len(words) > 1:
            surname[(words[-1], words[0][:3])].add(pid)
    links = collections.defaultdict(set)
    for pid, club in con.execute('SELECT player_id,club_id FROM player_clubs'):
        links[pid].add(club)
    used = collections.Counter(r[0] for r in con.execute('SELECT club_id FROM player_clubs'))
    known = {r[0] for r in con.execute('SELECT country FROM player_countries UNION SELECT country FROM players')}
    first = FIRST_ID
    candidates = json.loads(CANDIDATES.read_text(encoding='utf-8'))
    careers = json.loads(CAREERS.read_text(encoding='utf-8'))['pages']
    clubmap = json.loads(CLUBMAP.read_text(encoding='utf-8'))
    cmap, redirects = clubmap['titles'], clubmap['redirects']
    owned = {v for v in cmap.values()}

    def resolve(row, nations):
        t, label = (row.get('title') or '').strip(), (row.get('label') or '').strip()
        if not t and not label or t in BLOCK:
            return None
        if youth(t) or youth(label):
            return None
        for x in (t, redirects.get(t, t)):
            if x in cmap:
                return cmap[x]
        for text in filter(None, [redirects.get(t, t), t, label]):
            want = tokens(text)
            if not want:
                continue
            scored = sorted(((len(want & ct) / len(want | ct), i) for i, (n, ct) in pool.items()
                             if want & ct and i not in owned), reverse=True)
            if not scored or scored[0][0] < .6:
                continue
            best = [i for s, i in scored if s == scored[0][0]]
            if len({pool[i][0].lower() for i in best}) != 1:
                continue
            club = max(best, key=lambda i: used[i])
            # One-word names ("Olimpia", "Nacional") and qualified titles ("América (RJ)") exist in
            # several countries: only a club of the player's own country is taken.
            if (len(want) == 1 or '(' in text) and home.get(club) not in nations:
                return None
            return club
        return None

    def year(text, last):
        found = re.findall(r'(1[89]\d\d|20\d\d)', text or '')
        return int(found[-1 if last else 0]) if found else None

    players, skipped, next_id, spelled = [], collections.Counter(), first, []
    v4_name = dict(con.execute('SELECT id,name FROM players'))
    for c in sorted(candidates, key=lambda c: (-c['links'], c['qid'])):
        page = careers.get(c['title'])
        if not page or not page.get('senior'):
            skipped['no football infobox'] += 1
            continue
        spells, linked = [], []
        nations = country(c.get('sport', []), c.get('citizen', []), known)
        for row in page['senior']:
            club = resolve(row, nations)
            if club is None:
                continue
            if club not in linked:
                linked.append(club)
            start = year(row['years'], False)
            open_end = bool(re.search(r'[-–]\s*$', row['years'] or ''))
            spells.append(dict(id=club, startYear=start, endYear=None if open_end else (year(row['years'], True) or start),
                               loan=bool(row.get('loan'))))
        if not linked:
            skipped['no database club'] += 1
            continue
        if nations[:1] == ['Japan'] and not any(league.get(i) in BIG_LEAGUES and home.get(i) != 'Japan' for i in linked):
            skipped['Japan, no big European league'] += 1
            continue
        pos = position(page.get('position') or '')
        if not nations or not pos:
            skipped['no country' if not nations else 'no position'] += 1
            continue
        base = re.sub(r'\s*\(.*\)$', '', c['title'])
        name = c['name'] or base
        aliases = [a for a in dict.fromkeys([base, page.get('fullName') or '']) if a and fold(a) != fold(name)]
        born = int(page['birthDate'][:4]) if page.get('birthDate') else (int(c['born']) if str(c.get('born', '')).isdigit() else None)
        # The same person under another V4 name: an alias (full name) of a V4 player born within a year.
        if born and any(born_v4.get(i) and abs(born_v4[i] - born) <= 1
                        for a in [name] + aliases for i in owners[norm(a).replace(' ', '')]):
            skipped['already in V4 under another name'] += 1
            continue
        # Another spelling of the same person (Alexey / Aleksey Smertin): the same surname, a first name
        # starting alike, and two shared clubs.
        mine = {i for i in linked}
        keys = {(norm(a).split()[-1], norm(a).split()[0][:3]) for a in [name] + aliases if len(norm(a).split()) > 1}
        twin = next((i for k in sorted(keys) for i in sorted(surname[k])
                     if len(links[i] & mine) >= 2 and
                     (not born_v4.get(i) or not born or abs(born_v4[i] - born) <= 3)), None)
        if twin:
            skipped['already in V4 under another spelling'] += 1
            spelled.append(dict(qid=c['qid'], name=name, v4Id=twin, v4Name=v4_name[twin]))
            continue
        players.append(dict(id=next_id, qid=c['qid'], name=name, aliases=aliases, birthYear=born,
                            countries=nations, position=pos, sitelinks=c['links'],
                            source=dict(title=page['title'], revid=page['revid']),
                            clubs=[dict(id=i, name=clubs[i][0]) for i in linked], spells=spells))
        next_id += 1
    return dict(reviewedUtc='2026-11-23', source='https://en.wikipedia.org (infobox) + https://www.wikidata.org',
                policy='Men footballers with 25+ Wikidata sitelinks missing from V4. Senior clubs and years from the '
                       'English Wikipedia infobox (revision pinned); clubs mapped by the learned title map, never created; '
                       'reserve and youth sides dropped. Country: sport country, else modern citizenship.',
                players=players, skipped=dict(skipped), sameAsV4=spelled)


def encode(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = encode(build())
    if args.check:
        raise SystemExit(0 if OUT.exists() and OUT.read_text(encoding='utf-8') == data else 'patch is stale')
    OUT.write_text(data, encoding='utf-8', newline='\n')
    d = json.loads(data)
    print(len(d['players']), 'players;', d['skipped'])
