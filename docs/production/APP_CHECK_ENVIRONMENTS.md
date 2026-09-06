# Linkball App Check environment policy

## Goal

Use three separate App Check trust paths without ever committing a debug secret:

| Environment | Provider | Secret handling |
|---|---|---|
| Local emulator / local test device | Debug provider | Firebase Android SDK generates a device-local debug secret. Register it once in Firebase Console for the correct Android app. |
| CI Android instrumentation | Debug provider | Use a dedicated Console-generated token stored only in the CI secret store as `LINKBALL_APP_CHECK_DEBUG_TOKEN`. |
| Production release | Play Integrity | No debug secret. Release builds must always use Play Integrity. |

## Canonical Android Firebase app

The canonical app ID is read from `lib/firebase_options.dart` and `firebase.json` must match it.

The local verification script also checks `android/app/google-services.json` without copying or printing API keys. The Android client must use package:

`com.burakozturk.linkball`

## Local emulator / device

Interactive Flutter debug/profile builds use `AndroidDebugProvider`.

Firebase's Android debug provider generates and stores its own local debug secret. Standard interactive Flutter usage does **not** provide a supported Dart API for forcing an arbitrary pre-existing Console token into that provider.

Therefore:

1. Keep one token per local emulator/test-device install.
2. Register the token shown by `DebugAppCheckProvider` under the canonical Android Firebase app.
3. Give it a clear label such as `LOCAL-BERAT-EMULATOR`.
4. Do not clear app data unless you intentionally want a new local token.
5. Never commit or paste the token into project files.

Helper:

`.\scripts\app_check\run_capture_local_app_check_token.bat`

The helper only reads logcat and prints the token locally. It does not save it.

## CI

Create a separate App Check debug token in Firebase Console, label it for CI, and store it in the CI platform's encrypted secret store using:

`LINKBALL_APP_CHECK_DEBUG_TOKEN`

`android/app/build.gradle.kts` passes this value to Android instrumentation as the official `firebaseAppCheckDebugSecret` runner argument when the environment variable exists.

Do **not** place the token value in YAML, Gradle, Dart, `.env`, docs, or repository secrets files.

For GitHub Actions, the workflow environment should map an encrypted repository/environment secret to the variable, for example conceptually:

```yaml
env:
  LINKBALL_APP_CHECK_DEBUG_TOKEN: ${{ secrets.LINKBALL_APP_CHECK_DEBUG_TOKEN }}
```

Only jobs that actually run Android instrumentation/Firebase integration tests need this secret.

## Production

`CloudBootstrap` must keep this compile-time rule:

- `kReleaseMode == true` -> `AndroidPlayIntegrityProvider`
- non-release debug/profile -> `AndroidDebugProvider`

A CI/local environment variable must never be able to downgrade a release build to the debug provider.

Before enabling or tightening App Check enforcement, review App Check metrics for legitimate requests.

## Token rotation

If a debug token is exposed:

1. Revoke/delete it immediately in Firebase Console.
2. Generate/register a replacement only for the affected environment.
3. Update the CI encrypted secret if the CI token rotated.
4. Do not rotate unrelated local/CI tokens.

Keep Local and CI tokens separate so one compromise does not require rotating every environment.
