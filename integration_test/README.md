# Integration tests

End-to-end tests that run on a real device/simulator. Unlike `test/`,
which executes in a host VM with mocks, these drive the real app
binary, real platform channels, and (when configured) a real backend.

## Run locally

```bash
# iOS simulator (boot a sim first):
fvm flutter test integration_test --dart-define-from-file=dart_defines.json

# Android emulator:
fvm flutter test integration_test --dart-define-from-file=dart_defines.json -d emulator-5554

# A single file:
fvm flutter test integration_test/auth_flow_test.dart --dart-define-from-file=dart_defines.json
```

## When to write an integration test (vs. a widget test in `test/`)

Reach for `integration_test/` when **any** of the following hold:

- The flow needs platform channels we can't easily mock (RevenueCat
  paywall, speech recognition, image picker, home widget callbacks,
  flutter_secure_storage hardware backing, etc.).
- It exercises GoRouter navigation across more than 2-3 screens, since
  widget tests with a real router quickly become unmaintainable.
- The user value is "does this whole flow still work end-to-end?" —
  signup, paywall, export, deep link.

Everything else (widget rendering, notifier logic, repository contract
behavior) belongs in `test/`. The bar for adding here is high because
these tests are slower (~10× a widget test) and require a device.

## Conventions

- One file per user flow (`auth_flow_test.dart`, `paywall_flow_test.dart`).
- Reset state per test: clear shared prefs, sign out, drop local DB.
- Tag long flows with `@Tags(['e2e'])` so CI can run a fast subset.
- Don't hit the real Supabase project in CI — point at a test project
  via `SUPABASE_URL` in the CI env. For local runs, dev project is OK.
