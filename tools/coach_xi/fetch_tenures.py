"""Fetch dated head-coach tenures from Wikidata into a frozen, reviewable file.

Wikidata "head coach" (P286) statements on club items carry start (P580) and
end (P582) qualifiers. The response is stored with its query, retrieval time
and SHA-256 so tools/three_modes/build_catalog.py builds offline and
reproducibly; re-run this only to refresh the source on purpose:
  python tools/coach_xi/fetch_tenures.py
"""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import urllib.parse
import urllib.request

HERE = Path(__file__).parent
OUT = HERE / 'tenures.json'
# Wikidata club item -> V4 club id (checked against V4 names in the builder).
CLUBS = {
    'Q9616': 631, 'Q8682': 418, 'Q7156': 131, 'Q1130849': 31, 'Q18656': 985, 'Q9617': 11,
    'Q50602': 281, 'Q1422': 506, 'Q1543': 5, 'Q15789': 27, 'Q18741': 148, 'Q631': 46,
    'Q483020': 583, 'Q41420': 16, 'Q6601875': 36, 'Q495299': 141, 'Q172567': 114,
    'Q192641': 449, 'Q131499': 294, 'Q128446': 720, 'Q81888': 610,
}
QUERY = """SELECT ?club ?coach ?coachLabel ?start ?end ?statement WHERE {
  VALUES ?club { %s }
  ?club p:P286 ?statement . ?statement ps:P286 ?coach .
  OPTIONAL { ?statement pq:P580 ?start } OPTIONAL { ?statement pq:P582 ?end }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
} ORDER BY ?club ?start""" % ' '.join('wd:' + q for q in CLUBS)


def main():
    url = 'https://query.wikidata.org/sparql?' + urllib.parse.urlencode({'query': QUERY, 'format': 'json'})
    request = urllib.request.Request(url, headers={'User-Agent': 'LinkballDataBuild/1.0 (open-data research)'})
    raw = urllib.request.urlopen(request, timeout=90).read()
    rows = json.loads(raw)['results']['bindings']
    value = lambda r, k: r[k]['value'] if k in r else None
    tenures = sorted(({
        'clubQid': value(r, 'club').rsplit('/', 1)[1],
        'clubId': CLUBS[value(r, 'club').rsplit('/', 1)[1]],
        'coachQid': value(r, 'coach').rsplit('/', 1)[1],
        'coach': value(r, 'coachLabel'),
        'start': (value(r, 'start') or '')[:10] or None,
        'end': (value(r, 'end') or '')[:10] or None,
        'statement': value(r, 'statement').rsplit('/', 1)[1],
    } for r in rows), key=lambda t: (t['clubId'], t['start'] or '', t['coach']))
    doc = {
        'source': {'provider': 'wikidata', 'endpoint': 'https://query.wikidata.org/sparql', 'query': QUERY,
                   'retrievedAt': datetime.now(timezone.utc).isoformat(timespec='seconds'),
                   'sha256': hashlib.sha256(raw).hexdigest(), 'license': 'CC0'},
        'clubs': CLUBS,
        'tenures': tenures,
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    print(len(tenures), 'tenures')


if __name__ == '__main__':
    main()
