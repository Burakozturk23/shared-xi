# Grid club pool

Botla Oyna > Grid has one persistent Club pool selector for all three variants.
Popular clubs is the default, using the curated IDs in popular_clubs_pool.dart.
League selection is a union of one or more league names/codes in the bundled
catalog; it does not claim to reflect live league membership. Broad uses the
existing senior-team catalog. No fallback may silently widen a chosen pool.

Settings are stored under grid_club_pool_v1, read once when a game is prepared,
and apply to new games. Corrupt or obsolete settings default to popular.
No database records or player answer pools are removed by these preferences.

Classic requires two candidate answers per cell in popular/league mode and a
candidate among each row club's first 80 rank-ordered players; all loaded valid
answers remain accepted. Reverse chooses displayed players in question-rank
order and filters all hidden club criteria. Random requires two unused answers
and a question-pool player in popular/league modes; broad requires one answer.
Single-league random pairs are supported. Random checks at most 120 pairs per
request; retries shuffle again. Unavailable boards show an error rather than
silently using clubs outside the selection.

Server sessions started with rules 2 (functions/grid_support.js) first look
for a fair board: at least three answers per cell, one of them among the 3000
best-known players, at most one position column, and rows from clubs with six
or more well-known players. A narrow pool falls back to the old floor after
60 tries. Random pairs follow the same rule and are drawn from the first three
clubs that have pairs, not only the first one.
