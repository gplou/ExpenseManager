/// Pure domain helper that decides the effective `expires_at` for a PRO
/// subscription, combining the store-reported expiry with any bonus days
/// granted by a pending discount promo code.
///
/// Kept stateless and side-effect free so it can be unit-tested in isolation
/// and reused by the notifier, background renewal handlers, or future
/// server-driven flows without dragging in RevenueCat/Supabase dependencies.
class SubscriptionExpiryCalculator {
  const SubscriptionExpiryCalculator._();

  /// Returns the expiry date that should be persisted after a successful
  /// purchase or restore.
  ///
  /// - [storeExpiry] is the expiry reported by the store (via RevenueCat).
  ///   When `null` (e.g. lifetime entitlements, sandbox edge cases) a
  ///   fallback window of [fallbackPeriodDays] is used.
  /// - [bonusDays] is the extra days granted by a previously redeemed
  ///   `discount` promo code. Added on top of the store expiry so the user
  ///   actually receives the bonus they were promised in the paywall.
  /// - [now] is injectable to keep the function deterministic in tests.
  static DateTime effectiveExpiry({
    DateTime? storeExpiry,
    required int bonusDays,
    required int fallbackPeriodDays,
    DateTime? now,
  }) {
    assert(bonusDays >= 0, 'bonusDays must be non-negative');
    assert(fallbackPeriodDays > 0, 'fallbackPeriodDays must be positive');

    final reference = now ?? DateTime.now();
    final base =
        storeExpiry ?? reference.add(Duration(days: fallbackPeriodDays));
    if (bonusDays == 0) return base;
    return base.add(Duration(days: bonusDays));
  }
}
