import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/subscription/subscription_state.dart';

/// Integration test for the subscription lifecycle.
///
/// Tests the state transitions that occur during a subscription purchase,
/// promo code redemption, and expiry without needing a real IAP connection.
void main() {
  group('Subscription lifecycle', () {
    test('new user starts with free (non-PRO) state', () {
      const state = SubscriptionState();
      expect(state.isPro, isFalse);
      expect(state.expiresAt, isNull);
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

    test('promo code extends existing subscription', () {
      final currentExpiry = DateTime.now().add(const Duration(days: 10));
      final extended = currentExpiry.add(const Duration(days: 30));
      final state = SubscriptionState(
        expiresAt: extended,
        source: 'promo_code',
      );
      expect(state.isPro, isTrue);
      expect(state.expiresAt!.isAfter(currentExpiry), isTrue);
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
        purchaseError: 'Payment failed',
      );
      expect(withError.isPro, isTrue); // Still PRO
      expect(withError.purchaseError, 'Payment failed');
    });

    test('clearing error preserves subscription data', () {
      final errorState = SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        purchaseError: 'Network error',
        source: 'google_play',
      );
      final cleared = errorState.copyWith(clearError: true);
      expect(cleared.purchaseError, isNull);
      expect(cleared.isPro, isTrue);
      expect(cleared.source, 'google_play');
    });
  });
}
