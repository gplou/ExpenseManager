import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Raw data access: Supabase reads/writes and IAP store interactions.
/// Business logic lives in SubscriptionNotifier, not here.
class SubscriptionRepository {
  SubscriptionRepository(this._client);
  final SupabaseClient _client;

  // ── Supabase ─────────────────────────────────────────────────────────────

  /// Returns expires_at + source for the current user, or nulls if no record.
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

  /// Upsert subscription row. Called after a successful IAP purchase or promo code.
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

  /// Returns true if the user has already used the free trial OR has ever
  /// been PRO (any source). Only first-time users are eligible.
  Future<bool> checkTrialUsed() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return true; // not logged in → not eligible

    final row = await _client
        .from('subscriptions')
        .select('trial_used_at, source')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return false; // no record → eligible
    if (row['trial_used_at'] != null) return true; // already used trial
    // If they ever had a paid/promo source, they're not eligible
    final source = row['source'] as String?;
    if (source != null && source != 'free_trial') return true;
    return false;
  }

  /// Activates the 3-day free trial. Expires at midnight (00:00) of
  /// the 4th full day after today (3 complete calendar days).
  /// Also stamps trial_used_at so it can never be used again.
  Future<DateTime> startFreeTrial() async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    // 3 full days: today (partial) + 3 complete days → midnight of day+4
    final expiresAt = DateTime(now.year, now.month, now.day).add(const Duration(days: 4));

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

  // ── Promo codes ───────────────────────────────────────────────────────────

  /// Redeems a promo code and returns its details.
  ///
  /// For 'subscription' codes: [PromoResult.durationDays] contains the days granted.
  /// For 'discount' codes: [PromoResult.discountPercentage] contains the discount.
  /// Throws [PromoCodeException] with user-facing message on any failure.
  Future<PromoResult> redeemPromoCode(String code) async {
    final userId = _client.auth.currentUser!.id;
    final normalised = code.toUpperCase().trim();

    // 1. Fetch code record
    final codeRow = await _client
        .from('promo_codes')
        .select('id, type, duration_days, discount_percentage, max_uses, use_count, valid_until')
        .eq('code', normalised)
        .maybeSingle();

    if (codeRow == null) throw const PromoCodeException('Código no válido');

    final maxUses = codeRow['max_uses'] as int?;
    final useCount = codeRow['use_count'] as int;
    final validUntil = codeRow['valid_until'] != null
        ? DateTime.parse(codeRow['valid_until'] as String)
        : null;

    if (maxUses != null && useCount >= maxUses) {
      throw const PromoCodeException('Este código ya no tiene usos disponibles');
    }
    if (validUntil != null && validUntil.isBefore(DateTime.now())) {
      throw const PromoCodeException('Este código ha expirado');
    }

    // 2. Record redemption — unique constraint prevents double use per user
    try {
      await _client.from('promo_code_redemptions').insert({
        'promo_code_id': codeRow['id'] as String,
        'user_id': userId,
      });
    } on PostgrestException {
      throw const PromoCodeException('Ya has utilizado este código');
    }

    // 3. Increment use_count
    await _client
        .from('promo_codes')
        .update({'use_count': useCount + 1})
        .eq('id', codeRow['id'] as String);

    final type = (codeRow['type'] as String?) ?? 'subscription';
    return PromoResult(
      type: type,
      durationDays: codeRow['duration_days'] as int,
      discountPercentage: codeRow['discount_percentage'] as int?,
    );
  }

  // ── IAP ───────────────────────────────────────────────────────────────────

  /// Loads store product details. Returns null if store unavailable or product
  /// not found (e.g. not configured in Google Play / App Store yet).
  Future<ProductDetails?> loadProduct(String productId) async {
    final iap = InAppPurchase.instance;
    final available = await iap.isAvailable();
    if (!available) return null;

    final response = await iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;
}

// ── Promo result ──────────────────────────────────────────────────────────────

/// Result of a successful promo code redemption.
class PromoResult {
  const PromoResult({
    required this.type,
    required this.durationDays,
    this.discountPercentage,
  });

  /// 'subscription' (direct PRO access) or 'discount' (requires store purchase).
  final String type;

  /// Days of PRO granted (only meaningful for 'subscription' type).
  final int durationDays;

  /// Discount percentage 1-100 (only meaningful for 'discount' type).
  final int? discountPercentage;

  bool get isSubscription => type == 'subscription';
  bool get isDiscount => type == 'discount';
}

// ── Exception ─────────────────────────────────────────────────────────────────

class PromoCodeException implements Exception {
  const PromoCodeException(this.message);
  final String message;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});
