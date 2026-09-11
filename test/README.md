# Testing guide

This document explains how tests are organised in this project, which helpers
to reach for, and the conventions every new test should follow.

> **Goal:** keep `flutter test` fast and deterministic, with ≥90% line
> coverage on `lib/` (excluding generated files).

## Layout

```
test/
  helpers/                # reusable test infrastructure (mocks, fixtures, builders)
  unit/                   # pure logic — no Flutter widgets, no I/O
  widget/                 # widget tests rendered with WidgetTester
  integration/            # multi-layer tests (notifier + repo, sync flows, etc.)
  regression/             # tests guarding specific historical bugs
  features/<name>/        # feature-scoped tests that don't fit above buckets
  core/                   # tests for shared core/ services
  golden/                 # pixel golden tests, tagged `golden` — see below
```

`integration/` here are **in-process** Dart tests, not the on-device
`integration_test/` package. The latter (E2E in the simulator) is planned
for Phase 4 and will live in `integration_test/` at the repo root.

## Helpers

| Helper | Use for |
| --- | --- |
| `helpers/mocks.dart` | Mocktail mocks for every repository contract, Supabase client, RC types, http client. Call `registerCommonFallbacks()` once in `setUpAll`. |
| `helpers/local_db_helper.dart` | `useInMemoryDatabase()` opens an in-memory SQLite DB with the app schema and wires it into `LocalDatabase.instance`. Tear-down is automatic. |
| `helpers/supabase_function_helper.dart` | `stubFunctionInvoke()` + `okFunctionResponse(...)` for tests of code that calls `SupabaseClient.functions.invoke(...)` (AI parsers, chat). |
| `helpers/clock_helper.dart` | `withFixedClock()`, `withFakeAsyncAndClock()` for deterministic time. Production code should call `clock.now()` instead of `DateTime.now()`. |
| `helpers/provider_container_helper.dart` | `makeContainer([overrides])` creates a `ProviderContainer` with auto-`dispose` via `addTearDown`. |

## Conventions

### Mocks
- Every repository in `lib/features/*/data/` has a contract in `domain/`
  and a corresponding `MockX` in `helpers/mocks.dart`. **Do not declare
  one-off mocks inside test files** — add them to `mocks.dart` so the next
  test reuses them.
- Use `mocktail`. Call `registerCommonFallbacks()` (from `mocks.dart`) once
  in `setUpAll` if you use `any()` matchers with `DateTime`, `Duration`,
  `Package`, `Uri`, or maps.

### Riverpod
- Build the container with `makeContainer([overrides])` — never call
  `ProviderContainer()` directly (you'll forget to dispose).
- Override the repository provider, not the notifier itself.
- For notifiers that use `RevenueCat` / native channels in `build()`, test
  the **state-transition logic** directly with a mock contract rather than
  spinning up the full notifier (see `subscription_notifier_test.dart`).

### Time
- Production code should depend on `package:clock` and call `clock.now()`
  (not `DateTime.now()`). Tests use `withFixedClock()` to pin the clock.
- For `Future.delayed` / `Timer` paths, use `withFakeAsyncAndClock()` and
  drive time with `async.elapse(...)`.

### Supabase Edge Functions
```dart
final supabase = MockSupabaseClient();
final functions = MockFunctionsClient();
when(() => supabase.functions).thenReturn(functions);

stubFunctionInvoke(
  functions,
  functionName: 'parse-voice-transaction',
  response: okFunctionResponse({'result': '{"amount":12.5,"category":"Comida"}'}),
);

final parser = VoiceTransactionParser(supabase);
final result = await parser.parse('café cinco euros');
expect(result?.amount, 12.5);
```

### SQLite-backed tests
```dart
setUp(() async {
  await useInMemoryDatabase(); // auto tear-down
  repo = LocalTransactionsRepository(userId: 'user-1');
});
```

### Widget tests
- Wrap the widget under test in `ProviderScope` + `MaterialApp` with
  `AppLocalizations.localizationsDelegates` / `supportedLocales` so `AppLocalizations`
  resolves. Each test file defines its own small builder (e.g. `wrap(...)`,
  `buildSubject()`).
- Stub network providers (`chatRepositoryProvider`,
  `voiceTransactionParserProvider`, etc.) via the `ProviderScope` `overrides` —
  nothing auto-injects fakes.

### Don't
- Don't hit the real network, RevenueCat, or device platform channels
  from `test/` — those belong in `integration_test/`.
- Don't add `// ignore: ...` to silence analyzer warnings in tests; fix
  the root cause (often a missing fallback or a wrong matcher).
- Don't `await Future.delayed` in tests — use `fakeAsync` or rebuild the
  state via the notifier API.

### Golden tests
- Live in `test/golden/`, tagged `golden` (see `dart_test.yaml`). Baselines
  are generated on macOS and **excluded from CI** (`--exclude-tags golden`
  in `ci.yml`) — Skia font rendering differs enough on `ubuntu-latest` to
  produce false positives. See `lib/core/theme/README.md` for the full
  rationale and how to regenerate them.
- `test/golden/flutter_test_config.dart` loads the real Inter font before
  these tests run (`flutter test` renders text as placeholder boxes by
  default); Phosphor icon glyphs still show as boxes — a known harness
  limitation, not a bug.

## Running

```bash
fvm flutter test                          # full suite
fvm flutter test test/unit                # one folder
fvm flutter test --name "promo code"      # by name pattern
bash tool/coverage.sh                     # coverage with filtered lcov
open coverage/lcov_filtered.info          # inspect raw lcov
```

For HTML coverage:
```bash
genhtml coverage/lcov_filtered.info -o coverage/html
open coverage/html/index.html
```
