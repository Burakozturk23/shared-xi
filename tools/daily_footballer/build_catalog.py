#!/usr/bin/env python3
"""Build an explicitly dated gameplay snapshot; never edits career SQLite data.

Usage: python3 tools/daily_footballer/build_catalog.py --source-dir <saved ESPN rosters>
Use --fetch to download current public roster responses into that directory first.
Review the resulting diff before publishing a new catalog version.
"""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
TEAMS = [
    ('esp.1', 83, 'Barcelona'), ('esp.1', 86, 'Real Madrid'),
    ('eng.1', 364, 'Liverpool'), ('eng.1', 382, 'Manchester City'),
    ('eng.1', 359, 'Arsenal'), ('eng.1', 363, 'Chelsea'),
    ('eng.1', 360, 'Manchester United'),
    ('tur.1', 432, 'Galatasaray'), ('tur.1', 436, 'Fenerbahçe'),
    ('tur.1', 1895, 'Beşiktaş'), ('ger.1', 132, 'Bayern Münih'),
    ('ger.1', 124, 'Borussia Dortmund'), ('fra.1', 160, 'Paris Saint-Germain'),
    ('ita.1', 110, 'Inter'), ('ita.1', 111, 'Juventus'),
    ('ita.1', 103, 'Milan'), ('usa.1', 20232, 'Inter Miami'),
]
LEAGUES = {'esp.1': 'La Liga', 'eng.1': 'Premier League', 'tur.1': 'Süper Lig',
           'ger.1': 'Bundesliga', 'fra.1': 'Ligue 1', 'ita.1': 'Serie A', 'usa.1': 'MLS'}


def build(source_dir, date):
    players, sources, seen = [], [], set()
    for league, team, club in TEAMS:
        path = source_dir / f'{league}-{team}.json'
        raw = path.read_bytes()
        data = json.loads(raw)
        assert str(data['team']['id']) == str(team), 'Wrong source team'
        assert data['season']['year'] == 2026, 'Review the source season before updating'
        url = f'https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/teams/{team}/roster'
        sources.append(dict(club=club, url=url, season=data['season']['displayName'],
                            sha256=hashlib.sha256(raw).hexdigest()))
        for athlete in data['athletes']:
            dob = athlete.get('dateOfBirth', '')[:10]
            number = athlete.get('jersey', '')
            country = athlete.get('citizenship', '')
            position = athlete.get('position', {}).get('abbreviation')
            if not dob or not str(number).isdigit() or not country or position not in ('G', 'D', 'M', 'F'):
                continue
            birth = dt.date.fromisoformat(dob)
            age = date.year - birth.year - ((date.month, date.day) < (birth.month, birth.day))
            if not 16 <= age <= 45 or not 1 <= int(number) <= 99:
                continue
            pid = 'espn:' + athlete['id']
            if pid in seen:
                raise ValueError(f'Duplicate active roster identity: {pid}')
            seen.add(pid)
            players.append(dict(id=pid, name=athlete['displayName'],
                                aliases=list(dict.fromkeys([athlete['fullName'], athlete['shortName']])),
                                country=country, clubId=str(team), club=club, leagueId=league,
                                league=LEAGUES[league], position=position,
                                birthDate=dob, shirtNumber=int(number)))
    players.sort(key=lambda p: p['id'])
    return dict(version='2026-10-06.1', asOf=str(date),
                description='2026/27 club rosters; MLS 2026. Country follows source citizenship.',
                sources=sources, players=players)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    args.source_dir.mkdir(parents=True, exist_ok=True)
    if args.fetch:
        for league, team, _ in TEAMS:
            url = f'https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/teams/{team}/roster'
            with urllib.request.urlopen(url, timeout=40) as response:
                data = json.load(response)
            (args.source_dir / f'{league}-{team}.json').write_text(json.dumps(data, ensure_ascii=False))
    data = build(args.source_dir, dt.date(2026, 10, 6))
    target = ROOT / 'assets/data/daily_footballer_catalog.json'
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(data["players"])} complete identities, {len(data["sources"])} club sources')


if __name__ == '__main__':
    main()
