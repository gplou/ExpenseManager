import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:productivity_app/features/subscription/domain/subscription_repository_contract.dart';
import 'package:productivity_app/features/subscription/subscription_repository.dart';
import 'package:productivity_app/features/subscription/subscription_state.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepositoryContract {}

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
      when(() => mockRepo.purchaseProPlan()).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'google_play',
          expiresAt: expires,
          storeTxId: 'tx_1',
        ),
      );
      when(() => mockRepo.upsertSubscription(
            expiresAt: any(named: 'expiresAt'),
            source: any(named: 'source'),
            storeTxId: any(named: 'storeTxId'),
          )).thenAnswer((_) async {});

      final result = await mockRepo.purchaseProPlan();

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
      expect(afterCancel.purchaseError, isNull);
      expect(afterCancel.isPro, isFalse);
    });

    test('purchase error sets purchaseError in state', () {
      const current = SubscriptionState(isLoading: true);

      // Notifier catches RCPurchaseException and does:
      final afterError = current.copyWith(
        isLoading: false,
        purchaseError: 'Payment failed',
      );

      expect(afterError.isLoading, isFalse);
      expect(afterError.purchaseError, 'Payment failed');
      expect(afterError.isPro, isFalse);
    });

    test('non-PRO restore result clears loading without error', () {
      const current = SubscriptionState(isLoading: true);

      // Restore found nothing — result.isPro is false
      final afterRestore = current.copyWith(isLoading: false, clearError: true);

      expect(afterRestore.isLoading, isFalse);
      expect(afterRestore.purchaseError, isNull);
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
      when(() => mockRepo.upsertSubscription(
            expiresAt: any(named: 'expiresAt'),
            source: any(named: 'source'),
            storeTxId: any(named: 'storeTxId'),
          )).thenAnswer((_) async {});

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
      // RC returns an expiresAt; the notifier should add discountBonusDays on top.
      const pendingState = SubscriptionState(pendingDiscountPercentage: 100);
      // 100% discount → bonusDays = kSubscriptionDays (30)
      expect(pendingState.discountBonusDays, 30);

      final rcExpiry = DateTime.now().add(const Duration(days: 30));
      final bonusDays = pendingState.discountBonusDays;
      final effectiveExpiry = rcExpiry.add(Duration(days: bonusDays));

      final newState = SubscriptionState(
        expiresAt: effectiveExpiry,
        source: 'play_store',
        trialUsed: pendingState.trialUsed,
      );

      expect(newState.isPro, isTrue);
      expect(
        effectiveExpiry.isAfter(rcExpiry),
        isTrue,
        reason: 'Bonus days must extend the RC expiry',
      );
    });
  });

  // ── State transition: redeemPromoCode() ─────────────────────────────────

  group('Promo code redemption state transitions', () {
    test('subscription promo updates state to PRO with promo_code source',
        () async {
      when(() => mockRepo.redeemPromoCode(any())).thenAnswer(
        (_) async => const PromoResult(type: 'subscription', durationDays: 30),
      );
      when(() => mockRepo.upsertSubscription(
            expiresAt: any(named: 'expiresAt'),
            source: any(named: 'source'),
            storeTxId: any(named: 'storeTxId'),
          )).thenAnswer((_) async {});

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

      // Simulate: notifier catches and sets error
      const current = SubscriptionState(isLoading: true);
      final afterError = current.copyWith(
        isLoading: false,
        purchaseError: 'Error al activar la prueba gratuita',
      );

      expect(afterError.isPro, isFalse);
      expect(afterError.isLoading, isFalse);
      expect(afterError.purchaseError, isNotNull);
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
      when(() => mockRepo.upsertSubscription(
            expiresAt: any(named: 'expiresAt'),
            source: any(named: 'source'),
            storeTxId: any(named: 'storeTxId'),
          )).thenAnswer((_) async {});

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
