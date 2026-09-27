#!/usr/bin/env python3
"""Build a reproducible art-production queue from the bundled V4 snapshot.
Does not change runtime data, eligibility, or the portrait catalog.
"""
import hashlib
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / 'assets/runtime/linkball_game_data_v4.sqlite'
OUT = ROOT / 'docs/portraits'
# Editorial order, explicitly checked against the bundled database.
FIRST = [8198, 28003, 342229, 418560, 68290, 148455, 38253, 132098,
         371998, 581678, 937958, 18922, 27992, 88755, 401923, 68863,
         28396, 36139, 39152, 126414, 861410, 340879, 58088, 258626, 4188]
SECOND = [3373, 3455, 3111, 3924, 4673, 433177, 568177, 598577,
          683840, 845654, 411295, 17259, 108390, 25557, 139208,
          161056, 53622, 240306, 200512, 288230, 125781, 44352,
          56416, 35664, 192565]
BIG = {418, 131, 281, 31, 985, 11, 631, 148, 27, 16, 46, 506, 5,
       583, 6195, 294, 720, 234, 336, 244}
TURKEY = {36, 141, 114, 449}


def build():
    c = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
    c.row_factory = sqlite3.Row
    clubs = {r['id']: dict(r) for r in c.execute('SELECT * FROM clubs')}
    assert BIG | TURKEY <= clubs.keys()
    links = {}
    for r in c.execute('SELECT player_id, club_id FROM player_clubs WHERE trust >= 1'):
        links.setdefault(r['player_id'], set()).add(r['club_id'])
    players = {}
    for raw in c.execute('SELECT * FROM players WHERE playable=1 AND answer_eligible=1'):
        p = dict(raw)
        career = links.get(p['id'], set())
        major = career & BIG
        tr = career & TURKEY
        p['major_club_ids'] = sorted(major)
        p['turkish_club_ids'] = sorted(tr)
        p['turkey_priority'] = bool(tr) or p['country'] == 'Türkiye'
        # Editorial heuristic; not observed user frequency or a probability.
        p['portrait_score'] = round((p['selection_score'] or 0)
            + 3 * min(len(major), 4) + 5 * bool(tr), 2)
        players[p['id']] = p
    selected = []
    reasons = {}

    def add(pid, reason):
        if pid not in players:
            raise ValueError(f'Missing/ineligible seed: {pid}')
        if pid not in selected:
            selected.append(pid)
            reasons[pid] = reason

    for pid in FIRST:
        add(pid, 'İlk paket: yıldızlar ve Türkiye odağı')
    for pid in SECOND:
        add(pid, 'İkinci paket: efsaneler, genç yıldızlar ve pozisyon dengesi')
    ranked = sorted(players.values(), key=lambda p: (-p['portrait_score'], p['id']))
    # At least 8 keepers, 15 defenders and 25 Turkey-connected players overall.
    for predicate, minimum, reason in [
        (lambda p: p['position'] == 'Goalkeeper', 8, 'Kaleci dengesi'),
        (lambda p: p['position'] == 'Defender', 15, 'Savunmacı dengesi'),
        (lambda p: p['turkey_priority'], 25, 'Türkiye bağlantısı'),
    ]:
        for p in ranked:
            if sum(predicate(players[i]) for i in selected) >= minimum:
                break
            if predicate(p) and (p['major_club_ids'] or p['turkey_priority']):
                add(p['id'], reason)
    for p in ranked:
        if len(selected) >= 100:
            break
        if p['major_club_ids'] or p['turkey_priority']:
            add(p['id'], 'Seçim puanı ve büyük kulüp kariyer bağlantıları')
    assert len(selected) == len(set(selected)) == 100
    catalog = (ROOT / 'lib/data/player_portrait_catalog.dart').read_text()
    assets = {int(i): path for i, path in re.findall(r"(\d+): '([^']+)'", catalog)}
    rows = []
    for n, pid in enumerate(selected, 1):
        p = players[pid]
        asset = assets.get(pid)
        if asset:
            assert (ROOT / asset).is_file(), asset
        rows.append(dict(priority=n, batch=(n-1)//25+1, player_id=pid,
            name=p['name'], country=p['country'], position=p['position'],
            reason=reasons[pid], selection_score=p['selection_score'],
            portrait_score=p['portrait_score'], turkey_priority=p['turkey_priority'],
            career_clubs=[dict(id=i, name=clubs[i]['name'])
                for i in sorted(set(p['major_club_ids'] + p['turkish_club_ids']))],
            status='bundled' if asset else 'awaiting_art', asset=asset,
            expected_asset=f'assets/avatars/portraits_v1/p_{pid}.webp'))
    payload = dict(schema_version=1, source_database=str(DB.relative_to(ROOT)),
        source_sha256=hashlib.sha256(DB.read_bytes()).hexdigest(),
        scope='Editorial queue based on bundled career data; not current squads or measured usage.',
        players=rows)
    OUT.mkdir(exist_ok=True)
    (OUT / 'priority_100.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
    text = ['# İlk 100 oyuncu: portre üretim sırası', '',
        'Bu liste üretim kuyruğudur; 100 görselin hazır olduğu anlamına gelmez. '
        'Şu an katalogda yalnızca Ronaldo portresi vardır. Kalan 99 görsel bekliyor.', '',
        '## Seçim yöntemi', '',
        '- İlk 50 isim editoryal olarak seçildi: tanınan yıldızlar, genç oyuncular, efsaneler ve Türkiye odağı.',
        '- Devamı: veri tabanı seçim puanı + en fazla dört büyük kulüp bağlantısı başına 3 puan + dört büyük Türk kulübü bağlantısı için 5 puan.',
        '- En az 8 kaleci, 15 savunmacı ve 25 Türkiye bağlantılı oyuncu; kategoriler örtüşebilir.',
        '- Türkiye bağlantısı: Türkiye ülke kaydı veya Fenerbahçe, Galatasaray, Beşiktaş, Trabzonspor kariyer bağlantısı.',
        '- Kulüpler geçmiş kariyer bağlantılarıdır; güncel kadro veya gerçek kullanım sıklığı iddiası yoktur.',
        '- Kimlikler V4 tablosunda mevcut ve oynanabilir; görsel hazırlanırken referans kişi ayrıca kontrol edilmelidir.', '',
        '## Üretim ve kabul', '',
        '1. Oyuncu ID, ülke ve kariyerini referans kişiyle doğrula.',
        '2. Kullanılabilir görsel kaynağından aynı stilde baş–omuz portresi hazırla; referans ve kaynak kaydı tut.',
        '3. Yüz benzerliği, saç/sakal, 32/48/64 px okunabilirlik ve ortak kadrajı gözle kontrol et.',
        '4. 384×384 WebP olarak expected_asset yoluna ekle; yalnızca hazır görselleri Dart kataloğuna kaydet.',
        '5. Flutter görsel testlerini ve cihaz kontrolünü çalıştır; ardından bu kuyruğu yeniden üret.', '',
        '**Üretim engeli:** Messi isteği görsel aracınca public-figure gerekçesiyle reddedildi. '
        'Kuyruk bu engeli aşmayı veya toplu üretim garantisini amaçlamaz. '
        'Diğer portreler için kullanılabilir bir görsel kaynağı gerekir.', '',
        '**Kimlik notu:** Burak Yilmaz (164148, Austria) Türk millî futbolcunun yerine kullanılmadı.', '',
        'Yeniden üretim: `python tool/build_portrait_priority.py`',
        f"Veri SHA-256: `{payload['source_sha256']}`", '']
    for batch in range(1, 5):
        text += [f'## Paket {batch}', '', '| Sıra | ID | Oyuncu | Pozisyon | Durum |', '| --- | --- | --- | --- | --- |']
        for p in rows:
            if p['batch'] == batch:
                status = 'Hazır' if p['status']=='bundled' else 'Görsel bekliyor'
                text.append(f"| {p['priority']} | {p['player_id']} | {p['name']} | {p['position']} | {status} |")
        text.append('')
    (OUT / 'priority_100.md').write_text('\n'.join(text))
    print(json.dumps(dict(total=len(rows), bundled=sum(r['status']=='bundled' for r in rows),
        turkey_connected=sum(r['turkey_priority'] for r in rows),
        positions={pos:sum(r['position']==pos for r in rows) for pos in ['Goalkeeper','Defender','Midfield','Attack']})))
    c.close()


if __name__ == '__main__':
    build()
