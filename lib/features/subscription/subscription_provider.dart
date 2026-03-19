import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/security/secure_storage.dart';
import '../auth/presentation/providers/auth_provider.dart';
import 'subscription_repository.dart';
import 'subscription_state.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const kProProductId = 'pro_monthly_subscription';
const _kCacheExpiresAtKey = 'sub_expires_at';
const _kCacheCheckedAtKey = 'sub_checked_at';
const _kCacheSourceKey = 'sub_source';
const _kCacheUserIdKey = 'sub_user_id';
const _kCacheTrialUsedKey = 'sub_trial_used';

/// Re-check the store/Supabase at most once every 24 hours.
const _kCacheTtl = Duration(hours: 24);

/// Max failed promo-code attempts before triggering a cooldown.
const _kMaxPromoAttempts = 3;

/// Cooldown duration after [_kMaxPromoAttempts] consecutive failures.
const _kPromoCooldown = Duration(seconds: 30);

// ── Notifier ──────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // ── Promo-code rate-limiting (in-memory, per session) ─────────────────────
  int _promoFailedAttempts = 0;
  DateTime? _promoCooldownUntil;

  @override
  Future<SubscriptionState> build() async {
    // Rebuild when the logged-in user changes so stale cache is never reused.
    ref.watch(currentUserProvider);

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

  /// Redeems a promo code with client-side rate limiting.
  ///
  /// For 'subscription' promos: grants PRO access directly.
  /// For 'discount' promos: stores the discount percentage — the user must
  /// then complete a store purchase to activate PRO (bonus days are added
  /// automatically when the purchase completes).
  ///
  /// Throws [PromoCodeException] on failure so callers can display the message.
  Future<void> redeemPromoCode(String code) async {
    // ── Rate limiting ────────────────────────────────────────────────────────
    if (_promoCooldownUntil != null &&
        DateTime.now().isBefore(_promoCooldownUntil!)) {
      final remaining =
          _promoCooldownUntil!.difference(DateTime.now()).inSeconds;
      throw PromoCodeException(
          'Demasiados intentos. Espera $remaining segundos.');
    }

    final repo = ref.read(subscriptionRepositoryProvider);

    try {
      final result = await repo.redeemPromoCode(code);

      // Reset counter on success
      _promoFailedAttempts = 0;
      _promoCooldownUntil = null;

      if (result.isSubscription) {
        // ── Direct subscription: grant PRO immediately ────────────────────
        final now = DateTime.now();
        final current = state.valueOrNull;
        final base = (current?.isPro == true) ? current!.expiresAt! : now;
        final expiresAt = base.add(Duration(days: result.durationDays));

        await repo.upsertSubscription(
            expiresAt: expiresAt, source: 'promo_code');
        await _persistCache(expiresAt: expiresAt, source: 'promo_code');

        state = AsyncData(
          SubscriptionState(expiresAt: expiresAt, source: 'promo_code'),
        );
      } else {
        // ── Discount: store pending discount, user must purchase via store ─
        final current = state.valueOrNull ?? const SubscriptionState();
        state = AsyncData(
          current.copyWith(
            pendingDiscountPercentage: result.discountPercentage,
          ),
        );
      }
    } on PromoCodeException {
      _promoFailedAttempts++;
      if (_promoFailedAttempts >= _kMaxPromoAttempts) {
        _promoCooldownUntil = DateTime.now().add(_kPromoCooldown);
        _promoFailedAttempts = 0;
      }
      rethrow;
    }
  }

  /// Activates the one-time 3-day free trial.
  Future<void> startFreeTrial() async {
    _setLoading(true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final expiresAt = await repo.startFreeTrial();
      await _persistCache(
        expiresAt: expiresAt,
        source: 'free_trial',
        trialUsed: true,
      );
      state = AsyncData(
        SubscriptionState(
          expiresAt: expiresAt,
          source: 'free_trial',
          trialUsed: true,
        ),
      );
    } catch (e) {
      _setError('Error al activar la prueba gratuita');
    }
  }

  /// Forces a re-check against Supabase, ignoring the 24 h cache.
  Future<void> forceRefresh() async {
    _setLoading(true);
    final fresh = await _fetchRemote();
    state = AsyncData(fresh);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<SubscriptionState> _loadInitialState() async {
    final storage = SecureStorageService.instance;

    // If the user changed (e.g. switched accounts), discard the old cache.
    final cachedUserId = await storage.read(_kCacheUserIdKey);
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (cachedUserId != currentUserId) {
      await _clearCache(storage);
      return _fetchRemote();
    }

    final cachedExpiry = await storage.read(_kCacheExpiresAtKey);
    final cachedCheckedAt = await storage.read(_kCacheCheckedAtKey);
    final cachedSource = await storage.read(_kCacheSourceKey);
    final cachedTrialUsed = await storage.read(_kCacheTrialUsedKey);

    // Build the fast cached state (may be null / expired).
    SubscriptionState fast = const SubscriptionState();
    if (cachedExpiry != null) {
      fast = SubscriptionState(
        expiresAt: DateTime.parse(cachedExpiry).toLocal(),
        source: cachedSource,
        trialUsed: cachedTrialUsed == 'true',
      );
    } else if (cachedTrialUsed == 'true') {
      fast = const SubscriptionState(trialUsed: true);
    }

    // Determine whether the cache is stale (> 24 h old).
    bool cacheStale = true;
    if (cachedCheckedAt != null) {
      final checkedAt = DateTime.parse(cachedCheckedAt);
      cacheStale = DateTime.now().difference(checkedAt) > _kCacheTtl;
    }

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
    final trialUsed = await repo.checkTrialUsed();
    await _persistCache(
      expiresAt: remote.expiresAt,
      source: remote.source,
      trialUsed: trialUsed,
    );
    return SubscriptionState(
      expiresAt: remote.expiresAt,
      source: remote.source,
      trialUsed: trialUsed,
    );
  }

  Future<void> _persistCache({DateTime? expiresAt, String? source, bool? trialUsed}) async {
    final storage = SecureStorageService.instance;
    if (expiresAt != null) {
      await storage.write(
          _kCacheExpiresAtKey, expiresAt.toUtc().toIso8601String());
    } else {
      await storage.delete(_kCacheExpiresAtKey);
    }
    await storage.write(
        _kCacheCheckedAtKey, DateTime.now().toUtc().toIso8601String());
    if (source != null) {
      await storage.write(_kCacheSourceKey, source);
    } else {
      await storage.delete(_kCacheSourceKey);
    }
    if (trialUsed != null) {
      await storage.write(_kCacheTrialUsedKey, trialUsed.toString());
    }
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId != null) {
      await storage.write(_kCacheUserIdKey, currentUserId);
    } else {
      await storage.delete(_kCacheUserIdKey);
    }
  }

  Future<void> _clearCache(SecureStorageService storage) async {
    await storage.delete(_kCacheExpiresAtKey);
    await storage.delete(_kCacheCheckedAtKey);
    await storage.delete(_kCacheSourceKey);
    await storage.delete(_kCacheUserIdKey);
    await storage.delete(_kCacheTrialUsedKey);
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
          // Apply bonus days from pending discount promo code, if any.
          final current = state.valueOrNull ?? const SubscriptionState();
          final bonusDays = current.discountBonusDays;
          final expiresAt = DateTime.now()
              .add(Duration(days: 31 + bonusDays));
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
