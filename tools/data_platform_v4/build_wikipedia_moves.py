#!/usr/bin/env python3
"""Reviewed corrections to the summer-2026 moves, checked against English Wikipedia.

Read-only; writes patches/wikipedia-moves-2026-11-12.json for
apply_reviewed_corrections.py. Evidence: patches/wikipedia-careers-2026-11-12.json
(fetch_wikipedia_careers.py: each player's infobox senior career and revision id).

Three parts:
- MANUAL: per-player decisions made by reading the infobox (moves the Sporx
  matcher missed, roster rows that belonged to another player with the same
  name, loan-return rows Wikipedia contradicts). Every club a decision adds must
  appear in that player's infobox; the build stops otherwise.
- middle clubs: for each applied 2026 move, infobox rows between the club left
  and the club joined that the career lacks (mostly 2024-26 loans) become
  year-precision stops (REVIEWED_YEAR, stored as YYYY-07-01), when the club resolves to one
  database club. Unresolved rows are listed, not guessed.
- player_clubs: a club in a reviewed 2026 stop the player is not yet linked to
  (Sporx-only moves) gets the link the grid modes read.

Run: py -3 tools/data_platform_v4/build_wikipedia_moves.py [--check]
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import sqlite3

from build_current_club_review import DB, OFFSET, PATCHES, YOUTH, norm, offset_mismatch, same_club, tokens

OUT = PATCHES / 'wikipedia-moves-2026-11-12.json'
WIKI = PATCHES / 'wikipedia-careers-2026-11-12.json'
REVIEW = PATCHES / 'current-clubs-2026-11-11.json'
REVISION = 'v4-2026-11-12.1'
BASE = 'v4-2026-11-11.1'
BUILT = '2026-11-12T03:00:00+00:00'
YEAR, SEASON = 'REVIEWED_YEAR', 'REVIEWED_SEASON'
LINK = 'reviewed:summer-2026:2026-11-12'
DIRIYAH = 5000000024  # New club (Al-Diriyah); 5000000000+ are reviewed additions.
START = '2026-07-01'

# Wikipedia labels the resolver cannot place on its own: label -> club id.
CLUB = {'Wydad': 1000006603, 'Ludogorets Razgrad': 1000031614, 'Paris Saint-Germain': 1000000583,
        'Red Bull Salzburg': 409, 'Monaco': 1000000162}


def yr(year):
    """A year-precision date: the summer window of that year. The modes show only the year
    (precision 'year'); the month keeps stops in order next to exactly dated ones."""
    return year and f'{year}-07-01'


def season_move(pid, frm, to):
    return dict(op='addTransfer', eventId=f'season:{pid}:2026:{frm}:{to}', fromClubId=frm, toClubId=to,
                date=START, trust=SEASON)


def add(club, start, end=None, confidence=SEASON):
    return dict(op='addSpell', clubId=club, start=start, end=end, confidence=confidence)


def undo(pid, frm, to):
    """Take back an applied 2026 roster move: its stop and its transfer."""
    return [dict(op='removeSpell', clubId=to, start=START),
            dict(op='removeTransfer', eventId=f'season:{pid}:2026:{frm}:{to}')]


SAME_CLUB = 'No move: the roster lists the club he already played for under a second database row.'
WIKI_DISAGREES = 'Wikipedia has him still at {} (or the roster row is another player with the same name); '                  'the roster move is taken back.'

# playerId -> (clubs the infobox must name, reason, ops). Built by reading each
# player's infobox (wikipedia-careers-2026-11-12.json).
MANUAL = {
    # Sporx moves the name matcher missed; the infobox confirms each.
    319745: (['Real Madrid', 'Betis'], 'Real Madrid -> Real Betis (Sporx 327).',
             [add(150, START), season_move(319745, 418, 150)]),
    228948: (['Monaco', 'Ajax'], 'Monaco -> Ajax on loan; Sporx 326 has the clubs reversed, the roster and '
             'Wikipedia agree on Ajax.', [add(610, START), season_move(228948, 1000000162, 610)]),
    387047: (['Union Berlin', 'Lazio'], 'Union Berlin -> Lazio; Sporx 82 (Aston Villa) is wrong, the roster and '
             'Wikipedia agree on Lazio.', [add(398, START), season_move(387047, 89, 398)]),
    537860: (['Chelsea', 'Tottenham'], 'Chelsea -> Tottenham on loan (Sporx 318).',
             [add(148, START), season_move(537860, 631, 148)]),
    487969: (['Paris Saint-Germain', 'Juventus'], 'PSG -> Juventus (Sporx 152).',
             [dict(op='updateSpell', clubId=1000000583, start='2026-06-30', set=dict(end_date=START)),
              add(506, START), season_move(487969, 1000000583, 506)]),
    74857: (['Barcelona', 'Ajax'], 'Barcelona -> Ajax on loan (Sporx 161).',
            [dict(op='updateSpell', clubId=131, start='2026-06-30', set=dict(end_date=START)),
             add(610, START), season_move(74857, 131, 610)]),
    368887: (['Juventus', 'Lyon'], 'Juventus -> Lyon on loan (Sporx 135).',
             [dict(op='updateSpell', clubId=506, start=START, set=dict(end_date=START)),
              add(1041, START), season_move(368887, 506, 1041)]),
    126664: (['Aston Villa', 'Paris Saint-Germain'], 'Aston Villa -> PSG (Sporx 183).',
             [add(1000000583, START), season_move(126664, 405, 1000000583)]),
    500689: (['Aston Villa', 'Crystal Palace'], 'Aston Villa -> Crystal Palace on loan again (Sporx 195).',
             [dict(op='updateSpell', clubId=405, start='2026-06-30', set=dict(end_date=START)),
              add(873, START), season_move(500689, 405, 873)]),
    182893: (['Rennes', 'Porto'], 'Rennes -> Porto on loan again (Sporx 263).',
             [dict(op='updateSpell', clubId=273, start='2026-06-30', set=dict(end_date=START)),
              add(720, START), season_move(182893, 273, 720)]),
    # Wikipedia: Como bought Morata, then loaned him to Leganés (Sporx 277). The
    # loan-return stop at Milan never happened.
    128223: (['Como', 'Leganés'], 'Como (permanent) -> Leganés on loan; the 2026-06-30 return to Milan is '
             'replaced.', [dict(op='removeSpell', clubId=5, start='2026-06-30'),
                           dict(op='removeTransfer', eventId='tm:128223:2026-06-30:1047:5'),
                           dict(op='updateSpell', clubId=1047, start='2025-08-12', set=dict(end_date=START)),
                           add(1244, START), season_move(128223, 1047, 1244)]),
    # Wikipedia and Sporx 4/163: Burnley bought Florentino, then sold him to Ipswich.
    357162: (['Burnley', 'Ipswich'], 'Burnley (permanent) -> Ipswich; the 2026-06-30 return to Benfica is '
             'replaced.', [dict(op='removeSpell', clubId=294, start='2026-06-30'),
                           dict(op='removeTransfer', eventId='tm:357162:2026-06-30:1132:294'),
                           dict(op='updateSpell', clubId=1132, start='2025-09-01', set=dict(end_date=START)),
                           add(677, START), season_move(357162, 1132, 677)]),
    # Roster rows that belonged to another player with the same name.
    131102: (['Celta', 'Al-Shamal'], 'The roster\'s Jeison Murillo at Riestra is another player; he has been at '
             'Al-Shamal since 2023.', [dict(op='removeSpell', clubId=19775, start=START),
                                       add(10775, yr('2023'), None, YEAR)]),
    61892: (['Başakşehir', 'Botafogo'], 'The roster\'s Rafael at Real Salt Lake is another player; '
            'this Rafael played for Botafogo 2021-2024.', [dict(op='removeSpell', clubId=6643, start=START),
                                                          add(9030, yr('2021'), yr('2024'), YEAR)]),
    193867: (['Empoli', 'Sampdoria'], 'The roster\'s Liam Henderson at Falkirk is another player; he has been at '
             'Sampdoria since 2025.', [dict(op='removeSpell', clubId=1191, start=START),
                                       add(1038, yr('2025'), None, YEAR)]),
    220722: ([], 'The roster\'s Eduardo at V-Varen Nagasaki cannot be tied to this Eduardo (Estoril, Braga, '
             'Xanthi); the stop is removed.', [dict(op='removeSpell', clubId=23581, start=START)]),
    # Union Saint-Gilloise (3948/6571) and Antwerp (1096/10625) are each two rows.
    157396: (['Union'], SAME_CLUB, undo(157396, 3948, 6571)),
    684159: (['Union'], SAME_CLUB, undo(684159, 3948, 6571)),
    486039: (['Union'], SAME_CLUB, undo(486039, 3948, 6571)),
    502247: (['Union'], SAME_CLUB, undo(502247, 3948, 6571)),
    592403: (['Union'], SAME_CLUB, undo(592403, 3948, 6571)),
    428920: (['Union'], SAME_CLUB, undo(428920, 3948, 6571)),
    338637: (['Antwerp'], SAME_CLUB, undo(338637, 1096, 10625)),
    185245: (['Krasnodar'], WIKI_DISAGREES.format('Krasnodar'), undo(185245, 16704, 1829)),
    373374: (['Akhmat'], WIKI_DISAGREES.format('Akhmat Grozny (on loan at Rodina)'), undo(373374, 3725, 8024)),
    617679: (['Gil Vicente'], WIKI_DISAGREES.format('Gil Vicente'), undo(617679, 2424, 2425)),
    # Olympiacos bought Maffeo from Mallorca and loaned him to Valencia the same summer.
    251876: (['Mallorca', 'Olympiacos', 'Valencia'], 'Mallorca -> Olympiacos -> Valencia on loan (summer 2026).',
             [dict(op='removeTransfer', eventId='season:251876:2026:237:1049'),
              dict(op='removeSpell', clubId=1049, start=START),
              add(683, START, START), add(1049, START),
              season_move(251876, 237, 683), season_move(251876, 683, 1049)]),
    # Clubs the first pass left out as unclear: transfers in the database show 1000002524 is
    # Al Jazira of Abu Dhabi (Lanzini, Kosanović) and 1000000161 Al Wahda of Abu Dhabi
    # (Pizzi, Allan, Matheus Pereira). Al-Diriyah (Saudi Arabia) is not in the database.
    258626: (['Fenerbahçe', 'Jazira'], 'Fenerbahçe -> Al Jazira (Sporx 333).',
             [add(1000002524, START), season_move(258626, 36, 1000002524)]),
    546543: (['Al-Hilal', 'Diriyah'], 'Al-Hilal -> Al-Diriyah on loan (Sporx 246).',
             [dict(op='addClub', clubId=DIRIYAH, canonicalKey='reviewed:summer-2026:al_diriyah',
                   name='Al-Diriyah', country='Saudi Arabia'),
              dict(op='updateSpell', clubId=1114, start='2025-08-09', set=dict(end_date=START)),
              add(DIRIYAH, START), season_move(546543, 1114, DIRIYAH)]),
    174733: (['PAOK', 'Diriyah'], 'Al-Diriyah 2025-2026 between PAOK and Al-Fayha (from the day PAOK ends).',
             [add(DIRIYAH, '2025-07-23', START, YEAR)]),
    36139: (['Fenerbahçe', 'Wahda', 'NEC'], 'Fenerbahçe -> Al Wahda (2025-08-08, the transfer already in the '
            'database) -> NEC (Sporx 130).',
            [add(1000000161, '2025-08-08', START), season_move(36139, 1000000161, 467)]),
    203496: (['Betis', 'Jazira', 'Abha'], 'Al Jazira 2024-2026 between Betis and Abha (from the day Betis ends); the Al Jazira link was '
             'stored as Universitatea Craiova (id 2524, the offset collision).',
             [add(1000002524, '2024-08-25', START, YEAR), dict(op='removePlayerClub', clubId=2524)]),
    # Gaari joined Abha in 2025, after a season at Al-Hazem.
    328455: (['Al-Hazem', 'Abha'], 'Al-Hazem 2024-2025, Abha since 2025.',
             [add(9131, yr('2024'), yr('2025'), YEAR),
              dict(op='updateSpell', clubId=1000040039, start=START, set=dict(start_date=yr('2025'), confidence=YEAR))]),
}


def build(database=DB):
    con = sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    mismatch = offset_mismatch()
    clubs = {r['id']: r for r in con.execute('SELECT * FROM clubs')}
    used = Counter(r[0] for r in con.execute('SELECT club_id FROM career_spells'))
    pool = {i: c for i, c in clubs.items() if c['entity_type'] == 'SENIOR' and c['gameplay_eligible']
            and not YOUTH.search(norm(c['name']))}

    def cid(i):
        o = i - OFFSET
        return o if i >= OFFSET and i not in mismatch and o in clubs else i

    def resolve(row):
        if row['label'] in CLUB:
            return CLUB[row['label']]
        if YOUTH.search(norm(row['label'])) or norm(row['label']).startswith('jong '):
            return None
        for text in filter(None, [row['title'], row['label']]):
            want = tokens(text)
            scored = sorted(((len(want & tokens(c['name'])) / len(want | tokens(c['name'])), i)
                             for i, c in pool.items() if want & tokens(c['name'])), reverse=True)
            if not scored or scored[0][0] < .5:
                continue
            best = [i for s, i in scored if s == scored[0][0]]
            # Duplicate rows of one club (PSG twice): the one careers use.
            if len({norm(clubs[i]['name']) for i in best}) == 1:
                return max(best, key=lambda i: used[i])
            if len(best) == 1:
                return best[0]
        return None

    wiki = {p['playerId']: p for p in json.loads(WIKI.read_text(encoding='utf-8'))['players']}
    review = json.loads(REVIEW.read_text(encoding='utf-8'))
    spells = defaultdict(list)
    for r in con.execute('SELECT * FROM career_spells ORDER BY player_id,start_date,sequence'):
        spells[r['player_id']].append(r)
    links = defaultdict(set)
    for r in con.execute('SELECT player_id,club_id FROM player_clubs'):
        links[r['player_id']].add(cid(r['club_id']))
    names = dict(con.execute('SELECT id,name FROM players'))

    players, unresolved = {}, []
    for pid, (must, reason, ops) in MANUAL.items():
        rows = wiki[pid].get('senior') or []
        for club in must:
            if not any(same_club(club, r['label']) or same_club(club, r['title'] or '') for r in rows):
                raise ValueError(f'{names[pid]}: infobox does not name {club}')
        players[pid] = dict(playerId=pid, name=names[pid], wiki=dict(title=wiki[pid]['title'], revid=wiki[pid]['revid']),
                            reason=reason, ops=list(ops))

    excluded = set(review['excludedPlayerIds'])
    for move in review['players']:
        pid = move['playerId']
        w = wiki.get(pid)
        if pid in excluded or pid in MANUAL or not w or not w.get('senior'):
            continue
        rows = w['senior']
        left = [i for i, r in enumerate(rows) if same_club(r['label'], move['fromClub'])
                or same_club(r['title'] or '', move['fromClub'])]
        joined = [i for i, r in enumerate(rows) if same_club(r['label'], move['toClub'])
                  or same_club(r['title'] or '', move['toClub'])]
        if not left or not joined:
            continue
        have = {cid(s['club_id']) for s in spells[pid]}
        since = int(([s for s in spells[pid] if s['club_id'] == move['fromClubId']][-1]['start_date'] or '0')[:4])
        ops = []
        # A year-precision stop starts in the summer of its year, or when the stop before it ends.
        previous = [s for s in spells[pid] if s['club_id'] == move['fromClubId']][-1]['end_date'] or ''
        for r in rows[left[-1] + 1:joined[-1]]:
            start = r['years'][:4]
            if not start.isdigit() or int(start) < since or same_club(r['label'], move['fromClub']) \
                    or same_club(r['label'], move['toClub']):
                continue
            club = resolve(r)
            if club is None:
                if not YOUTH.search(norm(r['label'])) and not norm(r['label']).startswith('jong '):
                    unresolved.append(dict(playerId=pid, name=move['name'], years=r['years'], club=r['label']))
                continue
            if cid(club) in have:
                continue
            end = r['years'][5:9] if len(r['years']) >= 9 else start if not r['years'].endswith('-') else None
            begin = max(yr(start), previous) if previous[:4] == start else yr(start)
            ops.append(add(club, begin, yr(end), YEAR))
            previous = yr(end) or ''
            have.add(cid(club))
        if ops:
            players[pid] = dict(playerId=pid, name=move['name'], wiki=dict(title=w['title'], revid=w['revid']),
                                reason='Clubs between ' + move['fromClub'] + ' and ' + move['toClub'] +
                                       ' from the infobox (mostly loans).', ops=ops)

    # Links for the grid modes: every club a reviewed stop adds, plus the 2026
    # stops already applied without one.
    removed = {(pid, op['clubId']) for pid, p in players.items() for op in p['ops'] if op['op'] == 'removeSpell'}
    wanted = defaultdict(set)
    for move in review['players']:
        if move['playerId'] not in excluded:
            wanted[move['playerId']].add(move['toClubId'])
    for pid, p in players.items():
        for op in p['ops']:
            if op['op'] == 'addSpell':
                wanted[pid].add(op['clubId'])
    for pid, wanted_clubs in sorted(wanted.items()):
        for club in sorted(wanted_clubs):
            if (pid, club) in removed or cid(club) in links[pid]:
                continue
            links[pid].add(cid(club))
            entry = players.setdefault(pid, dict(playerId=pid, name=names[pid], wiki=None,
                                                 reason='Grid link for a reviewed 2026 club.', ops=[]))
            entry['ops'].append(dict(op='addPlayerClub', clubId=club, source=LINK))
    for pid, club in sorted(removed):
        links_rows = con.execute('SELECT source FROM player_clubs WHERE player_id=? AND club_id=?', (pid, club)).fetchone()
        if links_rows and links_rows[0].startswith('roster:'):
            players[pid]['ops'].append(dict(op='removePlayerClub', clubId=club))
    out = sorted(players.values(), key=lambda p: p['playerId'])
    return dict(id=REVISION, baseRevision=BASE, builtUtc=BUILT,
                scope='Corrections to the summer-2026 moves from English Wikipedia infoboxes.',
                sources=dict(wikipedia=dict(evidence='tools/data_platform_v4/patches/' + WIKI.name,
                                            fetchedUtc=json.loads(WIKI.read_text(encoding='utf-8'))['fetchedUtc'])),
                counts=dict(players=len(out), operations=dict(Counter(op['op'] for p in out for op in p['ops'])),
                            unresolvedMiddleClubs=len(unresolved)),
                unresolvedMiddleClubs=unresolved, players=out)


def encode(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    if args.check:
        assert OUT.read_text(encoding='utf-8') == encode(data), 'Review drift'
    else:
        OUT.write_text(encode(data), encoding='utf-8', newline='\n')
    print(json.dumps(data['counts'], ensure_ascii=False, indent=1))
