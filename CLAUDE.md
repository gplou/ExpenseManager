# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

> This project uses **FVM** (`fvm flutter` instead of `flutter`). `build_release.sh` already wraps it; use `fvm flutter` for manual commands.

**Run the app:**
```bash
fvm flutter run --dart-define-from-file=dart_defines.json
```

**Build:**
```bash
fvm flutter build apk --dart-define-from-file=dart_defines.json   # Android debug APK
bash build_release.sh                                              # Android release AAB
fvm flutter build ios --dart-define-from-file=dart_defines.json   # iOS
```

**Code generation** (required after modifying `@freezed` models or `@riverpod` providers):
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n   # regenerate localization from .arb files
```

**Tests:**
```bash
fvm flutter test                              # all tests
fvm flutter test test/features/transactions/  # single feature
fvm flutter test test/unit/some_test.dart     # single file
bash tool/coverage.sh                         # coverage report (lcov + per-file %)
```

**Lint:**
```bash
flutter analyze
```

## Environment Setup

All secrets are injected via `dart_defines.json` (not committed). Required keys:

```json
{
  "SUPABASE_URL": "...",
  "SUPABASE_ANON_KEY": "...",
  "GOOGLE_WEB_CLIENT_ID": "...",
  "REVENUECAT_ANDROID_KEY": "...",
  "REVENUECAT_IOS_KEY": "...",
  "POSTHOG_API_KEY": "..."
}
```

`AppConfig` (`lib/core/config/app_config.dart`) validates these at startup via `const String.fromEnvironment`.

## Architecture

### Layer Structure (per feature)

```
features/<feature>/
  data/         # repositories (Supabase, SQLite, RevenueCat)
  domain/       # @freezed models, repository contracts
  presentation/
    providers/  # Riverpod providers / AsyncNotifiers
    screens/
    widgets/
```

### State Management

Riverpod 3.x with code generation (`riverpod_annotation`):
- **Plain `Provider`** for repository singletons in `data/`
- **`@riverpod` function providers** for computed/derived state in `presentation/providers/`
- **`AsyncNotifier`** for async state with CRUD actions (e.g., `TransactionsNotifier`, `AuthNotifier`, `SubscriptionNotifier`)

Never put business logic in widgets. Widgets call notifier methods and watch providers.

### Data Layer

**Remote:** Supabase (PostgreSQL + Auth + Edge Functions). Each feature has a repository implementing a contract interface (`*_repository_contract.dart`).

**Local cache:** SQLite via `sqflite`. `LocalDatabase` (`lib/core/local_db/local_database.dart`) is a lazy-open singleton. Tables: `transactions`, `recurring_transactions`, `pending_operations`.

**Offline sync:** `OfflineSyncService` runs in the background and drains `pending_operations`. `InitialSyncService` hydrates PRO users on first load. Conflict resolution is last-write-wins.

**Offline-aware pattern:** `OfflineAwareTransactionsRepository` wraps remote + local repos, falling back to SQLite when connectivity is absent.

### Error Handling

Sealed `AppFailure` hierarchy (`lib/core/errors/failures.dart`): `AuthFailure`, `NetworkFailure`, `ServerFailure`, `CacheFailure`, `ValidationFailure`, `RateLimitFailure`, `UnexpectedFailure`. Repositories return `AppFailure` subtypes — never throw raw exceptions. Presentation layer maps failures to localized UI messages.

### Navigation

GoRouter 17.x. All route names/paths are constants in `AppRoutes` (`lib/core/config/router.dart`) — never hardcode path strings inline. The router subscribes to Supabase `authStateChanges` via `_RouterRefreshNotifier` to re-evaluate redirects without rebuilding the router.

Deep links use the `expensemanager://` URI scheme (e.g., home widget actions).

### Subscription / Paywall

RevenueCat (`purchases_flutter`) manages entitlements. `SubscriptionNotifier` (`lib/features/subscription/subscription_provider.dart`) syncs RC with Supabase (promo codes, redemptions), caches status for 4 hours, and rate-limits promo attempts (3 failures → 30s cooldown). PRO gate: check the entitlement before enabling offline sync, chat, export, and removing ads.

### AI Features

All AI calls go through Supabase Edge Functions, which proxy to **Gemini 2.5 Flash Lite** (`GOOGLE_AI_KEY` set as a Supabase secret — not in `dart_defines.json`).

- **Voice parsing:** `VoiceTransactionParser` (speech_to_text → Edge Function `parse-voice-transaction`) in `lib/features/transactions/data/`
- **Image parsing:** `ImageTransactionParser` (image_picker → Edge Function `parse-image-transaction`)
- **Financial chat:** `ChatRepository` → Edge Function `chat-transactions`
- Rate limiting: `AiRateLimiter` (`lib/core/utils/ai_rate_limiter.dart`) allows max 7 calls/minute (shared across voice + image)

### Localization

4 locales: Spanish (`es`), English (`en`), French (`fr`), German (`de`). Source files are `.arb` in `lib/l10n/`. Run `flutter gen-l10n` to regenerate `AppLocalizations`. Category keys are stored in Spanish in the DB; translation happens at the presentation layer via `TransactionCategories`.

### Analytics

`AnalyticsService` (`lib/core/services/analytics_service.dart`) is a thin static wrapper over PostHog. All methods are fire-and-forget (errors are swallowed). `AnalyticsRouteObserver` (`lib/core/services/analytics_route_observer.dart`) wires GoRouter navigation to PostHog screen events automatically. Never call PostHog directly — always go through `AnalyticsService`.

### Ads

Google Mobile Ads (`google_mobile_ads: ^8.0.0`) with `app_tracking_transparency` for iOS ATT prompt. Ads are gated behind the PRO entitlement — PRO users see no ads.

### Tutorial

`lib/features/tutorial/` contains an in-app tutorial overlay system (`TutorialOverlay`, `TutorialNotifier`, `TutorialStep`). Tutorial state is driven by `tutorial_notifier.dart` and keyed by `tutorial_keys.dart`.

### Code Generation Files

`*.freezed.dart` and `*.g.dart` are generated — do not edit manually. Run `build_runner` after any changes to `@freezed` data classes or `@riverpod` annotated providers/notifiers.

### Testing

Full conventions live in `test/README.md`. Key points for new tests:

- **Mocks** are centralised in `test/helpers/mocks.dart`. Add new mocks there rather than declaring one-off mocks inside test files. Call `registerCommonFallbacks()` once in `setUpAll` when using `any()` with `DateTime`/`Duration`/`Package`/maps.
- **Riverpod**: build containers with `makeContainer([overrides])` from `helpers/provider_container_helper.dart` — it auto-disposes. Override the repository provider, not the notifier.
- **SQLite**: `await useInMemoryDatabase()` in `setUp` (from `helpers/local_db_helper.dart`) opens an in-memory DB, creates the schema, and registers tear-down.
- **Supabase Edge Functions**: stub `SupabaseClient.functions.invoke(...)` via `stubFunctionInvoke()` + `okFunctionResponse()` from `helpers/supabase_function_helper.dart`. The AI parsers (`voice_transaction_parser`, `image_transaction_parser`) and `chat_repository` all go through this path.
- **Time**: production code should depend on `package:clock` and call `clock.now()` (not `DateTime.now()`). Tests pin time with `withFixedClock()` / `withFakeAsyncAndClock()` from `helpers/clock_helper.dart`.
- **Widget tests**: use `pumpWithProviders` / `pumpScreen` from `helpers/pump_app.dart` for `ProviderScope` + `MaterialApp` + l10n preloaded.

Don't hit the real network, RevenueCat, or platform channels from `test/` — those belong in `integration_test/` (planned, not yet present).
