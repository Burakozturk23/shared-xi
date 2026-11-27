"""Server catalog with answers, app assets without them.

`build_chapter_*.py` write the full chapters to `tools/player_journey/source/`.
This step writes `functions/config/journey_catalog.json` (answers, server only)
and the app assets `assets/data/player_journey_chapter_*.json`, where
`answerKeys` and `explanation` are removed and each task is marked
`serverValidated`: the answer is checked by the server, and the explanation is
returned only after a correct answer. Usage: build_catalog.py [--check]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).with_name('source')
NUMBERS = ['one', 'two', 'three', 'four']
SECRET = ('answerKeys', 'explanation')


def public(chapter):
    out = json.loads(json.dumps(chapter))
    for journey in out['journeys']:
        for task in journey['tasks']:
            for key in SECRET:
                task.pop(key, None)
            # Answer checked by the server; the coin/ad hints stay, computed there.
            task['serverValidated'] = True
            task['legacyHints'] = True
    return out


def outputs():
    chapters = [json.loads((SOURCE / f'chapter_{n}.json').read_text(encoding='utf-8')) for n in NUMBERS]
    files = {ROOT / 'functions/config/journey_catalog.json':
             json.dumps({'version': 1, 'chapters': chapters}, ensure_ascii=False, separators=(',', ':')) + '\n'}
    for n, chapter in zip(NUMBERS, chapters):
        files[ROOT / f'assets/data/player_journey_chapter_{n}.json'] = \
            json.dumps(public(chapter), ensure_ascii=False, indent=2) + '\n'
    return files


if __name__ == '__main__':
    for path, text in outputs().items():
        if '--check' in sys.argv:
            assert path.read_text(encoding='utf-8') == text, f'{path.relative_to(ROOT)} drift: run build_catalog.py'
        else:
            path.write_text(text, encoding='utf-8')
    print('[PASS]' if '--check' in sys.argv else '[WROTE]', 'journey catalog and redacted chapter assets')
