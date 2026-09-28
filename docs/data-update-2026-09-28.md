# Reviewed data update v4-2026-09-28.1

Scope: one player, Dušan Vlahović (357498). This is not a full summer update.
Official source URLs and exact before/after assertions are recorded in
`tools/data_platform_v4/patches/v4-2026-09-28.1.json`.

- Add Beşiktaş (114) to player_clubs, with a confirmed senior appearance.
- Remove the unsupported Ajman (515) relationship. Official biography lists
  Partizan, Fiorentina and Juventus; the old Ajman relationship had lower trust
  and no career spell, transfer event or club-stat support in this asset.
- Preserve Partizan, Fiorentina and Juventus relationships and all old spells.
- Add Beşiktaş career spell from the documented contract date, 2026-08-13.
  Appearances remain NULL; no current totals were guessed.
- Add the move from last club Juventus to Beşiktaş in transfer history. The
  player was a free agent between clubs; this record does not imply a paid
  direct transfer and the schema contains no fee/type column.
- Players remain 30,135, clubs 4,311. Transfer records increase by one to 33,994.
- Historical pruning counts and base generation date remain historical facts;
  revision/updatedUtc record this patch separately. Hash and size match the asset.

Apply only to the pinned base asset using `apply_reviewed_patch.py`. The tool
validates the base, operates on a temporary copy, checks affected rows, postconditions,
SQLite integrity and foreign keys, then replaces the asset and manifest. Publish
both in one git commit. A failed validation preserves the inputs; a repeated
identical patch is a no-op. Do not apply patches to an installed user's database.
The existing hash-based runtime filename loads the new asset on next full launch.
No schema or player-count startup change is needed for this targeted correction.

Validation:
- `python tools/data_platform_v4/verify_game_data_v4_freeze.py`
- `python -m unittest discover -s tools/data_platform_v4 -p 'test_reviewed_patch.py'`

Rollback: restore BOTH runtime asset and manifest from commit ace0ecd. Keep the
verifier consistent with that release. The original compiler still requires
missing historical inputs and would not automatically replay this patch.

Follow-up audit: club 669 is named Partizan but has legacy MLS/empty-country
metadata. No global club-ID remapping was attempted in this player-only patch.
