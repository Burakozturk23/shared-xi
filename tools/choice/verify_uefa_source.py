#!/usr/bin/env python3
"""Verify every transcribed numeric fact against the hash-pinned official PDF.

Usage: python tools/choice/verify_uefa_source.py /path/to/downloaded.pdf
Requires Poppler pdftotext; does not download or silently refresh any source.
"""
import hashlib
import json
import pathlib
import re
import subprocess
import sys


def extract(pdf):
    text = subprocess.check_output(['pdftotext', '-layout', '-f', '7', '-l', '8', str(pdf), '-'], text=True)
    result = []
    for page, body in enumerate(text.split('\f')[:2], 7):
        lines = body.splitlines()
        header = next(i for i, line in enumerate(lines) if line.startswith('Player'))
        starts = [m.start() for m in re.finditer('Player', lines[header])]
        assert len(starts) == 4
        for column, (a, b) in enumerate(zip(starts, starts[1:] + [None]), 1):
            previous = None
            for line in lines[header + 1:]:
                if 'UEFA Champions League Statistics Handbook' in line:
                    break
                cell = line[a:b].strip()
                m = re.match(r'^(.*?)\s{2,}(\d+)\s+(\d+)\s{2,}(.+)$', cell)
                if m:
                    previous = {'sourceName': m[1], 'appearances': int(m[2]), 'goals': int(m[3]),
                                'country': m[4].strip(), 'pdfPage': page, 'column': column}
                    result.append(previous)
                elif cell:
                    assert previous and cell in ['Ireland', 'Herzegovina'], cell
                    previous['country'] += ' ' + cell
    return result


def main(pdf):
    source = json.loads(pathlib.Path(__file__).with_name('uefa_2023_snapshot.json').read_text())
    assert hashlib.sha256(pdf.read_bytes()).hexdigest() == source['sourceSha256'], 'Source bytes changed'
    facts = extract(pdf)
    expected = source['rows'] + source['excluded']
    assert len(facts) == len(expected) == 208
    keyed = {(r['pdfPage'], r['column'], r['sourceName']): r for r in facts}
    assert len(keyed) == 208
    for row in expected:
        fact = keyed[(row['pdfPage'], row['column'], row['sourceName'])]
        assert all(row[k] == v for k, v in fact.items()), row
    print('PASS: all 208 source rows match; 145 accepted identities, 63 exclusions retained.')


if __name__ == '__main__':
    main(pathlib.Path(sys.argv[1]))
