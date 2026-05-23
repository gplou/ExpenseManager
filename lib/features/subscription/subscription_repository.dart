import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import 'data/purchases_gateway.dart';
import 'data/revenue_cat_adapter.dart';
import 'domain/subscription_repository_contract.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// RevenueCat entitlement identifier — must match the RC dashboard.
const kRCEntitlementId = 'pro';

/// Duration of the one-time free trial in days.
const kFreeTrialDays = 4;

/// Nominal subscription period in days (used for fallback expiry and bonus calculation).
const kSubscriptionDays = 30;

// ── Repository ────────────────────────────────────────────────────────────────

/// Raw data access: Supabase reads/writes and RevenueCat store interactions.
/// Business logic lives in SubscriptionNotifier, not here.
class SubscriptionRepository implements SubscriptionRepositoryContract {
  SubscriptionRepository(this._client, this._purchases);
  final SupabaseClient _client;
  final PurchasesGateway _purchases;

  // ── Supabase ─────────────────────────────────────────────────────────────

  /// Returns expires_at + source for the current user, or nulls if no record.
  @override
  Future<({DateTime? expiresAt, String? source})> fetchRemoteSubscription() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (expiresAt: null, source: null);

    final result = await _client
        .from('subscriptions')
        .select('expires_at, source')
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) return (expiresAt: null, source: null);
    return (
      expiresAt: DateTime.parse(result['expires_at'] as String).toLocal(),
      source: result['source'] as String?,
    );
  }

  /// Upsert subscription row. Called after a successful RC purchase or promo code.
  ///
  // SECURITY: Receipt validation for store purchases is handled server-side by
  // RevenueCat — this client-side upsert only mirrors the state into Supabase
  // for fast reads. The `subscriptions` table MUST have Row Level Security (RLS)
  // enabled so that each user can only INSERT/UPDATE their own row
  // (e.g. `auth.uid() = user_id`). Without RLS, a malicious client could
  // overwrite another user's subscription status.
  @override
  Future<void> upsertSubscription({
    required DateTime expiresAt,
    required String source,
    String? storeTxId,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('subscriptions').upsert(
      {
        'user_id': userId,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'source': source,
        if (storeTxId != null) 'store_tx_id': storeTxId,
        'cancelled': false,
      },
      onConflict: 'user_id',
    );
  }

  // ── Free trial ──────────────────────────────────────────────────────────

  @override
  Future<bool> checkTrialUsed() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return true;

    final row = await _client
        .from('subscriptions')
        .select('trial_used_at, source')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return false;
    if (row['trial_used_at'] != null) return true;
    final source = row['source'] as String?;
    if (source != null && source != 'free_trial') return true;
    return false;
  }

  @override
  Future<DateTime> startFreeTrial() async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    final expiresAt =
        DateTime(now.year, now.month, now.day).add(const Duration(days: kFreeTrialDays));

    await _client.from('subscriptions').upsert(
      {
        'user_id': userId,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'source': 'free_trial',
        'trial_used_at': now.toUtc().toIso8601String(),
        'cancelled': false,
      },
      onConflict: 'user_id',
    );

    return expiresAt;
  }

  // ── Promo codes ──────────────────────────────────────────────────────────

  @override
  Future<PromoResult> redeemPromoCode(String code) async {
    // Validation, redemption insert, and use_count increment are handled
    // atomically by the redeem_promo_code Postgres function (FOR UPDATE lock).
    // This prevents the race condition where two concurrent clients could both
    // read the same use_count and both write count+1, bypassing max_uses.
    try {
      final result = await _client.rpc(
        'redeem_promo_code',
        params: {'code': code.toUpperCase().trim()},
      ) as Map<String, dynamic>;

      return PromoResult(
        type: (result['type'] as String?) ?? 'subscription',
        durationDays: (result['duration_days'] as int?) ?? 30,
        discountPercentage: result['discount_percentage'] as int?,
      );
    } on PostgrestException catch (e) {
      // The RPC raises P0001 with user-facing messages in Spanish.
      throw PromoCodeException(e.message);
    }
  }

  // ── RevenueCat ────────────────────────────────────────────────────────────

  @override
  Future<RCPurchaseResult> purchaseProPlan(Package package) async {
    try {
      final info = await _purchases.purchasePackage(package);
      return RevenueCatAdapter.fromCustomerInfo(info);
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        throw const RCPurchaseCancelledException();
      }
      throw RCPurchaseException(e.message);
    }
  }

  @override
  Future<RCPurchaseResult> restoreProPlan() async {
    try {
      final customerInfo = await _purchases.restorePurchases();
      return RevenueCatAdapter.fromCustomerInfo(customerInfo);
    } on PurchasesError catch (e) {
      throw RCPurchaseException(e.message);
    }
  }

  @override
  Future<RCPurchaseResult?> getCurrentRCStatus() async {
    try {
      final customerInfo = await _purchases.getCustomerInfo();
      return RevenueCatAdapter.fromCustomerInfo(customerInfo);
    } catch (_) {
      return null;
    }
  }
}

// ── RC result & exceptions ────────────────────────────────────────────────────

class RCPurchaseResult {
  const RCPurchaseResult({
    required this.isPro,
    required this.source,
    this.expiresAt,
    this.storeTxId,
  });

  final bool isPro;

  /// 'play_store' | 'app_store' | 'unknown'
  final String source;

  final DateTime? expiresAt;
  final String? storeTxId;
}

class RCPurchaseException implements Exception {
  const RCPurchaseException(this.message);
  final String message;
}

class RCPurchaseCancelledException implements Exception {
  const RCPurchaseCancelledException();
}

// ── Promo result & exception ──────────────────────────────────────────────────

class PromoResult {
  const PromoResult({
    required this.type,
    required this.durationDays,
    this.discountPercentage,
  });

  final String type;
  final int durationDays;
  final int? discountPercentage;

  bool get isSubscription => type == 'subscription';
  bool get isDiscount => type == 'discount';
}

class PromoCodeException implements Exception {
  const PromoCodeException(this.message);
  final String message;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepositoryContract>((ref) {
  return SubscriptionRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(purchasesGatewayProvider),
  );
});
