#!/usr/bin/env python3
"""Apply a reviewed, hash-pinned data patch to an immutable V4 asset.

No network access. Keep the asset and manifest in the same git commit.
Re-running an applied patch is a no-op only when its recorded output hash matches.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def digest(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

def apply(database, manifest_path, patch_path):
    database, manifest_path, patch_path = map(Path, (database, manifest_path, patch_path))
    manifest = json.loads(manifest_path.read_text())
    patch = json.loads(patch_path.read_text())
    before = digest(database)
    if before != manifest['database']['sha256']:
        raise ValueError('Database/manifest hash mismatch; no changes applied')
    applied = next((p for p in manifest.get('patches', []) if p['id'] == patch['id']), None)
    if applied:
        if applied['outputSha256'] != before:
            raise ValueError('Already applied patch does not match current output; review patch chain')
        print('Already applied:', patch['id'])
        return
    if before != patch['baseSha256']:
        raise ValueError('Patch base hash mismatch; review against this database first')
    with tempfile.TemporaryDirectory(dir=database.parent) as directory:
        output = Path(directory) / database.name
        shutil.copy2(database, output)
        with sqlite3.connect(output) as con:
            con.execute('PRAGMA foreign_keys=ON')
            for check in patch['preconditions']:
                actual = [list(row) for row in con.execute(check['sql'], check.get('args', []))]
                if actual != check['rows']:
                    raise ValueError('Precondition failed: ' + check['sql'])
            for operation in patch['operations']:
                result = con.execute(operation['sql'], operation.get('args', []))
                if result.rowcount != operation['changes']:
                    raise ValueError('Unexpected affected row count: ' + operation['sql'])
            for check in patch['postconditions']:
                actual = [list(row) for row in con.execute(check['sql'], check.get('args', []))]
                if actual != check['rows']:
                    raise ValueError('Postcondition failed: ' + check['sql'])
            if con.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError('Database integrity failure')
            if con.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Foreign key failure')
        after = digest(output)
        manifest['database'].update(sha256=after, bytes=output.stat().st_size,
                                    sizeMB=round(output.stat().st_size / 1024**2, 2))
        manifest['revision'] = patch['id']
        manifest['updatedUtc'] = patch['reviewedUtc']
        manifest.setdefault('patches', []).append({
            'id': patch['id'], 'baseSha256': before, 'outputSha256': after,
            'definition': str(patch_path.relative_to(ROOT)) if patch_path.is_relative_to(ROOT) else patch_path.name,
        })
        with sqlite3.connect(output) as con:
            for table in ('players', 'clubs', 'transfers'):
                manifest['counts'][table] = con.execute('SELECT COUNT(*) FROM ' + table).fetchone()[0]
        next_manifest = Path(directory) / manifest_path.name
        next_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        # The hash check on every run detects an interrupted two-file publish.
        # Git retains the previous release for rollback; never patch an installed DB.
        os.replace(output, database)
        os.replace(next_manifest, manifest_path)
    print('Applied:', patch['id'], after)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('patch', type=Path)
    parser.add_argument('--database', type=Path, default=ROOT/'assets/runtime/linkball_game_data_v4.sqlite')
    parser.add_argument('--manifest', type=Path, default=ROOT/'assets/runtime/linkball_game_data_v4_manifest.json')
    args = parser.parse_args()
    apply(args.database, args.manifest, args.patch)
