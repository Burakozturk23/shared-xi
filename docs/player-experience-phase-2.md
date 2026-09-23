# Player experience — phase 2

Built on phase 1 (`codex/social-center-refresh`, PR #11). Merge phase 1 first,
then retarget this PR to main. No new backend deployment or reward rules.

- Progress: daily/career/claimable filters, level and season, dynamic reward
  schedule/multiplier, stale-data warnings, resume refresh and serialized claims.
- Badges: earned/locked/claimable/category filters, scrollable details, responsive
  cards. One load per refresh; no stream resubscriptions during widget builds.
  Server-confirmed claims remain acknowledged even before another refresh.
  Removed the sequence of blocking unlock dialogs on opening the collection.
- Account: current-theme layout, expandable data explanations, safe deletion
  confirmation and navigation lock during deletion; recoverable generic errors.
- Pro: real store prices, no guessed discounts, no purchase while entitlement is
  unknown; pending purchases lock other plans. Restore and store retry are visible.
  Verification/entitlement authority remains entirely on the existing server.
- Preferences: persisted Turkish/English *menu* language, theme, sounds/haptics,
  working feedback preview. Correct answers in Daily, Çinko, Random Five and Squad
  Challenge plus confirmed mission/badge rewards use the shared preferences.
  Sound is a platform click, subject to device/system support (not a music pack).

## Language coverage
Settings, notification preferences, progress/badge UI and the main navigation
are translated. Server mission/season copy, badge catalog names/descriptions,
other screens (including privacy/Pro), and game content retain their original
language. The language selector explicitly states the limited coverage. This is
not a claim that the whole application has English localization.

## Device acceptance
- Claim daily/mission/badge rewards with a linked test account; try offline retry.
- Check filters and detail sheets at large text sizes and in both themes.
- Switch menu language, restart app, confirm the selection persists.
- Disable sound/haptics, play supported modes; test each setting independently.
- Use Google Play license testing for pending/cancelled/success/restored purchases.
- Verify account deletion using a disposable test account, never a real profile.

Widget tests use injected gateways; they do not charge a card or delete real data.
