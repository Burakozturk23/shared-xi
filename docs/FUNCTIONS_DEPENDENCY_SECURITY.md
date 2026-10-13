# Functions dependency security update — 2026-10-09

The reported audit contained 18 vulnerable dependency entries (14 moderate,
3 high, 1 critical). These counts describe npm advisory matches, not evidence
that the application was exploited.

## Changes

- Update `firebase-admin` to ^14.5.0 and `firebase-functions` to ^7.4.0. The
  Functions SDK declares Admin 14 compatibility; the configured Node 24 runtime
  meets Admin 14's Node >=22 requirement.
- Replace removed legacy Admin namespace calls with modular app, database and
  auth entry points. Default app, database paths, function names, regions and
  business behavior are unchanged.
- Remove unused `firebase-functions-test`. This project runs `node --test` with
  its own transport harness; no test imported that package. Its obsolete helper
  dependencies and peer dependency tree are no longer installed.
- Refresh the lockfile, including compatible fixes for the reported
  proxy-addr, grpc-js, brace-expansion, js-yaml, qs and busboy advisories.
- Add a real SDK bootstrap regression test to complement the mocked transport
  tests. It loads the actual handlers and resolves modular Auth/Database clients
  using a demo project and local emulator addresses; no production request is made.
- Add `npm audit --audit-level=moderate` to the Functions CI gate.

No forced install, audit suppression, legacy peer dependency flag, or dependency
override was used. Remaining deprecation notices from ESLint 8 are separate from
known npm audit findings; an ESLint major migration is outside this fix.

## Verified locally

Node 24.19.0: clean `npm ci --ignore-scripts`, lint, all 244 tests (including real
SDK bootstrap) and a full `npm audit`: 0 vulnerabilities on 2026-10-09. Audit
findings can change as new advisories are published.

This is an SDK major upgrade, so deployment and physical app smoke tests must
still be performed with the target Firebase project. Use the reviewed branch's
package.json and package-lock.json together, then run npm ci; do not run
`npm audit fix --force` on the old lockfile.

Official migration notes:
https://firebase.google.com/support/release-notes/admin/node#version_1400_-_8_june_2026
