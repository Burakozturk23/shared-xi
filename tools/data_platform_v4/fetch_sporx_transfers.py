#!/usr/bin/env python3
"""Save a Sporx "Dünyada biten transferler" gallery as a reviewable snapshot.

The gallery page loads its entries five at a time from galeri_dikey_load.php;
this reads them all (about one request per five entries, 0.7 s apart) and keeps
only what each entry states: player, club left, club joined, position, fee
text and the entry image's upload date (the closest thing to an announcement
date the page gives). It never writes to the game database.

Run (summer 2026):
  py -3 tools/data_platform_v4/fetch_sporx_transfers.py \
     --gallery 80116 --out tools/data_platform_v4/patches/sporx-transfers-2026-summer.json
"""
import argparse
from datetime import datetime, timezone
import html
import json
from pathlib import Path
import re
import time
import urllib.request

LOAD = 'https://www.sporx.com/ekstra/_ajax/galeri_dikey_load.php?id={gallery}&order={order}'
PAGE = 'https://www.sporx.com/futbol/ekstra/dunyada-biten-transferler-2026-yaz-transfer-donemi-SXGLQ80116SXQ'
ENTRY = re.compile(r'<span>(\d+)</span>.*?<h6>(.*?)</h6>.*?story-desc">(.*?)</div>.*?<img src="([^"]*)"', re.S)


def parse(text, items):
    for m in ENTRY.finditer(text):
        desc = re.sub(r'</?(?:span|strong|b|p)(?:\s[^>]*)?>', '', html.unescape(m[3])).replace(' ', ' ')
        fields = {k.strip().lower(): v.strip() for k, v in re.findall(r'([^:<>\n\t]+):\s*([^<]*)', desc)}
        day = re.search(r'/img/(\d{4})/(\d{2})/(\d{2})/', m[4])
        items[int(m[1])] = dict(n=int(m[1]), name=html.unescape(m[2]).strip(),
                                fromClub=fields.get('eski takımı'), toClub=fields.get('yeni takımı'),
                                position=fields.get('mevki'), fee=fields.get('bonservis'),
                                imageDate='-'.join(day.groups()) if day else None)


def fetch(gallery, page):
    items, order = {}, 1
    while True:
        request = urllib.request.Request(LOAD.format(gallery=gallery, order=order), headers={
            'User-Agent': 'Mozilla/5.0', 'X-Requested-With': 'XMLHttpRequest', 'Referer': page})
        data = json.loads(urllib.request.urlopen(request, timeout=30).read().decode('utf-8'))
        if not data.get('html'):
            break
        before = len(items)
        parse(data['html'], items)
        if len(items) == before:
            break
        order += 5
        time.sleep(0.7)
    entries = [items[k] for k in sorted(items, reverse=True)
               if items[k]['name'] and items[k]['fromClub'] and items[k]['toClub']]
    return dict(source=page, gallery=gallery, fetchedUtc=datetime.now(timezone.utc).isoformat(timespec='seconds'),
                entries=entries)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--gallery', default='80116')
    parser.add_argument('--page', default=PAGE)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    data = fetch(args.gallery, args.page)
    Path(args.out).write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    print(len(data['entries']), 'entries')
