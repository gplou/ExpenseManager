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
  });
}
