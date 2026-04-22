import 'package:purchases_flutter/purchases_flutter.dart';

import '../subscription_repository.dart';

// ── Supabase sub-contract ─────────────────────────────────────────────────────

/// Contract for Supabase-backed subscription persistence operations.
/// Implementations of this interface must only interact with Supabase;
/// they must not depend on any IAP SDK.
abstract class SupabaseSubscriptionContract {
  Future<({DateTime? expiresAt, String? source})> fetchRemoteSubscription();

  Future<void> upsertSubscription({
    required DateTime expiresAt,
    required String source,
    String? storeTxId,
  });

  Future<bool> checkTrialUsed();

  Future<DateTime> startFreeTrial();

  Future<PromoResult> redeemPromoCode(String code);
}

// ── RevenueCat sub-contract ───────────────────────────────────────────────────

/// Contract for RevenueCat store purchase operations.
/// Implementations of this interface must only interact with the RC SDK;
/// they must not depend on any Supabase client.
abstract class RevenueCatContract {
  /// Triggers the native store purchase sheet for the given [package].
  /// Throws [RCPurchaseCancelledException] if the user cancels.
  /// Throws [RCPurchaseException] on any other error.
  Future<RCPurchaseResult> purchaseProPlan(Package package);

  /// Restores previous store purchases.
  /// Returns the current RC entitlement state (may not be PRO if nothing to restore).
  /// Throws [RCPurchaseException] on error.
  Future<RCPurchaseResult> restoreProPlan();

  /// Returns the current RC entitlement state without triggering any UI.
  /// Returns null if RevenueCat is unavailable.
  Future<RCPurchaseResult?> getCurrentRCStatus();
}

// ── Composed contract ─────────────────────────────────────────────────────────

/// Full subscription contract: composes Supabase + RevenueCat operations.
/// The concrete [SubscriptionRepository] implements this interface.
/// In tests, each sub-contract can be mocked independently.
abstract class SubscriptionRepositoryContract
    implements SupabaseSubscriptionContract, RevenueCatContract {}
