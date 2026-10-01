# Player portraits and season sets

The approved Mathieu MARCOU / FootballTRAFIC artwork is bundled offline:
50 individual legend portraits and the complete, unmodified 2012/13 and 2013/14
source sheets (56 cards each, 81 distinct season players). Legend artwork takes
priority where both collections cover a player. Source links and canonical IDs
are recorded in tools/season_portraits/manifest.json. Display-time cropping
preserves the original source files and their attribution.

Season sheets are 600×1010 and 736×1239 pixels. They replace the damaged 280×320
thumbnails. The catalog uses player IDs rather than names, so namesakes such as
Luis Suárez, Marcelo, Thiago Silva and Xavi cannot inherit the wrong portrait.
Unmapped players and image failures retain the symbolic kit fallback.

The bundled database contains 36,349 players, including the three season-set
additions Clint Dempsey, Javier Zanetti and Rio Ferdinand. Their recorded club
links are partial reviewed senior-player history, not complete career records.
Hilmi and Turan are removed from the shop selection; Emre Özcan uses initials
because no approved portrait is available for him. Existing ownership records
are not deleted.

Deploy the updated Firebase Functions shop catalog alongside the app update.
This PR does not deploy Firebase or merge the dependent PR chain into main.
No database migration is needed for the bundled SQLite: its manifest hash selects
the updated local database. The one-time materialization workflow has been
removed after the generated data was committed.

Validation covers source decoding, crop bounds, namesake exclusion, legend
priority, widget rendering, database integrity, reviewed patch idempotency,
Functions contracts, Flutter analysis/tests and Android debug compilation.
Device integration and signed release builds are separate release checks.
