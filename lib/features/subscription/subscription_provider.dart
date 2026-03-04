import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_repository.dart';
import 'subscription_state.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const kProProductId = 'pro_monthly_subscription';
const _kCacheExpiresAtKey = 'sub_expires_at';
const _kCacheCheckedAtKey = 'sub_checked_at';
const _kCacheSourceKey = 'sub_source';

/// Re-check the store/Supabase at most once every 24 hours.
const _kCacheTtl = Duration(hours: 24);

// ── Notifier ──────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  Future<SubscriptionState> build() async {
    // Listen to IAP purchase stream for the lifetime of this notifier.
    _purchaseSub = ref
        .read(subscriptionRepositoryProvider)
        .purchaseStream
        .listen(_handlePurchaseUpdate);

    ref.onDispose(() => _purchaseSub?.cancel());

    return _loadInitialState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initiates the native purchase flow. UI watches [state] for result.
  Future<void> purchase() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    _setLoading(true);

    final product = await repo.loadProduct(kProProductId);
    if (product == null) {
      _setError('Producto no disponible. Inténtalo más tarde.');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    // Result arrives via _handlePurchaseUpdate
  }

  /// Restores previous purchases (required for App Store compliance).
  Future<void> restorePurchases() async {
    _setLoading(true);
    await InAppPurchase.instance.restorePurchases();
    // Result arrives via _handlePurchaseUpdate
  }

  /// Redeems a promo code. Throws [PromoCodeException] on failure so
  /// callers can display the error message directly.
  Future<void> redeemPromoCode(String code) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    // PromoCodeException bubbles up to the caller — no try/catch here.
    final days = await repo.redeemPromoCode(code);

    final now = DateTime.now();
    final current = state.valueOrNull;
    final base = (current?.isPro == true) ? current!.expiresAt! : now;
    final expiresAt = base.add(Duration(days: days));

    await repo.upsertSubscription(expiresAt: expiresAt, source: 'promo_code');
    await _persistCache(expiresAt: expiresAt, source: 'promo_code');

    state = AsyncData(
      SubscriptionState(expiresAt: expiresAt, source: 'promo_code'),
    );
  }

  /// Forces a re-check against Supabase, ignoring the 24 h cache.
  Future<void> forceRefresh() async {
    _setLoading(true);
    final fresh = await _fetchRemote();
    state = AsyncData(fresh);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<SubscriptionState> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedExpiry = prefs.getString(_kCacheExpiresAtKey);
    final cachedCheckedAt = prefs.getString(_kCacheCheckedAtKey);
    final cachedSource = prefs.getString(_kCacheSourceKey);

    // Build the fast cached state (may be null / expired).
    SubscriptionState fast = const SubscriptionState();
    if (cachedExpiry != null) {
      fast = SubscriptionState(
        expiresAt: DateTime.parse(cachedExpiry).toLocal(),
        source: cachedSource,
      );
    }

    // Determine whether the cache is stale (> 24 h old).
    bool cacheStale = true;
    if (cachedCheckedAt != null) {
      final checkedAt = DateTime.parse(cachedCheckedAt);
      cacheStale = DateTime.now().difference(checkedAt) > _kCacheTtl;
    }

    // Refresh in background when:
    // 1. Cache is stale (> 24 h) — regular daily check.
    // 2. The cached state is not PRO — catches expired subscriptions and
    //    potential renewals that happened while the app was closed.
    //    (If user IS PRO with a fresh cache, trust it to avoid unnecessary calls.)
    final shouldRefresh = cacheStale || !fast.isPro;

    if (!shouldRefresh) return fast;

    // Return cached state immediately for fast startup, then update.
    _refreshInBackground();
    return fast;
  }

  void _refreshInBackground() {
    Future(() async {
      try {
        final fresh = await _fetchRemote();
        state = AsyncData(fresh);
      } catch (_) {
        // Silently fail — user sees stale cached data.
      }
    });
  }

  Future<SubscriptionState> _fetchRemote() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final remote = await repo.fetchRemoteSubscription();
    await _persistCache(expiresAt: remote.expiresAt, source: remote.source);
    return SubscriptionState(expiresAt: remote.expiresAt, source: remote.source);
  }

  Future<void> _persistCache({DateTime? expiresAt, String? source}) async {
    final prefs = await SharedPreferences.getInstance();
    if (expiresAt != null) {
      await prefs.setString(
          _kCacheExpiresAtKey, expiresAt.toUtc().toIso8601String());
    } else {
      await prefs.remove(_kCacheExpiresAtKey);
    }
    await prefs.setString(
        _kCacheCheckedAtKey, DateTime.now().toUtc().toIso8601String());
    if (source != null) {
      await prefs.setString(_kCacheSourceKey, source);
    } else {
      await prefs.remove(_kCacheSourceKey);
    }
  }

  void _setLoading(bool loading) {
    final current = state.valueOrNull ?? const SubscriptionState();
    state = AsyncData(current.copyWith(isLoading: loading, clearError: true));
  }

  void _setError(String message) {
    final current = state.valueOrNull ?? const SubscriptionState();
    state = AsyncData(
        current.copyWith(isLoading: false, purchaseError: message));
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kProProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setLoading(true);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          final expiresAt = DateTime.now().add(const Duration(days: 31));
          final source = _detectSource(purchase);
          final repo = ref.read(subscriptionRepositoryProvider);
          await repo.upsertSubscription(
            expiresAt: expiresAt,
            source: source,
            storeTxId: purchase.purchaseID,
          );
          await _persistCache(expiresAt: expiresAt, source: source);
          state = AsyncData(
            SubscriptionState(expiresAt: expiresAt, source: source),
          );

        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          _setError(
            purchase.error?.message ?? 'Error al procesar la compra',
          );

        case PurchaseStatus.canceled:
          final current = state.valueOrNull ?? const SubscriptionState();
          state = AsyncData(
              current.copyWith(isLoading: false, clearError: true));
      }
    }
  }

  String _detectSource(PurchaseDetails purchase) {
    return purchase.verificationData.source == 'google_play'
        ? 'google_play'
        : 'app_store';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Main subscription provider. keepAlive = true so it survives screen navigation.
final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

/// Derived bool provider for widgets that only need to know "is user PRO?".
/// Using .select() prevents rebuilds when only isLoading/purchaseError changes.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(
    subscriptionProvider.select((s) => s.valueOrNull?.isPro ?? false),
  );
});
