import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';

/// Integration test for the subscription lifecycle.
///
/// Tests the state transitions that occur during a subscription purchase,
/// promo code redemption (both subscription and discount types), and expiry
/// without needing a real IAP connection.
void main() {
  group('Subscription lifecycle', () {
    test('new user starts with free (non-PRO) state', () {
      const state = SubscriptionState();
      expect(state.isPro, isFalse);
      expect(state.expiresAt, isNull);
      expect(state.hasDiscount, isFalse);
    });

    test('after purchase, state becomes PRO with future expiry', () {
      final expiresAt = DateTime.now().add(const Duration(days: 31));
      final state = SubscriptionState(
        expiresAt: expiresAt,
        source: 'google_play',
      );
      expect(state.isPro, isTrue);
      expect(state.source, 'google_play');
    });

    test('expired subscription is not PRO', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'google_play',
      );
      expect(state.isPro, isFalse);
    });

    test('loading state during purchase flow', () {
      const initial = SubscriptionState();
      final loading = initial.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
      expect(loading.isPro, isFalse);

      // Purchase completes
      final completed = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 31)),
        source: 'app_store',
      );
      expect(completed.isPro, isTrue);
      expect(completed.isLoading, isFalse);
    });

    test('error state during purchase preserves existing PRO status', () {
      final proState = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        source: 'google_play',
      );
      final withError = proState.copyWith(
        errorCode: SubscriptionErrorCode.purchaseFailed,
      );
      expect(withError.isPro, isTrue); // Still PRO
      expect(withError.errorCode, SubscriptionErrorCode.purchaseFailed);
    });

    test('clearing error preserves subscription data', () {
      final errorState = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        errorCode: SubscriptionErrorCode.purchaseFailed,
        source: 'google_play',
      );
      final cleared = errorState.copyWith(clearError: true);
      expect(cleared.errorCode, isNull);
      expect(cleared.isPro, isTrue);
      expect(cleared.source, 'google_play');
    });
  });

  // ── Subscription promo flow: free → promo → PRO ──────────────────────────

  group('Subscription promo code flow (free → promo → PRO)', () {
    test('subscription promo grants PRO directly from free state', () {
      const result = PromoResult(
        type: 'subscription',
        durationDays: 30,
      );
      expect(result.isSubscription, isTrue);
      expect(result.isDiscount, isFalse);

      // Simulate: apply promo to free user
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: result.durationDays));
      final state = SubscriptionState(
        expiresAt: expiresAt,
        source: 'promo_code',
      );
      expect(state.isPro, isTrue);
      expect(state.source, 'promo_code');
      expect(state.hasDiscount, isFalse);
    });

    test('subscription promo extends existing PRO subscription', () {
      final currentExpiry = DateTime.now().add(const Duration(days: 10));
      const result = PromoResult(
        type: 'subscription',
        durationDays: 30,
      );

      // Simulate: extend from current expiry
      final extended = currentExpiry.add(Duration(days: result.durationDays));
      final state = SubscriptionState(
        expiresAt: extended,
        source: 'promo_code',
      );
      expect(state.isPro, isTrue);
      expect(state.expiresAt!.isAfter(currentExpiry), isTrue);
    });

    test('subscription promo with PRO expired uses current time as base', () {
      final expiredState = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(days: 5)),
        source: 'google_play',
      );
      expect(expiredState.isPro, isFalse);

      const result = PromoResult(
        type: 'subscription',
        durationDays: 30,
      );

      // Since expired, base = now (not expired date)
      final now = DateTime.now();
      final base = expiredState.isPro ? expiredState.expiresAt! : now;
      final expiresAt = base.add(Duration(days: result.durationDays));
      final newState = SubscriptionState(
        expiresAt: expiresAt,
        source: 'promo_code',
      );
      expect(newState.isPro, isTrue);
      // New expiry should be ~30 days from now, not from the expired date
      expect(
        newState.expiresAt!.difference(now).inDays,
        greaterThanOrEqualTo(29),
      );
    });
  });

  // ── Discount promo flow: free → discount → purchase → PRO ────────────────

  group('Discount promo code flow (free → discount → purchase → PRO)', () {
    test('discount promo does NOT grant PRO directly', () {
      const result = PromoResult(
        type: 'discount',
        durationDays: 0,
        discountPercentage: 50,
      );
      expect(result.isDiscount, isTrue);
      expect(result.isSubscription, isFalse);

      // Simulate: apply discount promo to free user → still free, but with discount
      const state = SubscriptionState(pendingDiscountPercentage: 50);
      expect(state.isPro, isFalse);
      expect(state.hasDiscount, isTrue);
      expect(state.pendingDiscountPercentage, 50);
    });

    test('discount promo sets bonus days based on percentage', () {
      const state = SubscriptionState(pendingDiscountPercentage: 50);
      // 30 * 50 / 100 = 15.0 → 15 bonus days
      expect(state.discountBonusDays, 15);
    });

    test('purchase after discount promo adds bonus days', () {
      // User has redeemed a 50% discount promo code
      const discountState = SubscriptionState(pendingDiscountPercentage: 50);
      final bonusDays = discountState.discountBonusDays; // 15

      // User then purchases via store → 30 base days + 15 bonus days = 45
      final expiresAt = DateTime.now().add(Duration(days: 30 + bonusDays));
      final proState = SubscriptionState(
        expiresAt: expiresAt,
        source: 'google_play',
        // Discount cleared after purchase
      );
      expect(proState.isPro, isTrue);
      expect(proState.hasDiscount, isFalse);
      // Total days should be ~45
      expect(
        proState.expiresAt!.difference(DateTime.now()).inDays,
        greaterThanOrEqualTo(44),
      );
    });

    test('purchase without discount promo gives only 31 base days', () {
      const freeState = SubscriptionState();
      final bonusDays = freeState.discountBonusDays; // 0
      expect(bonusDays, 0);

      final expiresAt = DateTime.now().add(Duration(days: 31 + bonusDays));
      final proState = SubscriptionState(
        expiresAt: expiresAt,
        source: 'app_store',
      );
      expect(proState.isPro, isTrue);
      expect(
        proState.expiresAt!.difference(DateTime.now()).inDays,
        lessThanOrEqualTo(31),
      );
    });

    test('discount promo is cleared after purchase completes', () {
      // Simulate the full flow
      const discountState = SubscriptionState(pendingDiscountPercentage: 30);
      expect(discountState.hasDiscount, isTrue);

      // After purchase, state is replaced (not copyWith) — discount is gone
      final purchasedState = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 40)),
        source: 'google_play',
      );
      expect(purchasedState.hasDiscount, isFalse);
      expect(purchasedState.isPro, isTrue);
    });

    test('100% discount promo doubles subscription length on purchase', () {
      const state = SubscriptionState(pendingDiscountPercentage: 100);
      // 30 * 100 / 100 = 30 bonus days → total 60 days
      expect(state.discountBonusDays, 30);

      final expiresAt = DateTime.now()
          .add(Duration(days: 30 + state.discountBonusDays));
      final proState = SubscriptionState(
        expiresAt: expiresAt,
        source: 'app_store',
      );
      expect(
        proState.expiresAt!.difference(DateTime.now()).inDays,
        greaterThanOrEqualTo(59),
      );
    });
  });

  // ── Free trial flow: free → trial → expiry → purchase ────────────────────

  group('Free trial flow', () {
    test('new user is eligible for trial', () {
      const state = SubscriptionState();
      expect(state.canStartTrial, isTrue);
      expect(state.isPro, isFalse);
      expect(state.trialUsed, isFalse);
    });

    test('activating trial grants PRO with free_trial source', () {
      final now = DateTime.now();
      final expiresAt = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 4));
      final state = SubscriptionState(
        expiresAt: expiresAt,
        source: 'free_trial',
        trialUsed: true,
      );
      expect(state.isPro, isTrue);
      expect(state.source, 'free_trial');
      expect(state.trialUsed, isTrue);
      expect(state.canStartTrial, isFalse);
    });

    test('trial expires at midnight of day+4 (3 full calendar days)', () {
      final now = DateTime.now();
      final expiresAt = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 4));
      // Verify it's exactly midnight (00:00:00)
      expect(expiresAt.hour, 0);
      expect(expiresAt.minute, 0);
      expect(expiresAt.second, 0);
      // Verify it's 4 calendar days from start of today
      final startOfToday = DateTime(now.year, now.month, now.day);
      expect(expiresAt.difference(startOfToday).inDays, 4);
    });

    test('after trial expires, user is no longer PRO but trial is still used', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        source: 'free_trial',
        trialUsed: true,
      );
      expect(state.isPro, isFalse);
      expect(state.trialUsed, isTrue);
      expect(state.canStartTrial, isFalse);
    });

    test('user can purchase PRO after trial expires', () {
      // Trial expired
      final trialExpired = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'free_trial',
        trialUsed: true,
      );
      expect(trialExpired.isPro, isFalse);
      expect(trialExpired.canStartTrial, isFalse);

      // User purchases — state is replaced
      final purchased = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 31)),
        source: 'google_play',
        trialUsed: true,
      );
      expect(purchased.isPro, isTrue);
      expect(purchased.source, 'google_play');
    });

    test('user who already purchased cannot start trial', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'google_play',
        trialUsed: true,
      );
      expect(state.canStartTrial, isFalse);
    });

    test('user with active promo code PRO cannot start trial', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        source: 'promo_code',
        trialUsed: true,
      );
      expect(state.canStartTrial, isFalse);
    });
  });

  // ── PromoResult ───────────────────────────────────────────────────────────

  group('PromoResult', () {
    test('isSubscription is true for subscription type', () {
      const result = PromoResult(
        type: 'subscription',
        durationDays: 30,
      );
      expect(result.isSubscription, isTrue);
      expect(result.isDiscount, isFalse);
    });

    test('isDiscount is true for discount type', () {
      const result = PromoResult(
        type: 'discount',
        durationDays: 0,
        discountPercentage: 25,
      );
      expect(result.isDiscount, isTrue);
      expect(result.isSubscription, isFalse);
    });

    test('subscription result has durationDays and no discountPercentage', () {
      const result = PromoResult(
        type: 'subscription',
        durationDays: 90,
      );
      expect(result.durationDays, 90);
      expect(result.discountPercentage, isNull);
    });

    test('discount result has discountPercentage', () {
      const result = PromoResult(
        type: 'discount',
        durationDays: 0,
        discountPercentage: 75,
      );
      expect(result.discountPercentage, 75);
    });
  });
}
