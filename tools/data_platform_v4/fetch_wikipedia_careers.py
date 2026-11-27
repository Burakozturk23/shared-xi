#!/usr/bin/env python3
"""Save English Wikipedia senior careers (infobox football biography) as evidence.

For each requested player (id, name, optional exact article title) this finds the
article, reads its infobox and keeps only what it states: each senior row's
years, club article title, club label, loan flag, apps and goals, plus the
article's revision id. Youth and national-team rows are ignored. It never writes
to the game database; apply_wikipedia_moves.py reads the saved file.

Input: a JSON list of {"playerId": 1, "name": "...", "title": optional, "hint": optional club}.
Run: py -3 tools/data_platform_v4/fetch_wikipedia_careers.py --players in.json --out out.json
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time
import unicodedata
import urllib.parse
import urllib.error
import urllib.request

API = 'https://en.wikipedia.org/w/api.php'
HEADERS = {'User-Agent': 'LinkballDataTool/1.0 (offline football data review)'}


def call(**params):
    params.update(format='json', formatversion='2')
    url = API + '?' + urllib.parse.urlencode(params)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=30) as r:
                return json.loads(r.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 5:
                raise
            time.sleep(int(e.headers.get('Retry-After') or 0) or 10 * (attempt + 1))
        finally:
            time.sleep(1)


def page(title):
    data = call(action='query', prop='revisions', rvprop='ids|content', rvslots='main', redirects='1', titles=title)
    p = data['query']['pages'][0]
    if p.get('missing'):
        return None
    rev = p['revisions'][0]
    return dict(title=p['title'], revid=rev['revid'], text=rev['slots']['main']['content'])


def infobox(text):
    start = re.search(r'\{\{\s*Infobox (?:football|soccer) biography', text, re.I)
    if not start:
        return None
    depth, i = 0, start.start()
    while i < len(text):
        if text.startswith('{{', i):
            depth, i = depth + 1, i + 2
        elif text.startswith('}}', i):
            depth, i = depth - 1, i + 2
            if depth == 0:
                return text[start.start():i]
        else:
            i += 1
    return None


def fields(box):
    """Top-level |name=value pairs; pipes inside [[...]] and {{...}} belong to the value."""
    parts, depth, start = [], 0, 0
    body = box[2:-2]
    i = 0
    while i < len(body):
        two = body[i:i + 2]
        if two in ('[[', '{{'):
            depth, i = depth + 1, i + 2
            continue
        if two in (']]', '}}'):
            depth, i = depth - 1, i + 2
            continue
        if body[i] == '|' and depth == 0:
            parts.append(body[start:i])
            start = i + 1
        i += 1
    parts.append(body[start:])
    out = {}
    for part in parts[1:]:
        if '=' in part:
            key, value = part.split('=', 1)
            out[key.strip()] = value.strip()
    return out


def clean(value):
    value = re.sub(r'<ref[^>]*/>|<ref[^>]*>.*?</ref>|<!--.*?-->', '', value, flags=re.S)
    value = re.sub(r'\{\{(?:nowrap|nobr)\|([^{}]*)\}\}', r'\1', value, flags=re.I)
    value = re.sub(r'\{\{[^{}]*\}\}', '', value)
    return value.replace('&nbsp;', ' ').replace(' ', ' ').strip()


def senior(f):
    rows = []
    numbers = sorted({int(m[1]) for k in f for m in [re.fullmatch(r'(?:clubs|years)(\d+)', k)] if m})
    for n in numbers:  # Editors sometimes skip a number (clubs5, clubs7).
        club = clean(f.get(f'clubs{n}', ''))
        link = re.search(r'\[\[([^\]|#]+)(?:\|([^\]]+))?\]\]', club)
        years = clean(f.get(f'years{n}', '')).replace('–', '-').replace('—', '-')
        rows.append(dict(years=years, title=link and link[1].strip(),
                         label=(link and (link[2] or link[1]).strip()) or re.sub(r'[\[\]→]', '', club).strip(),
                         loan='loan' in club.lower(),
                         apps=clean(f.get(f'caps{n}', '')) or None, goals=clean(f.get(f'goals{n}', '')).strip('()') or None))
    return rows


def born(value):
    m = re.search(r'(\d{4})\|(\d{1,2})\|(\d{1,2})', value)
    return m and f'{m[1]}-{int(m[2]):02d}-{int(m[3]):02d}'


def mentions(p, hint):
    """The infobox names the hint club (one of its words of 4+ letters)."""
    def plain(text):
        return ''.join(c for c in unicodedata.normalize('NFKD', text.lower()) if not unicodedata.combining(c))
    box = plain(infobox(p['text']))
    return any(w in box for w in re.findall(r'\w{4,}', plain(hint)))


def find(name, title=None, hint=None):
    """The player's article. With a hint (a club he played for), an article whose
    infobox does not name that club is someone else with the same name."""
    for t in ([title] if title else []) + [name]:
        p = page(t)
        if p and infobox(p['text']) and (not hint or mentions(p, hint)):
            return p
    query = f'{name} {hint} footballer' if hint else f'{name} footballer'
    for h in call(action='query', list='search', srsearch=query, srlimit='5')['query']['search']:
        p = page(h['title'])
        if p and infobox(p['text']) and (not hint or mentions(p, hint)):
            return p
    return None


def fetch(players):
    out = []
    for r in players:
        p = find(r['name'], r.get('title'), r.get('hint'))
        item = dict(playerId=r['playerId'], name=r['name'])
        if p:
            f = fields(infobox(p['text']))
            item.update(title=p['title'], revid=p['revid'], fullName=clean(f.get('name', '')) or None,
                        birthDate=born(f.get('birth_date', '')), currentClub=clean(f.get('currentclub', '')) or None,
                        senior=senior(f))
        out.append(item)
    return dict(source='https://en.wikipedia.org', fetchedUtc=datetime.now(timezone.utc).isoformat(timespec='seconds'),
                players=out)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--players', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    data = fetch(json.loads(Path(args.players).read_text(encoding='utf-8')))
    Path(args.out).write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    print(sum(1 for p in data['players'] if p.get('senior')), 'of', len(data['players']), 'found')
