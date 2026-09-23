# Social refresh — phase 1

## Delivered

- Community: a hub linking friends, rankings and safety; category-based support
  form; status filters; full request details and reference IDs. Failed sends keep
  the draft. Confirmed submissions remain visible if the history refresh fails.
- Friends: stable stream subscriptions, error/retry states, useful guest sign-in
  entry, friend-search empty CTA, removal confirmation and responsive action rows.
  Search relationship state updates after mutations from any tab. Failed profile
  lookups can be retried. Incoming match invitations retain their existing flows.
- Safety: direct links to blocked players and player search, report filters,
  detail/status explanations and an explicit account gate. A report does not
  imply the user has also blocked its subject.
- Leaderboard: current-theme daily/weekly/Elo views, responsive top-three cards,
  own entry and honest top-100 wording, retry without backend error leakage,
  stable reads and day-change refresh on application resume.
- Entry routes from profile/settings/online use the chosen light/dark theme.

## Authority and deployment

All mutations still call the existing server-authoritative services. No RTDB
rules, score calculation, moderation privileges, reward balances or payment
behavior changed. No new Firebase deployment is needed for this phase. The
existing social/community/leaderboard backend must already be deployed.

The UI displays only statuses the backend returns. It does not invent moderator
responses, live online presence, guaranteed response times or ranks outside the
returned leaderboard window. Backend paths are not shown in user-facing errors.

## Verification

`test/social_center_test.dart` covers draft retention and submission locking,
confirmed-send/history-failure behavior, friend stream retry, removal cancellation,
guest account gating, leaderboard retry/rank messaging, immutable report data,
report filters/details and all four screens at 390px and 320px / 1.8x text in both
light and dark themes. CI captures previews in `social-screen-previews`.

Device acceptance after merging:
1. Open Community; submit a valid request and inspect its detail in My Requests.
2. With a Google-linked test account, find an exact nickname, send/cancel a friend
   request; use a second account for accept/reject and match invitation flows.
3. Verify blocking/reporting and their history using test accounts.
4. Switch all ranking tabs; disconnect/reconnect to exercise retry.
5. Repeat in light theme and with larger system text.

Automated UI tests use deterministic gateways; production Firebase/Google
sign-in and cross-account moderation require the device checks above.

## Agreed next phase (not implemented in this PR)

- Progression and missions: clear objectives, reward states and daily/weekly pacing.
- Badge collection: collection structure, progress, earned/locked details.
- Privacy and account: account actions, confirmations, data and account controls.
- Language, game audio and vibration: persisted preferences and integration with
  gameplay feedback. Language work includes actual translated UI, not a cosmetic
  language switch.
- Linkball Pro: understandable benefits, purchase/restore/error states, consistent
  presentation of actual store prices and existing entitlements.
