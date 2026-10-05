# Player portraits and season sets

The approved Mathieu MARCOU / FootballTRAFIC artwork is bundled offline:
50 individual legend portraits and the complete, unmodified 2012/13 and 2013/14
source sheets (56 cards each, 77 distinct season players). Legend artwork takes
priority where both collections cover a player. Source links and canonical IDs
are recorded in tools/season_portraits/manifest.json. Display-time cropping
preserves the original source files and their attribution.

Season sheets are 600×1010 and 736×1239 pixels. They replace the damaged 280×320
thumbnails. The catalog uses player IDs rather than names, so namesakes such as
Luis Suárez, Marcelo, Thiago Silva and Xavi cannot inherit the wrong portrait.
Unmapped players and image failures retain the symbolic kit fallback.

The bundled database contains 36,353 players, including the reviewed
season/audit additions. Their recorded club
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

## Profile avatar coverage (4 October)

Profile badges now resolve stable avatar IDs to canonical player IDs and use the
same `PlayerPortrait` widget as common-player cards, including season-sheet crops,
legend priority and a fallback when an asset cannot load. Existing portraits for
Cristiano Ronaldo, Messi, Neymar, Benzema, Modrić and Ibrahimović are now available
in the profile picker, store and other `UserAvatarBadge` surfaces.

The previously requested 24 profile entries remain available. The caption audit
corrected Buffon's missing portrait: the 2012/13 card had been assigned to
Marchisio and the 2013/14 card to Higuaín. Buffon now uses the newer Juventus card.

The latest update adds Lampard, Shevchenko, Sócrates, Deschamps, Cruyff, Valderrama,
Gullit and Rijkaard with the existing legend artwork, plus James Rodríguez with
his Monaco season card. Mikel Arteta uses the separately captioned illustration supplied by the owner
from the 2013/14 Behance project. It is absent from the bundled collage; the
original screenshot is preserved and the existing display-time crop excludes
the page controls and caption. Canonical player ID 7451 connects it to the
profile picker, shop and player cards. Source and crop are in the manifest
under `additionalPortraits`. No duplicate database player is added.
The collection has 66 avatar offers, 45 with portraits. Existing offer IDs,
prices and ownership remain valid; new entries follow their category prices.
The Functions catalog version is 5. Deploy the updated Functions catalog with
the app to make the new purchases available on the live backend.

## Caption audit (4 October)

All 112 season cards and the 50 bundled legend portraits were visually reviewed.
There are 26 incorrect season-card labels in the earlier manifest; those have
been corrected. The season sets contain 77 unique identities, and the union with
the legend set contains 118 (119 with the separate Arteta portrait). The full cell-by-cell correction record is in
`tools/season_portraits/manifest.json` under `audit.corrections`.

Behance's live project pages returned HTTP 403 during this review. The audit used
the already bundled source sheets and the 56 full-size 2012/13 illustrations
reproduced at https://www.forza27.com/56-football-players-from-the-201213-season/.
This allowed the small captions to be checked without guessing from faces.
Source art files are unchanged. Legend artwork continues to take priority.

The reviewed data patch adds Clément Grenier, Michel Bastos, César Delgado and
Nemanja Vidić, each with a verified identity and the senior club printed on his
source card. Historical players mistakenly assigned these images are retained;
only their incorrect portrait associations are removed.

`generate_catalog.py` now produces Flutter crop coordinates from the reviewed
manifest. CI checks generation drift and resolves each name/search alias against
its exact player ID, instead of accepting a name anywhere in the database.
Regression tests pin Buffon, James, Müller, Sturridge, Cabaye, Walcott and Vidić
to their reviewed cells and reject the superseded/wrong identity mappings.
