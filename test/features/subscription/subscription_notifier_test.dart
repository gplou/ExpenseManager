import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:expense_manager/features/subscription/domain/subscription_expiry_calculator.dart';
import 'package:expense_manager/features/subscription/domain/subscription_repository_contract.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepositoryContract {}

class MockPackage extends Mock implements Package {}

/// These tests verify the business logic that the SubscriptionNotifier
/// applies to repository results. Because the notifier's build() method
/// calls RevenueCat native SDK methods (Purchases.logIn, addCustomerInfoUpdateListener)
/// which are not available in a pure Dart test environment, we test the
/// *state transition logic* directly rather than instantiating the full
/// AsyncNotifier via ProviderContainer.
///
/// For full integration tests of the notifier lifecycle, a Flutter integration
/// test with platform channel mocks would be required.
void main() {
  late MockSubscriptionRepository mockRepo;

  setUp(() {
    mockRepo = MockSubscriptionRepository();

    // Register fallback values for methods that take required params.
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(MockPackage());
  });

  // ── State transition: initial (no subscription) ─────────────────────────

  group('Initial state logic', () {
    test('fresh user with no remote subscription yields non-PRO state', () async {
      when(() => mockRepo.fetchRemoteSubscription())
          .thenAnswer((_) async => (expiresAt: null, source: null));
      when(() => mockRepo.checkTrialUsed()).thenAnswer((_) async => false);
      when(() => mockRepo.getCurrentRCStatus()).thenAnswer((_) async => null);

      final remote = await mockRepo.fetchRemoteSubscription();
      final trialUsed = await mockRepo.checkTrialUsed();

      final state = SubscriptionState(
        expiresAt: remote.expiresAt,
        source: remote.source,
        trialUsed: trialUsed,
      );

      expect(state.isPro, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.canStartTrial, isTrue);
    });
  });

  // ── State transition: purchase() ────────────────────────────────────────

  group('Purchase flow state transitions', () {
    test('purchase with PRO result updates state to isPro=true', () async {
      final expires = DateTime.now().add(const Duration(days: 31));
      when(() => mockRepo.purchaseProPlan(any())).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'google_play',
          expiresAt: expires,
          storeTxId: 'tx_1',
        ),
      );

      final result = await mockRepo.purchaseProPlan(MockPackage());

      // Simulate the state transition that the notifier would apply.
      expect(result.isPro, isTrue);
      final newState = SubscriptionState(
        expiresAt: result.expiresAt ?? DateTime.now().add(const Duration(days: 31)),
        source: result.source,
      );
      expect(newState.isPro, isTrue);
      expect(newState.expiresAt!.isAfter(DateTime.now()), isTrue);
    });

    test('cancelled purchase leaves state non-loading with no error', () {
      // Simulate: purchase throws RCPurchaseCancelledException
      const current = SubscriptionState(isLoading: true);

      // Notifier catches the exception and does:
      final afterCancel = current.copyWith(isLoading: false, clearError: true);

      expect(afterCancel.isLoading, isFalse);
      expect(afterCancel.errorCode, isNull);
      expect(afterCancel.isPro, isFalse);
    });

    test('purchase error sets errorCode in state', () {
      const current = SubscriptionState(isLoading: true);

      // Notifier catches RCPurchaseException and does:
      final afterError = current.copyWith(
        isLoading: false,
        errorCode: SubscriptionErrorCode.purchaseFailed,
      );

      expect(afterError.isLoading, isFalse);
      expect(afterError.errorCode, SubscriptionErrorCode.purchaseFailed);
      expect(afterError.isPro, isFalse);
    });

    test('non-PRO restore result clears loading without error', () {
      const current = SubscriptionState(isLoading: true);

      // Restore found nothing — result.isPro is false
      final afterRestore = current.copyWith(isLoading: false, clearError: true);

      expect(afterRestore.isLoading, isFalse);
      expect(afterRestore.errorCode, isNull);
      expect(afterRestore.isPro, isFalse);
    });

    test('successful restore with PRO result sets isPro=true', () async {
      final expires = DateTime.now().add(const Duration(days: 30));
      when(() => mockRepo.restoreProPlan()).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'app_store',
          expiresAt: expires,
          storeTxId: 'tx_restore',
        ),
      );

      final result = await mockRepo.restoreProPlan();

      expect(result.isPro, isTrue);
      final newState = SubscriptionState(
        expiresAt: result.expiresAt,
        source: result.source,
      );
      expect(newState.isPro, isTrue);
      expect(newState.source, 'app_store');
    });

    test('purchase with pending discount applies bonus days to expiry', () async {
      // Simulates _applyRCResult when a discount promo is pending.
      // RC returns an expiresAt; the notifier must add discountBonusDays on top
      // via SubscriptionExpiryCalculator (the same code path production uses).
      const pendingState = SubscriptionState(pendingDiscountPercentage: 100);
      // 100% discount → bonusDays = kSubscriptionDays (30)
      expect(pendingState.discountBonusDays, 30);

      final rcExpiry = DateTime.utc(2026, 5, 1);
      final effectiveExpiry = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: rcExpiry,
        bonusDays: pendingState.discountBonusDays,
        fallbackPeriodDays: 30,
      );

      final newState = SubscriptionState(
        expiresAt: effectiveExpiry,
        source: 'play_store',
        trialUsed: pendingState.trialUsed,
      );

      expect(newState.isPro, isTrue);
      expect(effectiveExpiry, DateTime.utc(2026, 5, 31));
      expect(
        effectiveExpiry.isAfter(rcExpiry),
        isTrue,
        reason: 'Bonus days must extend the RC expiry',
      );
    });

    test(
      'BUG REGRESSION: bonus days are applied even when the store returns an expiry',
      () {
        // Old code:
        //   final expiresAt = result.expiresAt ??
        //       DateTime.now().add(Duration(days: kSubscriptionDays + bonusDays));
        // With a non-null RC expiry the `??` short-circuits and bonusDays
        // never reach the persisted value — the user loses the discount
        // they redeemed. This test guards that regression.
        final rcExpiry = DateTime.utc(2026, 1, 1);
        const bonusDays = 15;
        final effective = SubscriptionExpiryCalculator.effectiveExpiry(
          storeExpiry: rcExpiry,
          bonusDays: bonusDays,
          fallbackPeriodDays: 30,
        );
        expect(effective, DateTime.utc(2026, 1, 16));
        expect(
          effective.isAfter(rcExpiry),
          isTrue,
          reason: 'Discount bonus must not be discarded when RC returns expiry',
        );
      },
    );
  });

  // ── State transition: redeemPromoCode() ─────────────────────────────────

  group('Promo code redemption state transitions', () {
    test('subscription promo updates state to PRO with promo_code source',
        () async {
      when(() => mockRepo.redeemPromoCode(any())).thenAnswer(
        (_) async => const PromoResult(type: 'subscription', durationDays: 30),
      );

      final result = await mockRepo.redeemPromoCode('TEST30');

      expect(result.isSubscription, isTrue);

      // Simulate what notifier does: base = now (user not PRO), add duration
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: result.durationDays));
      final newState = SubscriptionState(
        expiresAt: expiresAt,
        source: 'promo_code',
      );

      expect(newState.isPro, isTrue);
      expect(newState.source, 'promo_code');
    });

    test('discount promo sets pendingDiscountPercentage without granting PRO',
        () async {
      when(() => mockRepo.redeemPromoCode(any())).thenAnswer(
        (_) async => const PromoResult(
          type: 'discount',
          durationDays: 0,
          discountPercentage: 50,
        ),
      );

      final result = await mockRepo.redeemPromoCode('DISC50');

      expect(result.isDiscount, isTrue);

      const current = SubscriptionState();
      final newState = current.copyWith(
        pendingDiscountPercentage: result.discountPercentage,
      );

      expect(newState.isPro, isFalse);
      expect(newState.hasDiscount, isTrue);
      expect(newState.pendingDiscountPercentage, 50);
    });
  });

  // ── State transition: startFreeTrial() ──────────────────────────────────

  group('Free trial state transitions', () {
    test('startFreeTrial updates state to PRO with free_trial source',
        () async {
      final now = DateTime.now();
      final expiresAt = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 4));

      when(() => mockRepo.startFreeTrial())
          .thenAnswer((_) async => expiresAt);

      final result = await mockRepo.startFreeTrial();

      final newState = SubscriptionState(
        expiresAt: result,
        source: 'free_trial',
        trialUsed: true,
      );

      expect(newState.isPro, isTrue);
      expect(newState.source, 'free_trial');
      expect(newState.trialUsed, isTrue);
      expect(newState.canStartTrial, isFalse);
    });

    test('startFreeTrial error keeps state non-PRO', () {
      when(() => mockRepo.startFreeTrial())
          .thenThrow(Exception('DB error'));

      // Simulate: notifier catches and sets the trial-failed error code
      const current = SubscriptionState(isLoading: true);
      final afterError = current.copyWith(
        isLoading: false,
        errorCode: SubscriptionErrorCode.trialFailed,
      );

      expect(afterError.isPro, isFalse);
      expect(afterError.isLoading, isFalse);
      expect(afterError.errorCode, SubscriptionErrorCode.trialFailed);
    });
  });

  // ── RC reconciliation logic ─────────────────────────────────────────────

  group('RC + Supabase reconciliation', () {
    test('RC entitlement with later expiry overrides Supabase', () async {
      final supabaseExpiry = DateTime.now().add(const Duration(days: 10));
      final rcExpiry = DateTime.now().add(const Duration(days: 30));

      when(() => mockRepo.fetchRemoteSubscription())
          .thenAnswer((_) async => (expiresAt: supabaseExpiry, source: 'promo_code'));
      when(() => mockRepo.checkTrialUsed()).thenAnswer((_) async => false);
      when(() => mockRepo.getCurrentRCStatus()).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'google_play',
          expiresAt: rcExpiry,
          storeTxId: 'tx_rc',
        ),
      );

      final remote = await mockRepo.fetchRemoteSubscription();
      final rcStatus = await mockRepo.getCurrentRCStatus();
      final trialUsed = await mockRepo.checkTrialUsed();

      DateTime? expiresAt = remote.expiresAt;
      String? source = remote.source;

      if (rcStatus != null && rcStatus.isPro && rcStatus.expiresAt != null) {
        final rcExp = rcStatus.expiresAt!;
        if (expiresAt == null || rcExp.isAfter(expiresAt)) {
          expiresAt = rcExp;
          source = rcStatus.source;
        }
      }

      final state = SubscriptionState(
        expiresAt: expiresAt,
        source: source,
        trialUsed: trialUsed,
      );

      expect(state.isPro, isTrue);
      expect(state.source, 'google_play');
      expect(state.expiresAt, rcExpiry);
    });

    test('Supabase expiry used when RC has no active entitlement', () async {
      final supabaseExpiry = DateTime.now().add(const Duration(days: 15));

      when(() => mockRepo.fetchRemoteSubscription())
          .thenAnswer((_) async => (expiresAt: supabaseExpiry, source: 'promo_code'));
      when(() => mockRepo.checkTrialUsed()).thenAnswer((_) async => false);
      when(() => mockRepo.getCurrentRCStatus()).thenAnswer((_) async => null);

      final remote = await mockRepo.fetchRemoteSubscription();
      final rcStatus = await mockRepo.getCurrentRCStatus();

      DateTime? expiresAt = remote.expiresAt;
      String? source = remote.source;

      if (rcStatus != null && rcStatus.isPro && rcStatus.expiresAt != null) {
        expiresAt = rcStatus.expiresAt;
        source = rcStatus.source;
      }

      final state = SubscriptionState(expiresAt: expiresAt, source: source);

      expect(state.isPro, isTrue);
      expect(state.source, 'promo_code');
      expect(state.expiresAt, supabaseExpiry);
    });
  });

  // ── RC identity transitions ─────────────────────────────────────────────

  group('RevenueCat identity transitions', () {
    // Mirrors the decision logic in SubscriptionNotifier._syncRevenueCatIdentity.
    // We reproduce it here as a pure function so the transitions are tested
    // without touching the RC SDK (which requires platform channels).
    ({bool logOut, bool logIn, String? next}) syncIdentity({
      required String? previous,
      required String? incoming,
    }) {
      if (previous == incoming) {
        return (logOut: false, logIn: false, next: previous);
      }
      final shouldLogOut = previous != null;
      final shouldLogIn = incoming != null;
      return (logOut: shouldLogOut, logIn: shouldLogIn, next: incoming);
    }

    test('first login calls logIn and no logOut', () {
      final t = syncIdentity(previous: null, incoming: 'user-1');
      expect(t.logIn, isTrue);
      expect(t.logOut, isFalse);
      expect(t.next, 'user-1');
    });

    test('same user on rebuild is a no-op', () {
      final t = syncIdentity(previous: 'user-1', incoming: 'user-1');
      expect(t.logIn, isFalse);
      expect(t.logOut, isFalse);
      expect(t.next, 'user-1');
    });

    test('logout (user → null) calls logOut and skips logIn', () {
      // BUG REGRESSION: the previous `onDispose(() { if (user == null) logOut(); })`
      // captured the OLD user, so a non-null → null transition never fired
      // logOut. This direct check must stay green.
      final t = syncIdentity(previous: 'user-1', incoming: null);
      expect(t.logOut, isTrue);
      expect(t.logIn, isFalse);
      expect(t.next, isNull);
    });

    test('account switch (userA → userB) calls logOut AND logIn', () {
      final t = syncIdentity(previous: 'user-a', incoming: 'user-b');
      expect(t.logOut, isTrue);
      expect(t.logIn, isTrue);
      expect(t.next, 'user-b');
    });
  });

  // ── Listener race vs. explicit purchase flow ────────────────────────────

  group('CustomerInfoUpdateListener race guard', () {
    // Mirrors _handleRCUpdate's guard: when an explicit purchase/restore is
    // in flight, the listener must no-op so it doesn't clobber Supabase with
    // an expiry that lacks the discount bonus days.
    bool shouldProcessListener({
      required bool purchaseInFlight,
      required bool hasSession,
      required bool isPro,
      required DateTime? expiresAt,
    }) {
      if (purchaseInFlight) return false;
      if (!hasSession) return false;
      if (!isPro) return false;
      if (expiresAt == null) return false;
      return true;
    }

    test('skips listener while a purchase is in flight', () {
      final ok = shouldProcessListener(
        purchaseInFlight: true,
        hasSession: true,
        isPro: true,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(ok, isFalse,
          reason: 'Explicit purchase flow owns the upsert; listener must yield');
    });

    test('skips listener when no Supabase session', () {
      // BUG REGRESSION: without this guard the RC callback hit
      // `currentUser!.id` and threw during logout-driven RC callbacks.
      final ok = shouldProcessListener(
        purchaseInFlight: false,
        hasSession: false,
        isPro: true,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(ok, isFalse);
    });

    test('skips when entitlement inactive', () {
      final ok = shouldProcessListener(
        purchaseInFlight: false,
        hasSession: true,
        isPro: false,
        expiresAt: null,
      );
      expect(ok, isFalse);
    });

    test('processes listener on a legitimate background renewal', () {
      final ok = shouldProcessListener(
        purchaseInFlight: false,
        hasSession: true,
        isPro: true,
        expiresAt: DateTime.now().add(const Duration(days: 31)),
      );
      expect(ok, isTrue);
    });
  });

  // ── Promo code rate limiting ────────────────────────────────────────────

  group('Promo code rate limiting logic', () {
    test('3 consecutive failures triggers cooldown', () async {
      when(() => mockRepo.redeemPromoCode(any()))
          .thenThrow(const PromoCodeException('Codigo no valido'));

      int failedAttempts = 0;
      DateTime? cooldownUntil;

      for (int i = 0; i < 3; i++) {
        try {
          await mockRepo.redeemPromoCode('BAD');
        } on PromoCodeException {
          failedAttempts++;
          if (failedAttempts >= 3) {
            cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
            failedAttempts = 0;
          }
        }
      }

      expect(cooldownUntil, isNotNull);
      expect(cooldownUntil!.isAfter(DateTime.now()), isTrue);
    });
  });
}
