#!/usr/bin/env python3
"""Check source hashes, crop bounds, player identities and purchasable portraits."""
import hashlib
import json
import re
import sqlite3
import struct
from pathlib import Path
from generate_catalog import ROOT

manifest = json.loads(Path(__file__).with_name('manifest.json').read_text())
catalog = json.loads((ROOT / 'functions/config/store_collection.json').read_text())
for source in manifest['sources'].values():
    data = (ROOT / source['asset']).read_bytes()
    assert hashlib.sha256(data).hexdigest() == source['sha256']
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert list(struct.unpack('>II', data[16:24])) == source['size']
keys = {p['key'] for p in manifest['portraits']}
assert len(keys) == len(manifest['portraits']) == 216
with sqlite3.connect(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite') as db:
    for p in manifest['portraits']:
        if p['playerId'] is not None:
            assert db.execute('SELECT name FROM players WHERE id=?', (p['playerId'],)).fetchone() == (p['databaseName'],), p
        sw, sh = manifest['sources'][p['source']]['size']
        x, y, w, h = p['crop']
        assert 0 <= x < x+w <= sw and 0 <= y < y+h <= sh, p
legacy = dict(re.findall(r"'(persona_[^']+)': (\d+)", (ROOT / 'lib/data/player_portrait_catalog.dart').read_text()))
active = {o['itemId'] for o in catalog['offers'] if o['itemType'] == 'avatar' and o['enabled']}
assert len(active) == 123
assert active == set(manifest['avatarKeys']) | set(legacy)
assert not active.intersection(manifest['retiredAvatarIds'])
assert set(manifest['avatarKeys'].values()) <= keys
assert set(manifest['coachKeys'].values()) <= keys
# Canonical identities: source-card captions, not row arithmetic or name matching.
anchors = {'victor_osimhen':('zip1_14',0,401923), 'mauro_icardi':('zip1_14',1,68863),
           'pep_guardiola':('zip1_09',8,4000000062), 'pep_guardiola_coach':('zip0_01',2,4000000062),
           'patrick_vieira':('zip1_07',1,4000000032), 'gabriel_batistuta':('zip1_07',4,4000000045),
           'lefter_kucukandonyadis':('zip1_08',4,4000000008)}
for key, expected in anchors.items():
    p = next(p for p in manifest['portraits'] if p['key'] == key)
    assert (p['source'],p['cardIndex'],p['playerId']) == expected
for p in manifest['portraits']:
    assert p['playerId'] not in {466279,203655,164148,186623,424784,28900,52920,68293,588097}, p
for name in ['Metin Oktay','Oliver Kahn','Cafu','Burak Yılmaz']:
    assert next(p for p in manifest['portraits'] if p['name'] == name)['playerId'] is None
print('[PASS] 216 labelled portraits, 123 visible avatars; source hashes, bounds and canonical IDs verified.')
