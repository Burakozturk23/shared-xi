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
    text = subprocess.check_output(['pdftotext', '-layout', '-enc', 'UTF-8', '-f', '7', '-l', '8', str(pdf), '-'],
                                   encoding='utf-8')
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


def extract_clubs(pdf):
    text = subprocess.check_output(['pdftotext', '-raw', '-enc', 'UTF-8', '-f', '2', '-l', '6', str(pdf), '-'])
    result = []
    keys = ['participations', 'titles', 'played', 'won', 'drawn', 'lost', 'goalsFor', 'goalsAgainst', 'points',
            'goalDifference']
    for page, body in zip(range(2, 7), text.decode('utf-8').split('\f')):
        for line in body.splitlines():
            m = re.match(r'^(\d+) (.+?) ([A-Z]{3}) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (-?\d+)$',
                         line.strip())
            if m:
                result.append({'position': int(m[1]), 'sourceName': m[2], 'countryCode': m[3], 'pdfPage': page,
                               **dict(zip(keys, map(int, m.groups()[3:])))})
    return result


def main(pdf):
    source = json.loads(pathlib.Path(__file__).with_name('uefa_2023_snapshot.json').read_text())
    assert hashlib.sha256(pdf.read_bytes()).hexdigest() == source['sourceSha256'], 'Source bytes changed'
    # Club ranking first: its raw-mode extraction does not depend on page layout.
    clubs = json.loads(pathlib.Path(__file__).with_name('uefa_2023_clubs.json').read_text(encoding='utf-8'))
    assert clubs['sourceSha256'] == source['sourceSha256']
    assert extract_clubs(pdf) == clubs['rows'], 'club table differs from the PDF'
    print(f"PASS: all {len(clubs['rows'])} club ranking rows match the PDF.")
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
