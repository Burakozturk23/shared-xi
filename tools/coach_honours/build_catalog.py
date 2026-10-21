"""Build a read-only historical sidecar; never update canonical coaches or scoring."""
import argparse
import csv
import hashlib
import json
import re
import unicodedata
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUTPUT = ROOT / 'assets/data/coach_honours_archive.json'
REPORT = HERE / 'audit.json'
MISSING = {'', '-', 'NA'}
PROFILE_FIELDS = ['name', 'club', 'birth_date', 'age', 'place_of_birth', 'citizenship',
                  'appointment_date', 'contract_until_date', 'coaching_licence',
                  'avg_term_as_coach', 'preffered_formation', 'current_league', 'current_league_country']


def normalize(value):
    value = value.casefold().replace('ł', 'l').replace('ø', 'o').replace('ß', 'ss')
    return ''.join(c for c in unicodedata.normalize('NFKD', value) if c.isalnum())


def read_csv(path):
    with path.open(encoding='utf-8', newline='') as source:
        reader = csv.DictReader(source)
        headers, rows = reader.fieldnames, list(reader)
    if len(set(headers)) != len(headers) or any(None in r or None in r.values() for r in rows):
        raise ValueError(f'Malformed CSV: {path.name}')
    return headers, rows


def deduplicate(rows):
    result, lines, duplicates = {}, {}, []
    for line, row in enumerate(rows, 2):
        key = normalize(row['name'])
        if not key:
            raise ValueError('Empty name')
        if key in result:
            if row != result[key]:
                raise ValueError(f'Conflicting duplicate: {row["name"]}')
            duplicates.append({'name': row['name'], 'line': line})
        else:
            result[key] = row
            lines[key] = line
    return result, lines, duplicates


def positive_count(value):
    if not re.fullmatch(r'\d+', value):
        raise ValueError(f'Invalid count: {value!r}')
    return int(value)


def optional_text(value):
    value = value.strip()
    return None if value in MISSING else value


def optional_date(value):
    value = optional_text(value)
    if value is not None:
        date.fromisoformat(value)  # reject invalid dates instead of silently repairing
    return value


def clean_profile(row):
    """Only recover fields with recognisable syntax; retain original CSV for audit."""
    fields = ['coaching_licence', 'avg_term_as_coach', 'preffered_formation']
    values = [row[f].strip() for f in fields]
    licence = next((v for v in values if v in {'UEFA Pro Licence', 'Licence trainer'}), None)
    years = next((v for v in values if re.fullmatch(r'\d+(?:\.\d+)? Years', v)), None)
    formation = next((v for v in values if re.fullmatch(r'\d(?:-\d){2,4}(?: [A-Za-z0-9 ]+)?', v)), None)
    flags = []
    for field, value in zip(fields, values):
        expected = {'coaching_licence': licence, 'avg_term_as_coach': years, 'preffered_formation': formation}[field]
        if value not in MISSING and value != expected:
            flags.append(f'unreliable_{field}')
    return dict(birthDate=optional_date(row['birth_date']), citizenship=optional_text(row['citizenship']),
                birthPlace=optional_text(row['place_of_birth']), snapshotClub=optional_text(row['club']),
                snapshotLeague=optional_text(row['current_league']), snapshotLeagueCountry=optional_text(row['current_league_country']),
                snapshotAppointmentDate=optional_date(row['appointment_date']),
                snapshotContractUntil=optional_date(row['contract_until_date']),
                snapshotLicence=licence, snapshotAverageTermYears=float(years.split()[0]) if years else None,
                snapshotFormation=formation), flags


def resolve_identity(row, canonical, aliases):
    # Never use substring/fuzzy matching or select the first of multiple identities.
    target = normalize(aliases.get(row['name'], row['name']))
    matches = [c for c in canonical if target in {normalize(c['name']), *map(normalize, c.get('aliases', []))}]
    if len(matches) != 1:
        return None, 'ambiguous' if matches else 'unmatched', sorted(c['id'] for c in matches)
    coach = matches[0]
    if coach.get('countries') and row['citizenship'] not in coach['countries']:
        return None, 'country_conflict', [coach['id']]
    return coach, 'alias' if row['name'] in aliases else 'exact', [coach['id']]


def build():
    manifest = json.loads((HERE / 'sources/manifest.json').read_text(encoding='utf-8'))
    for source in manifest['files']:
        if hashlib.sha256((HERE / 'sources' / source['name']).read_bytes()).hexdigest() != source['utf8Sha256']:
            raise ValueError(f'Source checksum mismatch: {source["name"]}')
    headers, raw_coaches = read_csv(HERE / 'sources/all_coaches.csv')
    if headers != PROFILE_FIELDS:
        raise ValueError('Unexpected profile schema')
    trophy_headers, raw_trophies = read_csv(HERE / 'sources/all_trophies.csv')
    definitions = json.loads((HERE / 'competitions.json').read_text(encoding='utf-8'))
    if trophy_headers[0] != 'name' or set(trophy_headers) != {'name', 'NONE', *definitions}:
        raise ValueError('Unmapped or missing trophy column')
    if any(v[1] not in {'senior', 'individual', 'youth', 'lowerTier', 'medal'} for v in definitions.values()):
        raise ValueError('Unknown achievement category')
    coaches, coach_lines, duplicates = deduplicate(raw_coaches)
    trophies, trophy_lines, trophy_duplicates = deduplicate(raw_trophies)
    if set(trophies) - set(coaches):
        raise ValueError('Trophy row without coach')
    canonical = json.loads((ROOT / 'assets/data/coaches_min.json').read_text(encoding='utf-8'))
    aliases = json.loads((HERE / 'identity_aliases.json').read_text(encoding='utf-8'))
    if set(aliases) - {r['name'] for r in coaches.values()}:
        raise ValueError('Unused identity alias')
    records, unresolved, quality = [], [], []
    for key, row in sorted(coaches.items()):
        coach, resolution, candidates = resolve_identity(row, canonical, aliases)
        if coach is None:
            unresolved.append(dict(name=row['name'], reason=resolution, candidateIds=candidates))
        profile, flags = clean_profile(row)
        if flags:
            quality.append(dict(name=row['name'], flags=flags))
        trophy = trophies.get(key)
        counts = {column: positive_count(trophy[column]) for column in trophy_headers[1:]} if trophy else {}
        records.append(dict(
            id='coach_archive_' + key, name=row['name'], coachId=coach['id'] if coach else None,
            aliases=sorted(set([row['name']] + ([coach['name'], *coach.get('aliases', [])] if coach else []))),
            identityResolution=resolution, profile=profile, profileFlags=flags,
            coachSourceLine=coach_lines[key], trophySourceLine=trophy_lines.get(key),
            hasTrophyRecord=trophy is not None, unclassifiedCount=counts.get('NONE'),
            honours=[dict(competitionId=k, count=v) for k, v in counts.items() if k != 'NONE' and v > 0]))
    bound_ids = [r['coachId'] for r in records if r['coachId'] is not None]
    if len(bound_ids) != len(set(bound_ids)):
        raise ValueError('Multiple archive records linked to one canonical coach')
    catalog = dict(schemaVersion=1, source=manifest,
                   competitions=[dict(id=k, label=v[0], category=v[1]) for k, v in definitions.items()], coaches=records)
    report = dict(rawCoachRows=len(raw_coaches), uniqueCoaches=len(records), trophyRows=len(raw_trophies),
                  linkedCoaches=len(bound_ids), missingTrophyRows=sum(not r['hasTrophyRecord'] for r in records),
                  positiveHonourEntries=sum(len(r['honours']) for r in records),
                  excludedNoneCount=sum(r['unclassifiedCount'] or 0 for r in records),
                  duplicateCoachRows=duplicates, duplicateTrophyRows=trophy_duplicates,
                  unresolvedIdentities=unresolved, profileIssues=quality)
    return catalog, report


def render(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    catalog, report = build()
    for path, value in [(OUTPUT, catalog), (REPORT, report)]:
        content = render(value)
        if args.check:
            if not path.exists() or path.read_text(encoding='utf-8') != content:
                raise SystemExit(f'Outdated generated file: {path.relative_to(ROOT)}')
        else:
            path.write_text(content, encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if isinstance(v, int)}))


if __name__ == '__main__':
    main()
