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

  // ── Promo codes ───────────────────────────────────────────────────────────

  /// Returns granted duration in days if valid.
  /// Throws [PromoCodeException] with user-facing message on any failure.
  Future<int> redeemPromoCode(String code) async {
    final userId = _client.auth.currentUser!.id;
    final normalised = code.toUpperCase().trim();

    // 1. Fetch code record
    final codeRow = await _client
        .from('promo_codes')
        .select('id, duration_days, max_uses, use_count, valid_until')
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

    return codeRow['duration_days'] as int;
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

// ── Exception ─────────────────────────────────────────────────────────────────

class PromoCodeException implements Exception {
  const PromoCodeException(this.message);
  final String message;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});
