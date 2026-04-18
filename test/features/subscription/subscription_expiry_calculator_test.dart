import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/subscription/domain/subscription_expiry_calculator.dart';

/// Pure unit tests for [SubscriptionExpiryCalculator].
///
/// These tests lock in the contract that fixes the production bug where a
/// redeemed `discount` promo code's bonus days were silently dropped whenever
/// the store returned an explicit expiry (i.e. for every real subscription).
void main() {
  group('SubscriptionExpiryCalculator.effectiveExpiry', () {
    // ── Store returns an expiry (the real-world happy path) ─────────────────

    test('returns storeExpiry unchanged when bonusDays is 0', () {
      final store = DateTime.utc(2026, 5, 1);
      final result = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: store,
        bonusDays: 0,
        fallbackPeriodDays: 30,
      );
      expect(result, store);
    });

    test('adds bonusDays on top of storeExpiry when > 0 (BUG REGRESSION)', () {
      // Regression test: the previous implementation used
      //   `result.expiresAt ?? now.add(days: kSubscriptionDays + bonusDays)`
      // which meant bonusDays were ONLY applied when the store failed to
      // return an expiry. For every real subscription the discount promo
      // was silently discarded.
      final store = DateTime.utc(2026, 5, 1);
      final result = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: store,
        bonusDays: 15,
        fallbackPeriodDays: 30,
      );
      expect(result, DateTime.utc(2026, 5, 16));
    });

    test('100% discount on a 30-day period doubles the bonus window', () {
      // A 100% discount maps to bonusDays = (30 * 100 / 100).round() = 30.
      final store = DateTime.utc(2026, 6, 1);
      final result = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: store,
        bonusDays: 30,
        fallbackPeriodDays: 30,
      );
      expect(result, DateTime.utc(2026, 7, 1));
    });

    // ── Store returns nothing — fallback window kicks in ────────────────────

    test('falls back to now + fallbackPeriodDays when storeExpiry is null', () {
      final now = DateTime.utc(2026, 1, 10);
      final result = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: null,
        bonusDays: 0,
        fallbackPeriodDays: 30,
        now: now,
      );
      expect(result, DateTime.utc(2026, 2, 9));
    });

    test('fallback path also respects bonusDays', () {
      final now = DateTime.utc(2026, 1, 10);
      final result = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: null,
        bonusDays: 7,
        fallbackPeriodDays: 30,
        now: now,
      );
      expect(result, DateTime.utc(2026, 2, 16));
    });

    // ── Determinism / injectable clock ──────────────────────────────────────

    test('is deterministic when `now` is injected', () {
      final now = DateTime.utc(2026, 3, 15, 12, 0, 0);
      final a = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: null,
        bonusDays: 5,
        fallbackPeriodDays: 10,
        now: now,
      );
      final b = SubscriptionExpiryCalculator.effectiveExpiry(
        storeExpiry: null,
        bonusDays: 5,
        fallbackPeriodDays: 10,
        now: now,
      );
      expect(a, b);
    });

    // ── Defensive contracts (assert in debug) ───────────────────────────────

    test('asserts on negative bonusDays', () {
      expect(
        () => SubscriptionExpiryCalculator.effectiveExpiry(
          storeExpiry: DateTime.utc(2026, 1, 1),
          bonusDays: -1,
          fallbackPeriodDays: 30,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on non-positive fallbackPeriodDays', () {
      expect(
        () => SubscriptionExpiryCalculator.effectiveExpiry(
          storeExpiry: null,
          bonusDays: 0,
          fallbackPeriodDays: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
