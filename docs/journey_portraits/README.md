# Player Journey portrait refresh

Based on PR #44 (`codex/five-mode-expansion`). The original ZIP's two PNG
sheets are bundled byte-for-byte. Reviewed native crop rectangles exclude card
captions. No generated faces, new database identities or image network calls.

- 10 refreshed player portraits, shared by gameplay and profile avatars.
- 9 new shop offers use existing 300-coin player / 450-coin legend prices.
  Salah's existing item ID and price remain unchanged. Existing purchases stay valid.
- All 40 journey identities resolve to bundled artwork. Locked careers show
  their portrait plus one lock; unlocking, progression and rewards stay unchanged.
- Five shorter chapter titles; chapter/task IDs and saved progress are unchanged.
- `tools/uploaded_portraits/manifest.json` is the source of truth; regenerate with
  `python tools/uploaded_portraits/generate_catalog.py` and verify with
  `python tools/uploaded_portraits/verify.py`.

## Try locally (PowerShell)

First save any local edits shown by `git status` (commit or stash), then:

```powershell
git fetch origin
git switch -c test/journey-portraits --track origin/codex/journey-portraits
flutter pub get
flutter run
```

If this local test branch already exists, switch to it and run `git pull --ff-only`.
Stop the running app and run it again so new bundled assets are loaded.
This branch includes PR #44 and its prior story development chain.

The visual changes are bundled with the app. New shop offers additionally need
the store callable deployed from this checkout:

```powershell
firebase deploy --only "functions:getStoreCatalog,functions:purchaseEconomyOffer,functions:equipStoreItem"
```

No production deployment is performed by this PR. Deploy the earlier story
Functions separately if PR #44 has not yet been deployed (see
`docs/five_mode_expansion/powershell.md`).
