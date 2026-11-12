#!/usr/bin/env python3
"""Review list of summer-2026 moves missing from careers and transfers.

Read-only. Two sources, both saved in patches/ before this runs:
- roster snapshots (worldcup26.ir club rosters, synced 2026-09-29): the club
  each listed player was at; player_clubs already has it, career_spells and
  transfers stop before the summer 2026 window;
- a Sporx "Dünyada biten transferler" gallery (fetch_sporx_transfers.py):
  club left, club joined and fee text per move.

Each move becomes one new final career stop and, when the club he left is
certain, one transfer, both dated to the season (2026-07-01, season precision),
never to a day the sources do not give. apply_current_clubs.py applies the file
after the owner's review; the owner's exclusions survive a rebuild.

Rules:
- roster moves: the player has a career, one roster club, the club is not yet in
  his career, his last stop is closed and ended before the roster date. The
  transfer (club left -> club joined) is added only when the last stop ended in
  2026 or Sporx names the same club left: an older end means a move in between
  may be missing (Tadić: Fenerbahçe 2025, Al-Wahda, then NEC).
- Sporx moves the rosters do not have: the Sporx player matches one database
  player by name and the club he left is his last career stop; the club joined
  resolves to one senior club. An open last stop is closed at the season start.
- a roster move Sporx contradicts (another club joined) is left out and listed.

Run: py -3 tools/data_platform_v4/build_current_club_review.py [--check]
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
PATCHES = ROOT / 'tools/data_platform_v4/patches'
OUT = PATCHES / 'current-clubs-2026-11-11.json'
SPORX = PATCHES / 'sporx-transfers-2026-summer.json'
REVISION = 'v4-2026-11-11.1'
SEASON_START = '2026-07-01'  # The summer 2026 window; stored with season precision.
CERTAIN_FROM = '2026-01-01'  # A last stop ending after this is the club he left.
ROSTER_SYNCED = '2026-09-29'
OFFSET = 1_000_000_000

# Sporx writes some clubs in Turkish or short; database names are English.
EXONYM = {'marsilya': 'marseille', 'olimpik': 'olympique', 'atina': 'athens', 'munih': 'munich',
          'kopenhag': 'copenhagen', 'lizbon': 'lisbon', 'prag': 'prague', 'wolves': 'wolverhampton',
          'spurs': 'tottenham', 'man': 'manchester', 'psg': 'paris saint germain', 'hamburg': 'hamburger',
          'gladbach': 'monchengladbach', 'atletico madrid': 'atletico de madrid', 'inter': 'inter milan',
          'betis': 'real betis', 'vitoria sc': 'vitoria guimaraes',
          'leverkusen': 'bayer leverkusen', 'salzburg': 'red bull salzburg', 'fenerbahce': 'fenerbahce',
          'basaksehir': 'basaksehir', 'leganes': 'leganes'}
STOP = {'fc', 'cf', 'sc', 'ac', 'afc', 'club', 'football', 'calcio', 'de', 'cd', 'sd', 'ud', 'sk', 'jk', 'as',
        'ss', 'us', 'fk', 'saudi', 'the', 'and', 'kv', 'rc', 'ogc', 'losc', 'acf', 'bc', 'cp', 'sl', 'sv', 'vfb',
        'vfl', 'tsg', 'al', '1', '04', '05', '1899', '1913', '1907', 'hotspur', 'clube', 'kulubu', 'spor', 'cfc',
        'balompie', 'ssc'}
YOUTH = re.compile(r'\b(u\d\d|s\d\d|m \d\d|ii|b|youth|reserves?|academy|juniors? b)\b')


def norm(s):
    s = (s or '').replace('İ', 'i').replace('I', 'ı').casefold()
    s = s.translate(str.maketrans({'ı': 'i', 'ø': 'o', 'ł': 'l', 'đ': 'd', 'ð': 'd', 'æ': 'ae', 'œ': 'oe', 'ß': 'ss'}))
    s = ''.join(x for x in unicodedata.normalize('NFKD', s) if not unicodedata.combining(x))
    return re.sub(r'\s+', ' ', re.sub('[^a-z0-9 ]', ' ', s)).strip()


def tokens(name):
    n = norm(name)
    for a, b in EXONYM.items():
        n = re.sub(r'\b' + a + r'\b', b, n)
    t = set(n.split())
    return (t - STOP) or t


def same_club(a, b):
    return bool(tokens(a) & tokens(b))


def offset_mismatch():
    data = json.loads((ROOT / 'tools/data_platform_v4/club_offset_mismatch.json').read_text(encoding='utf-8'))
    return {x['id'] for x in data['ids']}


def rejected_roster_rows():
    """(playerId, clubId) roster rows Wikipedia showed to be another player with the same name."""
    path = PATCHES / 'wikipedia-moves-2026-11-12.json'
    if not path.exists():
        return set()
    return {(p['playerId'], op['clubId']) for p in json.loads(path.read_text(encoding='utf-8'))['players']
            for op in p['ops'] if op['op'] == 'removeSpell' and op['start'] == SEASON_START}


def roster_rows():
    """(playerId, clubId) -> the roster row that placed the player at the club."""
    rows = {}
    for path in sorted(PATCHES.glob('roster*-2026-09-29-*.json')):
        for r in json.loads(path.read_text(encoding='utf-8')):
            if r.get('playerId') and r.get('clubId'):
                rows.setdefault((r['playerId'], r['clubId']), r)
    return rows


def build(database=DB, sporx_path=SPORX):
    con = sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    mismatch = offset_mismatch()
    clubs = {r['id']: r for r in con.execute('SELECT * FROM clubs')}
    senior = {i: c for i, c in clubs.items() if c['entity_type'] == 'SENIOR' and not YOUTH.search(norm(c['name']))}

    def cid(i):
        o = i - OFFSET
        return o if i >= OFFSET and i not in mismatch and o in clubs else i

    def resolve(name):
        """The senior club a Sporx name means: best token overlap, then fame."""
        want = tokens(name)
        scored = []
        for i, c in senior.items():
            have = tokens(c['name'])
            if want & have:
                scored.append((len(want & have) / len(want | have), c['popularity_seed'] or 0, -i, i))
        scored.sort(reverse=True)
        # Two clubs that fit equally well (Vitória Setúbal, Vitória Guimarães) stay unresolved.
        if not scored or scored[0][0] < .5 or len(scored) > 1 and scored[1][0] == scored[0][0]:
            return None
        return scored[0][3]

    names = {r['id']: r for r in con.execute('SELECT id,name,selection_rank FROM players')}
    by_name = defaultdict(set)
    for r in con.execute('SELECT player_id,alias FROM player_aliases'):
        by_name[norm(r['alias'])].add(r['player_id'])
    for p in names.values():
        by_name[norm(p['name'])].add(p['id'])
    links = defaultdict(set)
    roster = defaultdict(set)
    for r in con.execute('SELECT player_id,club_id,source FROM player_clubs'):
        links[r['player_id']].add(r['club_id'])
        if r['source'].startswith('roster:worldcup26'):
            roster[r['player_id']].add(r['club_id'])
    spells = defaultdict(list)
    for r in con.execute('SELECT * FROM career_spells ORDER BY player_id,start_date,sequence'):
        spells[r['player_id']].append(r)
    moved_to = defaultdict(set)
    for r in con.execute('SELECT player_id,to_club_id FROM transfers'):
        moved_to[r['player_id']].add(cid(r['to_club_id']))

    def last_stop(pid):
        return max(spells[pid], key=lambda s: (s['start_date'] or '', s['sequence']))

    # Sporx moves by database player: the club he left must be one of his clubs.
    sporx = json.loads(Path(sporx_path).read_text(encoding='utf-8'))
    said = {}
    unmatched = Counter()
    for e in sporx['entries']:
        fit = [p for p in by_name.get(norm(e['name']), ())
               if any(same_club(clubs[c]['name'], e['fromClub']) for c in links[p] | {s['club_id'] for s in spells.get(p, ())})]
        if len(fit) == 1:
            said[fit[0]] = e
        else:
            unmatched['player_not_found' if not fit else 'player_ambiguous'] += 1

    def entry(pid, last, to, source, fee=None, sporx_n=None, transfer=True, close_last=False):
        p = names[pid]
        return dict(playerId=pid, name=p['name'], rank=p['selection_rank'],
                    fromClubId=last['club_id'], fromClub=clubs[last['club_id']]['name'],
                    fromEnd=last['end_date'] or None, toClubId=to, toClub=clubs[to]['name'],
                    source=source, sporxEntry=sporx_n, fee=fee or None,
                    transfer=transfer, closeLastStop=close_last)

    evidence = roster_rows()
    rejected = rejected_roster_rows()
    skipped, players, conflicts = Counter(), [], []
    for pid in sorted(roster):
        if not spells.get(pid):
            skipped['roster:no_career'] += 1
            continue
        if len(roster[pid]) != 1:
            skipped['roster:several_roster_clubs'] += 1
            continue
        club = next(iter(roster[pid]))
        if (pid, club) in rejected:
            skipped['roster:another_player_same_name'] += 1
            continue
        if cid(club) in {cid(s['club_id']) for s in spells[pid]} or cid(club) in moved_to[pid]:
            skipped['roster:club_already_in_career'] += 1
            continue
        last = last_stop(pid)
        if (last['start_date'] or '') >= SEASON_START:
            skipped['roster:career_already_after_summer_2026'] += 1
            continue
        if clubs[club]['entity_type'] != 'SENIOR':
            skipped['roster:not_senior_club'] += 1
            continue
        e = said.get(pid)
        if e and not same_club(clubs[club]['name'], e['toClub']):
            conflicts.append(dict(playerId=pid, name=names[pid]['name'], rosterClub=clubs[club]['name'],
                                  sporx=f"{e['fromClub']} -> {e['toClub']}", sporxEntry=e['n']))
            skipped['roster:sporx_names_another_club'] += 1
            continue
        confirmed = bool(e and same_club(clubs[last['club_id']]['name'], e['fromClub']))
        if not last['end_date'] and not confirmed:
            # An open last stop: when the player left it is unknown.
            skipped['roster:open_last_stop'] += 1
            continue
        if last['end_date'] and last['end_date'] > ROSTER_SYNCED:
            skipped['roster:last_stop_ends_after_roster_date'] += 1
            continue
        row = evidence.get((pid, club), {})
        players.append(dict(entry(pid, last, club, 'roster' + ('+sporx' if e else ''),
                                  fee=e and e['fee'], sporx_n=e and e['n'],
                                  transfer=confirmed or (last['end_date'] or '') >= CERTAIN_FROM,
                                  close_last=not last['end_date']),
                            league=row.get('league'), lastSyncedAt=row.get('lastSyncedAt')))
    done = {r['playerId'] for r in players} | {c['playerId'] for c in conflicts}
    for pid, e in sorted(said.items()):
        if pid in done or pid in roster and len(roster[pid]) == 1:
            continue
        if not spells[pid]:
            skipped['sporx:no_career'] += 1
            continue
        last = last_stop(pid)
        to = resolve(e['toClub'])
        if to is None:
            skipped['sporx:club_joined_unresolved'] += 1
            continue
        if same_club(clubs[last['club_id']]['name'], e['toClub']) or cid(to) == cid(last['club_id']):
            skipped['sporx:already_at_club_joined'] += 1
            continue
        if not same_club(clubs[last['club_id']]['name'], e['fromClub']):
            skipped['sporx:club_left_is_not_last_stop'] += 1
            continue
        if (last['start_date'] or '') >= SEASON_START or (last['end_date'] or '') > ROSTER_SYNCED:
            skipped['sporx:career_already_after_summer_2026'] += 1
            continue
        players.append(entry(pid, last, to, 'sporx', fee=e['fee'], sporx_n=e['n'], close_last=not last['end_date']))
    players.sort(key=lambda r: (r['rank'] or 10**9, r['playerId']))
    return dict(
        id=REVISION,
        scope='Add each summer-2026 move as the final career stop (from 2026-07-01, season precision) and, '
              'when the club left is certain, one summer-2026 transfer. An open last stop the sources '
              'close ends at 2026-07-01. No other existing row changes.',
        sources=dict(
            roster=dict(provider='worldcup26.ir club rosters', syncedAt=ROSTER_SYNCED,
                        evidence='tools/data_platform_v4/patches/roster*-2026-09-29-*.json'),
            sporx=dict(page=sporx['source'], fetchedUtc=sporx['fetchedUtc'], entries=len(sporx['entries']),
                       evidence='tools/data_platform_v4/patches/' + Path(sporx_path).name)),
        seasonStart=SEASON_START,
        excludedPlayerIds=[],
        counts=dict(players=len(players), famous=sum(1 for r in players if (r['rank'] or 10**9) <= 5000),
                    bySource=dict(Counter(r['source'] for r in players)),
                    transfers=sum(1 for r in players if r['transfer']),
                    closedLastStops=sum(1 for r in players if r['closeLastStop']),
                    sporxUnmatched=dict(unmatched), skipped=dict(sorted(skipped.items()))),
        conflicts=conflicts,
        players=players)


def encode(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    if OUT.exists():
        data['excludedPlayerIds'] = json.loads(OUT.read_text(encoding='utf-8'))['excludedPlayerIds']
    if args.check:
        assert OUT.read_text(encoding='utf-8') == encode(data), 'Review drift'
    else:
        OUT.write_text(encode(data), encoding='utf-8', newline='\n')
    print(json.dumps(data['counts'], ensure_ascii=False, indent=1))
