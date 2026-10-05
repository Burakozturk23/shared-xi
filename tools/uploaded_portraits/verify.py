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
assert len(keys) == len(manifest['portraits']) == 247
with sqlite3.connect(ROOT / 'assets/runtime/linkball_game_data_v4.sqlite') as db:
    for p in manifest['portraits']:
        if p['playerId'] is not None:
            assert db.execute('SELECT name FROM players WHERE id=?', (p['playerId'],)).fetchone() == (p['databaseName'],), p
        sw, sh = manifest['sources'][p['source']]['size']
        x, y, w, h = p['crop']
        assert 0 <= x < x+w <= sw and 0 <= y < y+h <= sh, p
legacy = dict(re.findall(r"'(persona_[^']+)': (\d+)", (ROOT / 'lib/data/player_portrait_catalog.dart').read_text()))
active = {o['itemId'] for o in catalog['offers'] if o['itemType'] == 'avatar' and o['enabled']}
assert len(active) == 151
assert active == set(manifest['avatarKeys']) | set(legacy)
assert not active.intersection(manifest['retiredAvatarIds'])
assert set(manifest['avatarKeys'].values()) <= keys
assert set(manifest['coachKeys'].values()) <= keys
# Canonical identities: source-card captions, not row arithmetic or name matching.
anchors = {'victor_osimhen':('zip1_14',0,401923), 'mauro_icardi':('zip1_14',1,68863),
           'pep_guardiola':('dual_role_00',0,4000000062), 'pep_guardiola_coach':('dual_role_01',0,4000000062),
           'patrick_vieira':('zip1_07',1,4000000032), 'gabriel_batistuta':('zip1_07',4,4000000045),
           'lefter_kucukandonyadis':('zip1_08',4,4000000008)}
for key, expected in anchors.items():
    p = next(p for p in manifest['portraits'] if p['key'] == key)
    assert (p['source'],p['cardIndex'],p['playerId']) == expected
for p in manifest['portraits']:
    assert p['playerId'] not in {466279,203655,164148,186623,424784,28900,52920,68293,588097}, p
by_key = {p['key']: p for p in manifest['portraits']}
for p in manifest['portraits']:
    assert p['role'] == 'custom' or p['playerId'] is not None, p
for pair in manifest['dualRoles']:
    player, coach = by_key[pair['playerKey']], by_key[pair['coachKey']]
    assert player['role'] == 'player' and coach['role'] == 'coach'
    assert player['playerId'] == coach['playerId']
    assert player['source'] != coach['source']
    assert pair['playerKey'] in manifest['avatarKeys'].values()
    assert pair['coachKey'] in manifest['avatarKeys'].values()
for name in ['kaan', 'omer', 'berat', 'burak', 'ege']:
    assert manifest['avatarKeys']['persona_' + name] == name
    assert by_key[name]['playerId'] is None
print('[PASS] 247 labelled portraits, 151 visible avatars; 24 role pairs and canonical IDs verified.')
