# Player coverage review — 2026-09-30

This review covers 114 previously mapped clubs across Türkiye, England, Spain,
Germany, Italy and France. It is not a claim that every current first-division
club or squad is complete. `lastSyncedAt` reports an API refresh, not a roster's
effective season.

The API scan found 2,877 linked rows, 392 unmatched identities, 76 ambiguous
identities and four missing-link candidates. Those are roster rows, not counts
of unique missing players. The unresolved rows and source URLs are retained in
`tools/data_platform_v4/patches/six-league-audit-2026-09-30.json`.
No rows from that queue were automatically imported: the Newcastle response
includes Christian Atsu, proving that the endpoint also contains historical
players. Its output must not be advertised as an authoritative current squad.

## Included corrections

- 45 reviewed missing notable players: Gökhan Gönül, Hagi, Popescu, Sergen,
  Arda Turan, Volkan Demirel, Alex-era contemporaries and global legends including
  Beckham, Maldini, Totti, Kaká, Roberto Carlos, Maradona and Cruyff.
- 191 additional senior-club relationships, including the four missing links
  for the existing Ümit Akdağ and İlhan Fakılı identities. Their names retain
  Turkish spelling; ASCII spellings remain searchable.
- 6,145 roster-import positions normalized to the existing app vocabulary.
- Search uses the normalized search index, supporting Turkish characters and
  accent-free spelling without loading the whole player universe.
- Daily fixture selection checks the theme's actual 5/6/8-answer target; an
  insufficient fallback is not offered in the playable match list.

Final package: 36,325 players and 4,311 clubs. Existing transfer and career-spell
tables are unchanged. Reviewed club history is deliberately partial; no dates,
fees, appearances or trophy statistics were fabricated. Current squads remain
a separate verification task from historical common-player relationships.

## Evidence and reproduction

`notable-players-2026-09-30.json` holds stable IDs, birth years, positions,
club mappings and per-player source URLs. Gökhan's senior playing history is
also documented by TFF (person ID 414770) and Beşiktaş's 2016 announcement:
https://bjk.com.tr/tr/haber/66738/gokhan_gonul_ile_anlasmaya_varildi.html

Run from the repository root:

```sh
python3 tools/data_platform_v4/apply_notable_players.py
python3 tools/data_platform_v4/verify_game_data_v4_freeze.py
python3 -m unittest discover -s tools/data_platform_v4 -p 'test_*.py'
flutter test test/daily_answer_capacity_test.dart
```

The patch is pinned to the published base asset hash, validates club identities,
rejects duplicate names and changed evidence, and is idempotent after application.
The publishing workflow commits the SQLite asset and manifest together. The app
uses the manifest hash to refresh an installed copy at the next full restart;
hot reload cannot replace a database that is already open.
