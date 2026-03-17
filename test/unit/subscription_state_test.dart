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
      // 31 * 50 / 100 = 15.5 → rounds to 16
      expect(state.discountBonusDays, 16);
    });

    test('discountBonusDays calculates correctly for 100%', () {
      const state = SubscriptionState(pendingDiscountPercentage: 100);
      // 31 * 100 / 100 = 31
      expect(state.discountBonusDays, 31);
    });

    test('discountBonusDays calculates correctly for 10%', () {
      const state = SubscriptionState(pendingDiscountPercentage: 10);
      // 31 * 10 / 100 = 3.1 → rounds to 3
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
}
