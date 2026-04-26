import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
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
  SubscriptionRepository(this._client);
  final SupabaseClient _client;

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
    final userId = _client.auth.currentUser!.id;
    final normalised = code.toUpperCase().trim();

    final Map<String, dynamic>? codeRow;
    try {
      codeRow = await _client
          .from('promo_codes')
          .select()
          .eq('code', normalised)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw PromoCodeException('Error al verificar el código: ${e.message}');
    }

    if (codeRow == null) throw const PromoCodeException('Código no válido');

    final maxUses = codeRow['max_uses'] as int?;
    final useCount = (codeRow['use_count'] as int?) ?? 0;
    final validUntil = codeRow['valid_until'] != null
        ? DateTime.parse(codeRow['valid_until'] as String)
        : null;

    if (maxUses != null && useCount >= maxUses) {
      throw const PromoCodeException('Este código ya no tiene usos disponibles');
    }
    if (validUntil != null && validUntil.isBefore(DateTime.now())) {
      throw const PromoCodeException('Este código ha expirado');
    }

    try {
      await _client.from('promo_code_redemptions').insert({
        'promo_code_id': codeRow['id'] as String,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const PromoCodeException('Ya has utilizado este código');
      }
      throw PromoCodeException('Error al canjear el código: ${e.message}');
    }

    // SECURITY: Incrementing use_count from the client is vulnerable to race
    // conditions (two concurrent redemptions can both read the same count) and
    // client-side manipulation (a modified client could skip this call). This
    // should be moved to a Supabase Edge Function or a Postgres trigger/RPC
    // that atomically increments the counter server-side.
    await _client
        .from('promo_codes')
        .update({'use_count': useCount + 1})
        .eq('id', codeRow['id'] as String);

    final type = (codeRow['type'] as String?) ?? 'subscription';
    return PromoResult(
      type: type,
      durationDays: (codeRow['duration_days'] as int?) ?? 30,
      discountPercentage: codeRow['discount_percentage'] as int?,
    );
  }

  // ── RevenueCat ────────────────────────────────────────────────────────────

  @override
  Future<RCPurchaseResult> purchaseProPlan(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return RevenueCatAdapter.fromCustomerInfo(result.customerInfo);
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
      final customerInfo = await Purchases.restorePurchases();
      return RevenueCatAdapter.fromCustomerInfo(customerInfo);
    } on PurchasesError catch (e) {
      throw RCPurchaseException(e.message);
    }
  }

  @override
  Future<RCPurchaseResult?> getCurrentRCStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
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
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});
