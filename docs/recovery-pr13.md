# Consolidated PR13 recovery

## Why features appeared missing

At inspection, main was 7d7b1a7, while PR13 was still open on
codex/store-collection-refresh at b4aeae0. PR13 targets the PR12 branch,
not main. Its PR11/12/13 feature chain therefore was never part of main.
PR14 was based on main and inherited that missing feature chain.
No evidence in this inspected main history shows a whole-project revert.

## Combined source

- PR13 b4aeae0: complete social/player experience/store updates.
- Main 8f9118e: WorkManager 2.11.2 startup dependency fix, retained.
- Main 62c7a6b: bot Grid uses VsBotGridPage compatibility route, retained.
- Main 7d7b1a7: modern controller suggestions limited to session pool, retained.
- PR14 a31fc5b: procedural kit identities and tests, retained.

All 59 files changed by PR11/12/13 relative to e06c2f5 are preserved byte-for-byte.
The Grid route is the existing compatibility fix; this consolidation does not
claim to repair or reactivate the modern ClassicGridPage.

## Validation

- All 216 functions/test/*.test.js tests passed locally with node --test.
- Git index diff whitespace/conflict check passed.
- Flutter analysis, widget tests, Android debug build: require CI/local machine.
  Earlier Flutter dependency setup in this environment was blocked by automatic
  review for a cloud metadata request, including offline setup. Not retried.
- Physical-device release startup is NOT verified by a debug build.

## Safe emulator checkout (PowerShell, from any existing repo worktree)

```powershell
git fetch origin
git worktree add --detach ..\shared_xi_guncel origin/codex/restore-pr13-complete
cd ..\shared_xi_guncel
flutter pub get
flutter run
```

Use a new directory name if shared_xi_guncel already exists. This leaves any
unfinished merge and uncommitted files in the original working directory intact.
Local ignored Firebase/Android configuration is not automatically copied into
a worktree. Reuse your existing local configuration only if the build requires it;
never commit signing credentials.

## Acceptance

Verify the new store categories, inventory, 24 profile kits, avatar collection,
profile, friends, achievements and progression views; then check bot Grid and
procedural player kit identities. Test a release APK on the affected phone too.

PR13 includes backend and RTDB rule changes. If they are not already deployed,
store transactions need the matching backend. Follow docs/store-collection.md;
no Firebase deploy was performed in this recovery. Do not merge older stacked
PRs separately after merging this combined branch without comparing them first.
