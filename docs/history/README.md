# Historical football data

The user-supplied ZIP snapshots are imported into two independent, read-only SQLite packs. They do not modify the canonical V4 player/club database or existing game answers. The data is available in **Veritabanı → Futbol arşivi**, from UCL Moments, and from International Glory. The bookmark action opens the 37-match selection supplied in the StatsBomb package.

## What is included

- 534,528 stored historical result records (conservative identity matching; aliases can leave distinct source records for the same real-world fixture).
- 49,944 international matches, 47,914 goal records, 699 linked shootout winners, and 36 date-bounded former country names.
- 16,581 season/tournament rosters containing 576,048 listed/past player entries. These are membership records, **not unique players**, current squads, career proofs, appearances, or match starting lineups.
- All 37 StatsBomb selection entries, of which 34 have a unique independently sourced result. **No StatsBomb event or lineup JSON was present in the supplied ZIP.** No raw StatsBomb content is fetched, bundled, or claimed available.
- Source identifiers, original labels, file/row provenance and original result fields; optional roster measurements and birthplace are retained as source text.

Exact generated sizes, hashes, source snapshot checksums and counts are in `assets/history/manifest.json` and `import-report.json`. The packaged databases add approximately 62 MB compressed and require approximately 327 MB when both are installed. Each pack is installed only when requested. Streaming decompression and hashing run off the UI isolate; queries return at most 40 records at a time. Existing databases are hash-verified before reuse.

## Identity and result rules

IDs in the historical databases are local to the pack and its version. Never use a historical ID as a canonical player or club ID. `teams.canonical_club_id` is populated only by an unambiguous country-scoped exact match or the reviewed aliases in `build.py`; it may be null. No fuzzy player-name joins are performed. National identity does not depend on venue country. Country renames retain date ranges rather than silently rewriting older teams.

FT, half-time, extra-time, and shootout fields remain separate. International final scores include extra time where played and exclude shootouts; do not infer a 90-minute result. Club FT is labelled as a source result unless a separate ET field is supplied. The goal minute `NA` becomes null, not a made-up minute. `goals_complete` requires per-side goal counts to agree with the result; absent coverage does not mean nobody scored. Own goals retain the source's credited team and own-goal flag.

Exact duplicate keys (kind, competition, date, country-scoped teams) merge provenance. Conflicting final scores are flagged and both original source records remain recoverable. The first result is displayed with a conflict warning. Conflicting records must not be used for generated quiz answers. Before building a new quiz, also check the required field coverage, aliases, source evidence, and the relevant score phase. The archive API deliberately does not assert that every browse result is a reviewed quiz question.

Squad `status` distinguishes listed and past players. `relation` distinguishes Previous Club, New Club, and Current Club. Birth dates, heights, weights, and birthplace remain literal source strings because older two-digit years and units are not uniformly specified. Comma-ambiguous roster rows are rejected and counted rather than shifted into wrong columns. Records without played scores and ambiguous matches are reported, not fabricated. See report examples for paths and row numbers to inspect in the original archives.

## Rebuild and validate

From the repository root, with the original large ZIP available:

```bash
python3 tools/history/build.py --archive '/absolute/path/Yeni klasör (2)(1).zip' --cutoff 2026-10-09
python3 -m unittest discover -s tools/history -p 'test_*.py'
python3 tools/history/verify.py
flutter pub get
flutter test test/history_archive_test.dart
flutter run
```

`tools/history/statsbomb_selection.json` is the 37-match metadata catalog supplied in the smaller ZIP. No supplied shell/PowerShell/batch script is executed. Importing does not require downloading external football data. Rebuilding with identical archives, selection, importer, and SQLite runtime produces deterministic compressed packs (gzip timestamp zero). The verifier checks hashes, counts, integrity, foreign keys, source coverage, participant consistency, and Istanbul 2005 score phases. CI runs both the importer regression tests and pack verifier before Flutter tests and Android compilation.

For application code use `HistoryRepository`: paginated `browse`, `detail`, and `selections`. Inject a fake repository for widget tests. Native SQLite is required, consistent with the existing V4 database. Web displays a retry/error state rather than pretending the native archive loaded.

## Attribution and limitations

Football CSV snapshots include CC0 notices; the international results upstream also publishes CC0. The included `licenses/history/CC0-1.0.txt` preserves the supplied notice, with source URLs listed in the manifest and in-app record details. Upstream sources are credited even where a CC0 waiver applies. Snapshot coverage, spelling errors, and ambiguous identities are not guaranteed correct merely because import validation passes.

The StatsBomb ZIP is a catalog plus downloader, not the downloaded dataset. Before a future raw-data integration, obtain the actual files and assess the applicable upstream terms for the intended use. Its catalog-only entries are never offered as complete event/lineup records.
