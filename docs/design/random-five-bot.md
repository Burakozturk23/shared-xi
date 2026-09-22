# Rastgele Beşler — Botla Oyna

This increment continues from `a9d0f86` (the published Çinko fixes).

## Rules and interaction

- Five rounds, one human answer followed by one bot answer on the same five clubs.
- Each matched club is +1; an answer scores at most 5 and a match at most 25.
- Unknown, ambiguous, already used or unrelated answers do not consume the turn.
  Rejected text stays editable; ambiguous identities can be selected explicitly.
- Passing consumes the human turn for 0 points. Both players share one used-player
  set throughout the match; a bot answer cannot repeat the human answer.
- Both answers and matched clubs remain on screen until **Sonraki tur** is pressed.
  After the fifth pair, **Maç sonucunu gör** opens totals, replay and round history.
- Easy bot prefers the best available 1–2-club answer; medium prefers the best
  answer up to 3 clubs; hard selects the actual best unused answer. If the preferred
  range has no candidates, easy/medium select the lowest available score instead.
  All actual matched clubs count; scores are never artificially capped.

## Data and lifecycle

`RandomFiveSession` loads answer-eligible V4 identities, aliases, countries and
popular-club memberships directly from SQLite. It does not initialize the legacy
Repository. Autocomplete searches all eligible identities rather than revealing
only players who match the board, and bypasses other modes' global search index.
Validation resolves canonical IDs and reads the same relation map for both sides.

Generation uses players with three or more popular clubs as seeds, fills from
connected clubs and prefers at least ten triple / fifteen double matches. It
prefers avoiding the previous board's clubs; overlap is allowed when needed, but
an identical set is rejected when there are alternatives. Every board must have
five distinct clubs, a triple connection and at least ten distinct answer IDs.
At most eight players can have been used before round five, so at least two
answers remain for the last pair. Inadequate data produces a retry screen, never
an empty or unplayable board.

All five boards are prepared before the explicit start action. Initialization is
versioned; stale completions and completions after disposal are ignored. User
input locks before notifications. Pause, backgrounding and exit confirmation
cancel the bot timer; returning resumes only a previously active match. Replay
clears scores, histories, text, identities and timers.

## Presentation

Ortak Saha light/dark surfaces, cyan human and purple bot accents, named club
cards with league labels, readable match badges, three difficulty choices,
progress and retained chronological history. Cards adapt to screen width and text
scale. History uses its own `PageStorageKey` so expansion booleans never share
storage with scroll offsets.

## Validation

- Controller/generation tests: seeded board validity, sparse data, loading/retry,
  disposal and stale loads, canonical identities, ambiguity, accents, search scope,
  duplicate submission locking, all difficulty bands, same-board turns, repeated
  answers, five-round termination, totals, pass, pause and replay.
- Widget tests: explicit start, editable rejected input, identity selection,
  scrolled history regression, round review/replay at 390×844 / 320×568 / 700×400
  with normal and 200% text, light/dark themes, background and exit handling.
- Catalog regression: this bot mode prepares its own V4 session and keeps existing
  account requirements.

Execution results are recorded in the accompanying PR. Merely adding a test does
not establish that it passed; full device verification is separate from CI.
