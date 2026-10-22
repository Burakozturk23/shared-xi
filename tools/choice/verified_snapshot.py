"""Bounded historical UEFA metrics; never approves legacy database statistics."""
import collections
import json
import pathlib
import unicodedata

SOURCE = 'https://editorial.uefa.com/resources/0282-18407aecf6fe-cb82de053b1e-1000/ucl_202223_all-time_md13.pdf'

def key(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', value.lower()) if c.isalnum())


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
    return metrics, audit
