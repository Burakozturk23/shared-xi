"""Bounded historical UEFA metrics; never approves legacy database statistics."""
import collections
import json
import pathlib
import unicodedata

SOURCE = 'https://editorial.uefa.com/resources/0282-18407aecf6fe-cb82de053b1e-1000/ucl_202223_all-time_md13.pdf'

# Club countries as shown in the game; codes are UEFA's published three-letter codes.
COUNTRY_CODES = {'ALB': 'Arnavutluk', 'ARM': 'Ermenistan', 'AUT': 'Avusturya', 'AZE': 'Azerbaycan', 'BEL': 'Belçika',
                 'BIH': 'Bosna-Hersek', 'BLR': 'Belarus', 'BUL': 'Bulgaristan', 'CRO': 'Hırvatistan', 'CYP': 'Kıbrıs',
                 'CZE': 'Çekya', 'DEN': 'Danimarka', 'ENG': 'İngiltere', 'ESP': 'İspanya', 'EST': 'Estonya',
                 'FIN': 'Finlandiya', 'FRA': 'Fransa', 'FRO': 'Faroe Adaları', 'GEO': 'Gürcistan', 'GER': 'Almanya',
                 'GRE': 'Yunanistan', 'HUN': 'Macaristan', 'IRL': 'İrlanda', 'ISL': 'İzlanda', 'ISR': 'İsrail',
                 'ITA': 'İtalya', 'KAZ': 'Kazakistan', 'LTU': 'Litvanya', 'LUX': 'Lüksemburg', 'LVA': 'Letonya',
                 'MDA': 'Moldova', 'MKD': 'Kuzey Makedonya', 'MLT': 'Malta', 'NED': 'Hollanda', 'NIR': 'Kuzey İrlanda',
                 'NOR': 'Norveç', 'POL': 'Polonya', 'POR': 'Portekiz', 'ROU': 'Romanya', 'RUS': 'Rusya',
                 'SCO': 'İskoçya', 'SRB': 'Sırbistan', 'SUI': 'İsviçre', 'SVK': 'Slovakya', 'SVN': 'Slovenya',
                 'SWE': 'İsveç', 'TUR': 'Türkiye', 'UKR': 'Ukrayna', 'WAL': 'Galler'}
# Clubs with at least this many European Cup matches form the club pool.
CLUB_MIN_PLAYED = 20


def key(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', value.lower()) if c.isalnum())


def gate(values):
    distinct = len({r['value'] for r in values})
    pairs = (len(values)**2 - sum(n*n for n in collections.Counter(r['value'] for r in values).values())) // 2
    assert len(values) >= 120 and distinct >= 7 and pairs >= 50
    return distinct, pairs


def load_clubs(path=None):
    """All-time club ranking, pages 2-6 of the same hash-pinned handbook."""
    path = path or pathlib.Path(__file__).with_name('uefa_2023_clubs.json')
    source = json.loads(path.read_text(encoding='utf-8'))
    assert source['sourceUrl'] == SOURCE and source['edition'] == '2022/23'
    assert source['scopeId'] == 'uefa-handbook-2022-23-alltime-club-ranking' and source['sourcePages'] == [2, 3, 4, 5, 6]
    rows = source['rows']
    assert [r['position'] for r in rows] == list(range(1, len(rows) + 1))
    for r in rows:
        # The table checks itself: every transcribed row must add up.
        assert r['won'] + r['drawn'] + r['lost'] == r['played'], r
        assert r['goalsFor'] - r['goalsAgainst'] == r['goalDifference'], r
        assert r['points'] == 2 * r['won'] + r['drawn'], r
        assert r['pdfPage'] in source['sourcePages'] and r['countryCode'] in COUNTRY_CODES or r['played'] < CLUB_MIN_PLAYED
    return source


def load_metrics(players, aliases, path=None):
    path = path or pathlib.Path(__file__).with_name('uefa_2023_snapshot.json')
    source = json.loads(path.read_text())
    assert source['sourceUrl'] == SOURCE and source['edition'] == '2022/23'
    assert source['scopeId'] == 'uefa-handbook-2022-23-alltime-including-qualifying'
    assert len(source['sourceSha256']) == 64 and source['sourcePages'] == [7, 8]
    rows = source['rows']
    assert len(rows) >= 120 and len({r['playerId'] for r in rows}) == len(rows)
    for r in rows:
        p = players[r['playerId']]
        assert p['name'] == r['canonicalName'] and p['country'] == r['canonicalCountry'], r
        assert aliases[key(r['sourceName'])] == {r['playerId']}, r
        country = {'Bosnia & Herzegovina': 'Bosnia-Herzegovina', 'Ivory Coast': "Cote d'Ivoire", 'Republic of Ireland': 'Ireland'}.get(r['country'], r['country'])
        assert country == p['country'], r
        assert r['pdfPage'] in source['sourcePages'] and r['column'] in range(1, 5)
        assert isinstance(r['appearances'], int) and 70 <= r['appearances'] <= 187
        # Zero is explicitly printed in UEFA's table, not inferred from a blank.
        assert isinstance(r['goals'], int) and 0 <= r['goals'] <= 141
    metrics = {}; audit = {}
    for field, label, unit in [('appearances', 'Avrupa Kupası maçları · 2023 arşivi', 'maç'),
                                ('goals', 'Avrupa Kupası golleri · 2023 arşivi', 'gol')]:
        mid = f'uefa_ec_ucl_2023_{field}'
        values = [{'id': r['playerId'], 'value': r[field]} for r in rows]
        distinct = len({r['value'] for r in values})
        pairs = (len(values)**2 - sum(n*n for n in collections.Counter(r['value'] for r in values).values())) // 2
        assert distinct >= 7 and pairs >= 50
        metrics[mid] = {'id': mid, 'label': label, 'unit': unit, 'status': 'ready', 'gatePassed': True,
                        'sourceTable': 'uefa_2023_snapshot', 'sourceColumn': field,
                        'scopeLabel': 'Şampiyon Kulüpler Kupası / Şampiyonlar Ligi · 1955–2023 · elemeler ve play-off dahil',
                        'poolLabel': f'Bu baskıda en az 70 maça çıkmış {len(values)} doğrulanmış futbolcu',
                        'edition': '2022/23 UEFA arşivi', 'sources': [SOURCE], 'sourceSha256': source['sourceSha256'],
                        'groups': {source['scopeId']: values}, 'reason': ''}
        audit[mid] = {'gatePassed': True, 'eligibleCount': len(values), 'distinctValues': distinct,
                      'distinctPairs': pairs, 'explicitZeroCount': sum(v['value'] == 0 for v in values),
                      'sourceReviewed': True, 'edition': source['edition'], 'sourceSha256': source['sourceSha256']}
    # Goals per match, derived only from the two printed columns above.
    mid = 'uefa_ec_ucl_2023_goals_per_match'
    values = [{'id': r['playerId'], 'value': round(r['goals'] / r['appearances'], 2)} for r in rows]
    distinct, pairs = gate(values)
    metrics[mid] = {'id': mid, 'label': 'Avrupa Kupası maç başına gol · 2023 arşivi', 'unit': 'gol/maç',
                    'status': 'ready', 'gatePassed': True, 'sourceTable': 'uefa_2023_snapshot',
                    'sourceColumn': 'goals/appearances',
                    'scopeLabel': 'Şampiyon Kulüpler Kupası / Şampiyonlar Ligi · 1955–2023 · gol ÷ maç, iki basamak',
                    'poolLabel': f'Bu baskıda en az 70 maça çıkmış {len(values)} doğrulanmış futbolcu',
                    'edition': '2022/23 UEFA arşivi', 'sources': [SOURCE], 'sourceSha256': source['sourceSha256'],
                    'groups': {source['scopeId'] + ':per-match': values}, 'reason': ''}
    audit[mid] = {'gatePassed': True, 'eligibleCount': len(values), 'distinctValues': distinct,
                  'distinctPairs': pairs, 'derivedFrom': ['appearances', 'goals'], 'sourceReviewed': True}
    # Club criteria: participations, wins and goals scored.
    clubs = load_clubs(); entities = {}
    pool = [r for r in clubs['rows'] if r['played'] >= CLUB_MIN_PLAYED]
    for r in pool:
        cid = f"uefaclub:{r['position']}"
        entities[cid] = {'id': cid, 'name': r['sourceName'], 'type': 'club',
                         'country': COUNTRY_CODES[r['countryCode']], 'position': 'Kulüp'}
    for field, label, unit in [('participations', 'Avrupa Kupası katılımı · kulüpler', 'katılım'),
                               ('won', 'Avrupa Kupası galibiyetleri · kulüpler', 'galibiyet'),
                               ('goalsFor', 'Avrupa Kupası\'nda atılan goller · kulüpler', 'gol')]:
        mid = f'uefa_clubs_2023_{field}'
        values = [{'id': f"uefaclub:{r['position']}", 'value': r[field]} for r in pool]
        distinct, pairs = gate(values)
        metrics[mid] = {'id': mid, 'label': label, 'unit': unit, 'status': 'ready', 'gatePassed': True,
                        'sourceTable': 'uefa_2023_clubs', 'sourceColumn': field, 'subject': 'club',
                        'scopeLabel': 'Şampiyon Kulüpler Kupası / Şampiyonlar Ligi · 1955–2023 · elemeler dahil',
                        'poolLabel': f'Bu baskıda en az {CLUB_MIN_PLAYED} maça çıkmış {len(values)} kulüp',
                        'edition': '2022/23 UEFA arşivi', 'sources': [SOURCE], 'sourceSha256': clubs['sourceSha256'],
                        'groups': {clubs['scopeId']: values}, 'reason': ''}
        audit[mid] = {'gatePassed': True, 'eligibleCount': len(values), 'distinctValues': distinct,
                      'distinctPairs': pairs, 'sourceReviewed': True, 'edition': clubs['edition'],
                      'sourceSha256': clubs['sourceSha256']}
    return metrics, audit, entities
