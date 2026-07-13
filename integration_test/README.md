# Integration tests

End-to-end tests that run on a real device/simulator. Unlike `test/`,
which executes in a host VM with mocks, these drive the real app
binary, real platform channels, and a real backend.

## Files

| File | What it covers |
| --- | --- |
| `smoke_test.dart` | App boots to login/dashboard without crashing |
| `transactions_flow_test.dart` | Login → create expense (keypad, category, note) → verify on dashboard → edit → delete |
| `budgets_flow_test.dart` | Login → create budget → FREE limit upgrade dialog → delete |
| `helpers/e2e_helpers.dart` | Boot/reset/login/wait helpers shared by all flows |

## E2E test user

Flows sign in with a dedicated FREE user that exists **only in Supabase
auth** — as a FREE user all its data stays in the device's local SQLite,
so it leaves no rows in the cloud tables. Credentials are injected via
dart-define and are **never committed**:

- Local: `dart_defines_e2e.json` (gitignored) with `E2E_EMAIL` / `E2E_PASSWORD`.
- CI: GitHub secrets `E2E_EMAIL` / `E2E_PASSWORD` (see `.github/workflows/e2e.yml`).

`helpers/e2e_helpers.dart#resetLocalState` wipes the local DB and first-run
flags before each boot, so flows are deterministic and re-runnable.

## Run locally

```bash
# Android emulator (recommended — see iOS caveat below):
fvm flutter test integration_test \
  --dart-define-from-file=dart_defines.json \
  --dart-define-from-file=dart_defines_e2e.json \
  -d emulator-5554

# A single flow:
fvm flutter test integration_test/transactions_flow_test.dart \
  --dart-define-from-file=dart_defines.json \
  --dart-define-from-file=dart_defines_e2e.json \
  -d emulator-5554
```

> **iOS simulator caveat:** on a fresh iOS install the ATT tracking prompt
> is a *native* dialog that `integration_test` cannot tap, blocking boot.
> Either tap it once manually (the choice persists) or run on Android.

## CI

`.github/workflows/e2e.yml` boots an Android emulator (API 34) and runs the
whole `integration_test/` folder on every release tag (`v*`) and on manual
dispatch. Each test file is a full build + install (~10 min each), which is
why it doesn't run per-PR.

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

- One file per user flow, one `testWidgets` per file — `app.main()` can only
  run once per process (`Supabase.initialize` is not re-entrant).
- Find widgets by `TestKeys` (`lib/core/constants/test_keys.dart`) or widget
  type, never by localized text — except through `l10nEn`
  (`AppLocalizationsEn`), since `resetLocalState()` pins the locale to `en`.
- Prefer `settle()` over raw `pumpAndSettle()`: ad banners animate forever
  and would make `pumpAndSettle` time out (that's not a failure).
- Real network involved → wait with `waitFor`/`waitOrScrollTo`, never assume
  the next frame has the result.
