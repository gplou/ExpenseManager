# Plan: Testing roadmap F1 + F2 + F3

**Status:** awaiting user adjustments before execution.
**Author:** Claude session, 2026-05-22.
**Goal:** raise coverage from 57.53% to ~78% across three independent phases.

## User decisions (locked in)

- **Delivery**: one commit per phase, on the current branch (no separate PRs).
- **CI gate**: raise threshold after each phase (55 → 60 → 70 → 76).
- **Plan status**: user wants to adjust scope/details before kicking off.

## Coverage math

- Today: **3865 / 6718 lines = 57.53%**.
- For 90%: would need +2181 covered lines (out of scope for this plan).
- This plan targets ~78% = +1370 lines covered.

| Phase | Coverage delta | Cumulative | Est. effort |
| --- | ---: | ---: | ---: |
| F1 — `PurchasesGateway` | +5.8pp | **63.3%** | 3-4 h |
| F2 — `HomeWidgetGateway` + dashboard | +9.4pp | **72.7%** | 6-8 h |
| F3 — Big screens | +5.2pp | **77.9%** | 5-7 h |

---

## F1 — `PurchasesGateway` + subscription tests · 63% (+5.8pp)

**Objective:** unlock `SubscriptionNotifier.build()`, `SubscriptionRepository`,
and `pro_screen.dart` by hiding RevenueCat behind an interface.

### F1.1 — Production refactor

Create `lib/features/subscription/data/purchases_gateway.dart`:

```dart
abstract interface class PurchasesGateway {
  Future<void> configure(String apiKey, {String? appUserId});
  Future<CustomerInfo> logIn(String userId);
  Future<void> logOut();
  Future<CustomerInfo> getCustomerInfo();
  Future<CustomerInfo> purchasePackage(Package package);
  Future<CustomerInfo> restorePurchases();
  Future<Offerings> getOfferings();
  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener);
  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener);
}

class RevenueCatPurchasesGateway implements PurchasesGateway {
  // 1:1 delegation to Purchases.* statics
}

final purchasesGatewayProvider =
    Provider<PurchasesGateway>((ref) => RevenueCatPurchasesGateway());
```

**Callsites to migrate (replace static `Purchases.*` calls):**

- `lib/features/subscription/subscription_provider.dart` — `_identifyCurrentUser`,
  `build()`, `signOut`/`deleteAccount` wiring (4 sites).
- `lib/features/subscription/subscription_repository.dart` — `purchaseProPlan`,
  `restoreProPlan`, `getCurrentRCStatus` (3 methods).
- `lib/features/subscription/pro_screen.dart` — the `offeringsProvider`
  FutureProvider (1 line).
- `lib/features/auth/presentation/providers/auth_provider.dart` —
  `signOut`, `deleteAccount` (each has a `Purchases.logOut().ignore()`).

### F1.2 — New tests (~25)

- `test/features/subscription/subscription_notifier_build_test.dart` — cover
  the actual `build()` path that today is untested: login, addListener,
  initial state hydration, race-condition guard.
- `test/features/subscription/subscription_repository_test.dart` —
  `purchaseProPlan`, `restoreProPlan`, `getCurrentRCStatus` against a
  `MockPurchasesGateway`.
- `test/features/subscription/pro_screen_test.dart` — smoke: loading, error,
  PRO body, free body. `offeringsProvider` overridden with stubbed `Offering`.

**Existing tests to update:** `test/features/subscription/subscription_notifier_test.dart`
must pass the gateway into the manual notifier constructions.

### F1.3 — Validation

- `fvm flutter analyze` clean
- `fvm flutter test` passes (897 existing + ~25 new)
- `bash tool/coverage.sh` ≥ 63%
- Bump CI threshold: 55 → 60
- Commit message draft:
  `test(subscription): inject PurchasesGateway and cover SubscriptionNotifier.build`

---

## F2 — `HomeWidgetGateway` + dashboard ecosystem · 73% (+9.4pp)

**Objective:** cover the dashboard family that depends on platform channels
(`HomeWidget`, `image_picker`, `speech_to_text`).

### F2.1 — Production refactor

Create:

- `lib/core/services/home_widget_gateway.dart` — wraps `HomeWidget.widgetClicked`.
- `lib/core/services/voice_input_gateway.dart` — wraps `SpeechToText` (initialize,
  listen, stop).
- `lib/core/services/image_input_gateway.dart` — wraps `ImagePicker.pickImage`.

Each exposes an injectable `Provider` and a real implementation delegating 1:1
to its package.

**Callsites to migrate:**

- `lib/features/dashboard/dashboard_screen.dart:51` — `HomeWidget.widgetClicked`
- `lib/features/dashboard/widgets/dashboard_fab.dart` — `SpeechToText`, `ImagePicker`
- `lib/features/transactions/presentation/widgets/voice_transaction_button.dart`
  — same as above

Also extract the private dialogs inside `app_drawer.dart` into their own files
(`_PromoCodeDialog`, `_EditNameSheet`) as `@visibleForTesting` public widgets so
they can be tested in isolation.

### F2.2 — New tests (~40)

- `test/widget/features/dashboard/dashboard_screen_test.dart` — smoke with
  overrides of `transactionsSummaryProvider`, `recentTransactionsProvider`,
  `currentUserProvider`, `homeWidgetGatewayProvider` (StreamController),
  `tutorialProvider` (override notifier). ~8 tests.
- `test/widget/features/dashboard/app_drawer_test.dart` — sections render,
  `EditNameSheet` (with `MockGoTrueClient.updateUser`), `PromoCodeDialog` (with
  `MockSubscriptionRepository`), `confirmDeleteAccount` (with
  `MockAuthRepository`). ~12 tests.
- `test/widget/features/dashboard/quick_add_sheet_test.dart` — shortcuts render,
  income/expense toggle, save flow with `_FakeTransactionsNotifier`. ~10 tests.
- `test/widget/features/dashboard/dashboard_fab_test.dart` — FAB renders, opens
  quick_add, expands radial during tutorial. ~6 tests.
- `test/widget/features/transactions/voice_transaction_button_test.dart`
  — add listening + processing states with `MockVoiceInputGateway`. ~4 tests.

Add `test/helpers/dashboard_overrides.dart` — a fluent builder for the long
list of overrides each dashboard test needs.

### F2.3 — Validation

- Coverage ≥ 73%
- Bump CI threshold: 60 → 70
- Commit message draft:
  `test(dashboard): inject HomeWidget/Voice/Image gateways and cover dashboard family`

---

## F3 — Big screens · 78% (+5.2pp)

**Objective:** close `add_transaction_screen.dart` (319 lines uncovered, 45%
today) and `tutorial_overlay.dart` visual parts.

### F3.1 — `add_transaction_screen.dart`

**No production refactor needed** — its providers are already injectable.
Tests only.

Extend `test/widget/features/transactions/add_transaction_screen_test.dart`
with ~15 tests:

- Save expense → calls `transactionsNotifierProvider.create` with correct
  data (using `_FakeTransactionsNotifier`).
- Save income with currency override.
- Type toggle clears the selected category.
- Subcategory picker opens with `subcategoriesProvider` family override.
- Recurring toggle reveals `_RecurringFrequencyPicker`.
- Edit mode pre-populates fields from the `transaction` param.
- Voice mode pre-populates from `voiceData` param.
- Validation: amount=0 shows the inline error.
- Validation: no category shows a snackbar.
- Delete button (in edit) calls `notifier.delete`.
- Date picker changes the date.

### F3.2 — `tutorial_overlay.dart` visuals

Extract the private `_TooltipCard` and `_StepDots` into their own file and
make them public `@visibleForTesting` so they can be tested in isolation.

New file: `lib/features/tutorial/tutorial_tooltip_card.dart` with
`TutorialTooltipCard` and `TutorialStepDots` moved from the overlay.

Tests:

- `test/widget/features/tutorial/tutorial_tooltip_card_test.dart` — tooltip
  renders title+body+icon, back button hidden on first step, next-button
  label flips (next vs finish), step dots render N points, edge case >5
  steps shows the sliding window. ~10 tests.
- For `_SpotlightPainter`: extract as public and test against a mock `Canvas`
  — verify the path has the hole + halo + border. ~5 tests.
  - *Note*: paint-method coverage adds % but limited real value. Optional —
    revisit if user wants to skip.

### F3.3 — Validation

- Coverage ≥ 78%
- Bump CI threshold: 70 → 76
- Commit message draft:
  `test(screens): cover add_transaction flows and tutorial tooltip card`

---

## Execution order

```
F1 → commit → F2 → commit → F3 → commit
```

Each phase is independent and mergeable. Stopping after F1 already gives
useful improvement (subscription covered) without touching the dashboard.

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| `PurchasesGateway` refactor breaks the real purchase flow | Gateway is a 1:1 delegation. Manual smoke test of the paywall on a device before F1 is committed. |
| `app_drawer` internal dialogs are private | Extract to separate `@visibleForTesting` files. No behaviour change. |
| `dashboard_screen` tests become fragile from too many overrides | Build `helpers/dashboard_overrides.dart` with a fluent override builder. |
| `_FakeTransactionsNotifier` must mirror the real notifier API | Subclass + override only methods used in tests. Riverpod 3 supports this. |

## Open questions for the user (the "adjustments" you asked about)

1. **F1 scope**: minimal (only what tests require) vs. opportunistic (clean up
   every static `Purchases.*` callsite in the codebase)?
2. **F2 dashboard depth**: pure smoke tests (renders without crashing) vs.
   deep interaction tests (taps, dialogs, navigation)?
3. **F3 add_transaction**: also cover the subcategory flow (which needs
   `subcategoriesProvider` family override + `CreateSubcategoryDialog`)?
4. **Tutorial spotlight painter**: extract and test, or skip? Paint code adds
   % but little real confidence.
5. **Phase order**: keep F1→F2→F3, or reorder (e.g. F3 first since it needs
   no production refactor)?

Answer these (or say "use defaults") and the plan is ready to execute.
