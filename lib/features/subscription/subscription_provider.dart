import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/security/secure_storage.dart';
import '../../core/services/analytics_service.dart';
import '../auth/presentation/providers/auth_provider.dart';
import 'subscription_repository.dart';
import 'subscription_state.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

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
  // ── Promo-code rate-limiting (in-memory, per session) ─────────────────────
  // SECURITY: This rate limit lives in Dart memory and resets when the app
  // restarts or the notifier is rebuilt. A determined attacker can bypass it by
  // force-closing the app. For production hardening, enforce rate limits
  // server-side (e.g. Supabase Edge Function with a per-user cooldown window).
  int _promoFailedAttempts = 0;
  DateTime? _promoCooldownUntil;

  @override
  Future<SubscriptionState> build() async {
    // Rebuild when the logged-in user changes so stale cache is never reused.
    final user = ref.watch(currentUserProvider);

    // Sync RC user identity so RevenueCat can attribute purchases correctly.
    if (user != null) {
      Purchases.logIn(user.id).ignore();
      AnalyticsService.identify(
        user.id,
        isPro: state.valueOrNull?.isPro ?? false,
      );
    }

    // Listen to RC CustomerInfo updates (background renewals, cancellations).
    void onRCUpdate(CustomerInfo info) => _handleRCUpdate(info);
    Purchases.addCustomerInfoUpdateListener(onRCUpdate);
    ref.onDispose(() {
      Purchases.removeCustomerInfoUpdateListener(onRCUpdate);
      if (user == null) Purchases.logOut().ignore();
    });

    return _loadInitialState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initiates the native purchase flow via RevenueCat.
  Future<void> purchase() async {
    _setLoading(true);
    try {
      final result =
          await ref.read(subscriptionRepositoryProvider).purchaseProPlan();
      await _applyRCResult(result, isRestore: false);
    } on RCPurchaseCancelledException {
      final current = state.valueOrNull ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isLoading: false, clearError: true));
      AnalyticsService.track(AnalyticsService.purchaseCancelled);
    } on RCPurchaseException catch (e) {
      _setError(e.message);
      AnalyticsService.track(AnalyticsService.purchaseError, {
        'error': e.message,
      });
    }
  }

  /// Restores previous purchases via RevenueCat.
  Future<void> restorePurchases() async {
    _setLoading(true);
    try {
      final result =
          await ref.read(subscriptionRepositoryProvider).restoreProPlan();
      await _applyRCResult(result, isRestore: true);
    } on RCPurchaseException catch (e) {
      _setError(e.message);
      AnalyticsService.track(AnalyticsService.purchaseError, {
        'error': e.message,
        'flow': 'restore',
      });
    }
  }

  /// Redeems a promo code with client-side rate limiting.
  Future<void> redeemPromoCode(String code) async {
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

      _promoFailedAttempts = 0;
      _promoCooldownUntil = null;

      if (result.isSubscription) {
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

        AnalyticsService.track(AnalyticsService.promoCodeRedeemed, {
          'type': 'subscription',
          'duration_days': result.durationDays,
        });
      } else {
        final current = state.valueOrNull ?? const SubscriptionState();
        state = AsyncData(
          current.copyWith(
            pendingDiscountPercentage: result.discountPercentage,
          ),
        );

        AnalyticsService.track(AnalyticsService.promoCodeRedeemed, <String, Object>{
          'type': 'discount',
          if (result.discountPercentage != null)
            'discount_percentage': result.discountPercentage!,
        });
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

      AnalyticsService.track(AnalyticsService.freeTrialStarted, {
        'expires_at': expiresAt.toIso8601String(),
      });
    } catch (e) {
      _setError('Error al activar la prueba gratuita');
    }
  }

  /// Forces a re-check against Supabase + RevenueCat, ignoring the 24 h cache.
  Future<void> forceRefresh() async {
    _setLoading(true);
    final fresh = await _fetchRemote();
    state = AsyncData(fresh);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<SubscriptionState> _loadInitialState() async {
    final storage = SecureStorageService.instance;

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

    bool cacheStale = true;
    if (cachedCheckedAt != null) {
      final checkedAt = DateTime.parse(cachedCheckedAt);
      cacheStale = DateTime.now().difference(checkedAt) > _kCacheTtl;
    }

    if (!cacheStale) return fast;

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

  /// Checks Supabase (covers promo/trial) and RC (covers store subscriptions).
  /// If RC shows a later active entitlement it is synced back to Supabase.
  Future<SubscriptionState> _fetchRemote() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final remote = await repo.fetchRemoteSubscription();
    final trialUsed = await repo.checkTrialUsed();

    DateTime? expiresAt = remote.expiresAt;
    String? source = remote.source;

    // Reconcile with RC: if RC has an active entitlement with a later expiry,
    // sync it to Supabase so all sources stay consistent.
    final rcStatus = await repo.getCurrentRCStatus();
    if (rcStatus != null && rcStatus.isPro && rcStatus.expiresAt != null) {
      final rcExpiry = rcStatus.expiresAt!;
      if (expiresAt == null || rcExpiry.isAfter(expiresAt)) {
        expiresAt = rcExpiry;
        source = rcStatus.source;
        await repo.upsertSubscription(
          expiresAt: expiresAt,
          source: source,
          storeTxId: rcStatus.storeTxId,
        );
      }
    }

    await _persistCache(
        expiresAt: expiresAt, source: source, trialUsed: trialUsed);
    return SubscriptionState(
        expiresAt: expiresAt, source: source, trialUsed: trialUsed);
  }

  /// Handles a RevenueCat CustomerInfo update pushed by the SDK
  /// (e.g. subscription renewed or cancelled by the store).
  Future<void> _handleRCUpdate(CustomerInfo info) async {
    final entitlement = info.entitlements.active[kRCEntitlementId];
    if (entitlement == null) return; // not PRO — let the next 24 h check handle expiry

    final source = switch (entitlement.store) {
      Store.appStore || Store.macAppStore => 'app_store',
      Store.playStore => 'play_store',
      Store.amazon => 'amazon',
      Store.stripe || Store.rcBilling => 'stripe',
      Store.promotional => 'promotional',
      _ => 'unknown',
    };
    final expiresAtStr = entitlement.expirationDate;
    if (expiresAtStr == null) return;
    final expiresAt = DateTime.tryParse(expiresAtStr)?.toLocal();
    if (expiresAt == null) return;

    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.upsertSubscription(expiresAt: expiresAt, source: source);
    await _persistCache(expiresAt: expiresAt, source: source);

    state = AsyncData(
      SubscriptionState(
        expiresAt: expiresAt,
        source: source,
        trialUsed: state.valueOrNull?.trialUsed ?? false,
      ),
    );
  }

  /// Applies a successful purchase/restore result: upserts Supabase, updates
  /// cache and state, and fires the appropriate PostHog event.
  Future<void> _applyRCResult(
    RCPurchaseResult result, {
    required bool isRestore,
  }) async {
    if (!result.isPro) {
      // Restore found nothing — show a neutral state.
      final current = state.valueOrNull ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isLoading: false, clearError: true));
      return;
    }

    // Apply bonus days from a pending discount promo code, if any.
    final current = state.valueOrNull ?? const SubscriptionState();
    final bonusDays = current.discountBonusDays;
    final expiresAt = result.expiresAt ??
        DateTime.now().add(Duration(days: 31 + bonusDays));

    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.upsertSubscription(
      expiresAt: expiresAt,
      source: result.source,
      storeTxId: result.storeTxId,
    );
    await _persistCache(expiresAt: expiresAt, source: result.source);

    state = AsyncData(
      SubscriptionState(
        expiresAt: expiresAt,
        source: result.source,
        trialUsed: current.trialUsed,
      ),
    );

    final eventName = isRestore
        ? AnalyticsService.subscriptionRestored
        : AnalyticsService.subscriptionStarted;
    AnalyticsService.track(eventName, {
      'source': result.source,
      'expires_at': expiresAt.toIso8601String(),
    });

    // Update PostHog person property.
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      AnalyticsService.identify(userId, isPro: true);
    }
  }

  // SECURITY: The subscription cache (including expiresAt) is stored in
  // flutter_secure_storage (Android EncryptedSharedPreferences / iOS Keychain).
  // On a rooted/jailbroken device the stored values could be tampered with to
  // extend a subscription locally. This is mitigated by the 24-hour TTL that
  // forces a server re-check, but a user in airplane mode could exploit the
  // stale cache. Consider adding a server-signed expiry token if this becomes
  // a significant abuse vector.
  Future<void> _persistCache({
    DateTime? expiresAt,
    String? source,
    bool? trialUsed,
  }) async {
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
    state =
        AsyncData(current.copyWith(isLoading: false, purchaseError: message));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Main subscription provider. keepAlive = true so it survives screen navigation.
final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

/// Derived bool provider for widgets that only need to know "is user PRO?".
final isProProvider = Provider<bool>((ref) {
  return ref.watch(
    subscriptionProvider.select((s) => s.valueOrNull?.isPro ?? false),
  );
});
