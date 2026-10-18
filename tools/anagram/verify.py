"""Ensure curated Anagram identities remain aligned with the bundled database."""
import json
import sqlite3
from pathlib import Path
root = Path(__file__).resolve().parents[2]
players = json.loads((root/'assets/data/anagram_catalog.json').read_text())
assert len(players) >= 270
legacy = json.loads((root/'tools/daily_words/practice_legacy.json').read_text())
assert players[:len(legacy)] == legacy
assert len({p['id'] for p in players}) == len(players)
assert len({p['answer'] for p in players}) == len(players)
with sqlite3.connect(root/'assets/runtime/linkball_game_data_v4.sqlite') as con:
    for p in players:
        assert con.execute('SELECT name,country,position FROM players WHERE id=?', (p['id'],)).fetchone() == (p['name'], p['country'], p['position']), p['name']
        assert p['answer'].isascii() and p['answer'].isalpha() and p['answer'].isupper()
        assert 4 <= len(p['answer']) <= 14 and len(set(p['answer'])) >= 2
print(f'[PASS] All {len(players)} Anagram players match V4; all 64 legacy entries preserved.')
