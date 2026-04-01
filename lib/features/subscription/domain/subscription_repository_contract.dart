import '../subscription_repository.dart';

/// Contract for subscription data operations.
/// IAP store interactions are handled via RevenueCat (see [RCPurchaseResult]).
abstract class SubscriptionRepositoryContract {
  // ── Supabase ───────────────────────────────────────────────────────────────

  Future<({DateTime? expiresAt, String? source})> fetchRemoteSubscription();

  Future<void> upsertSubscription({
    required DateTime expiresAt,
    required String source,
    String? storeTxId,
  });

  Future<bool> checkTrialUsed();

  Future<DateTime> startFreeTrial();

  Future<PromoResult> redeemPromoCode(String code);

  // ── RevenueCat ─────────────────────────────────────────────────────────────

  /// Triggers the native store purchase sheet and returns the result.
  /// Throws [RCPurchaseCancelledException] if the user cancels.
  /// Throws [RCPurchaseException] on any other error.
  Future<RCPurchaseResult> purchaseProPlan();

  /// Restores previous store purchases.
  /// Returns the current RC entitlement state (may not be PRO if nothing to restore).
  /// Throws [RCPurchaseException] on error.
  Future<RCPurchaseResult> restoreProPlan();

  /// Returns the current RC entitlement state without triggering any UI.
  /// Returns null if RevenueCat is unavailable.
  Future<RCPurchaseResult?> getCurrentRCStatus();
}
