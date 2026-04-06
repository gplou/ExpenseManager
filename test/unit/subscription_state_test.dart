import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/subscription/subscription_state.dart';

void main() {
  group('SubscriptionState', () {
    test('isPro returns false when expiresAt is null', () {
      const state = SubscriptionState();
      expect(state.isPro, isFalse);
    });

    test('isPro returns false when expired', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(state.isPro, isFalse);
    });

    test('isPro returns true when not yet expired', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(state.isPro, isTrue);
    });

    test('copyWith changes fields correctly', () {
      const original = SubscriptionState(isLoading: true, purchaseError: 'err');
      final updated = original.copyWith(isLoading: false, clearError: true);
      expect(updated.isLoading, isFalse);
      expect(updated.purchaseError, isNull);
    });

    test('copyWith preserves expiresAt when not clearing', () {
      final expires = DateTime.now().add(const Duration(days: 30));
      final state = SubscriptionState(expiresAt: expires);
      final updated = state.copyWith(isLoading: true);
      expect(updated.expiresAt, expires);
    });

    test('copyWith with clearExpiry sets expiresAt to null', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      final updated = state.copyWith(clearExpiry: true);
      expect(updated.expiresAt, isNull);
    });

    test('default state has no error and is not loading', () {
      const state = SubscriptionState();
      expect(state.isLoading, isFalse);
      expect(state.purchaseError, isNull);
      expect(state.source, isNull);
    });

    // ── Discount promo fields ──────────────────────────────────────────────

    test('default state has no pending discount', () {
      const state = SubscriptionState();
      expect(state.hasDiscount, isFalse);
      expect(state.pendingDiscountPercentage, isNull);
      expect(state.discountBonusDays, 0);
    });

    test('hasDiscount returns true when pendingDiscountPercentage is set', () {
      const state = SubscriptionState(pendingDiscountPercentage: 50);
      expect(state.hasDiscount, isTrue);
    });

    test('discountBonusDays calculates correctly for 50%', () {
      const state = SubscriptionState(pendingDiscountPercentage: 50);
      // 30 * 50 / 100 = 15.0 → 15
      expect(state.discountBonusDays, 15);
    });

    test('discountBonusDays calculates correctly for 100%', () {
      const state = SubscriptionState(pendingDiscountPercentage: 100);
      // 30 * 100 / 100 = 30
      expect(state.discountBonusDays, 30);
    });

    test('discountBonusDays calculates correctly for 10%', () {
      const state = SubscriptionState(pendingDiscountPercentage: 10);
      // 30 * 10 / 100 = 3.0 → 3
      expect(state.discountBonusDays, 3);
    });

    test('copyWith preserves pendingDiscountPercentage', () {
      const state = SubscriptionState(pendingDiscountPercentage: 30);
      final updated = state.copyWith(isLoading: true);
      expect(updated.pendingDiscountPercentage, 30);
    });

    test('copyWith with clearDiscount removes pendingDiscountPercentage', () {
      const state = SubscriptionState(pendingDiscountPercentage: 30);
      final updated = state.copyWith(clearDiscount: true);
      expect(updated.pendingDiscountPercentage, isNull);
      expect(updated.hasDiscount, isFalse);
    });

    test('discount state does not make user PRO', () {
      const state = SubscriptionState(pendingDiscountPercentage: 50);
      expect(state.isPro, isFalse);
      expect(state.hasDiscount, isTrue);
    });
  });

  // ── Free trial fields ────────────────────────────────────────────────────

  group('Free trial', () {
    test('default state has trialUsed = false', () {
      const state = SubscriptionState();
      expect(state.trialUsed, isFalse);
    });

    test('canStartTrial is true for fresh user (not PRO, trial not used)', () {
      const state = SubscriptionState();
      expect(state.canStartTrial, isTrue);
    });

    test('canStartTrial is false when already PRO', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 3)),
        source: 'free_trial',
        trialUsed: true,
      );
      expect(state.isPro, isTrue);
      expect(state.canStartTrial, isFalse);
    });

    test('canStartTrial is false when trial already used (even if expired)', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'free_trial',
        trialUsed: true,
      );
      expect(state.isPro, isFalse);
      expect(state.canStartTrial, isFalse);
    });

    test('canStartTrial is false when PRO via purchase (trial never used)', () {
      final state = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        source: 'google_play',
      );
      expect(state.canStartTrial, isFalse); // isPro is true
    });

    test('copyWith preserves trialUsed', () {
      const state = SubscriptionState(trialUsed: true);
      final updated = state.copyWith(isLoading: true);
      expect(updated.trialUsed, isTrue);
    });

    test('copyWith can change trialUsed', () {
      const state = SubscriptionState();
      final updated = state.copyWith(trialUsed: true);
      expect(updated.trialUsed, isTrue);
    });

    test('copyWith does not mutate the original instance', () {
      final original = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isLoading: false,
        source: 'google_play',
        trialUsed: false,
        pendingDiscountPercentage: 20,
      );
      final originalExpires = original.expiresAt;
      final copy = original.copyWith(
        isLoading: true,
        source: 'app_store',
        trialUsed: true,
        clearDiscount: true,
      );

      // Original unchanged
      expect(original.isLoading, isFalse);
      expect(original.source, 'google_play');
      expect(original.trialUsed, isFalse);
      expect(original.pendingDiscountPercentage, 20);
      expect(original.expiresAt, originalExpires);

      // Copy has new values
      expect(copy.isLoading, isTrue);
      expect(copy.source, 'app_store');
      expect(copy.trialUsed, isTrue);
      expect(copy.pendingDiscountPercentage, isNull);
    });
  });
}
