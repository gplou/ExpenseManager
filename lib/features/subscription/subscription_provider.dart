import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:expense_manager/core/security/secure_storage.dart';
import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'data/purchases_gateway.dart';
import 'data/revenue_cat_adapter.dart';
import 'domain/subscription_expiry_calculator.dart';
import 'subscription_repository.dart';
import 'subscription_state.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kCacheExpiresAtKey = 'sub_expires_at';
const _kCacheCheckedAtKey = 'sub_checked_at';
const _kCacheSourceKey = 'sub_source';
const _kCacheUserIdKey = 'sub_user_id';
const _kCacheTrialUsedKey = 'sub_trial_used';

/// Re-check the store/Supabase at most once every [_kCacheTtl].
/// Keeping this short limits the window where a tampered cache (e.g. on a
/// rooted device) could grant offline PRO access beyond the real expiry.
const _kCacheTtl = Duration(hours: 4);

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

  /// Tracks the RC identity currently logged in so we can detect user
  /// transitions across [build] re-runs. Without this we can't distinguish
  /// "first build for a user" from "same user rebuilt" from "logout".
  String? _rcIdentityUserId;

  /// Set while a purchase/restore is in flight. The RC SDK fires
  /// `CustomerInfoUpdateListener` when the entitlement changes after a
  /// purchase; that callback runs concurrently with [_applyRCResult] and
  /// would overwrite Supabase without the bonus-days from a pending discount.
  /// We suppress the listener for the duration of the explicit flow.
  bool _purchaseInFlight = false;

  /// Incremented on every [build]. A background poll captures the value at
  /// launch and bails out if it changes (e.g. user logged out/in mid-poll),
  /// so a stale loop can never write state for a different user/session.
  int _generation = 0;

  @override
  Future<SubscriptionState> build() async {
    _generation++;
    final purchases = ref.read(purchasesGatewayProvider);
    // Rebuild when the logged-in user changes so stale cache is never reused.
    final user = ref.watch(currentUserProvider);
    _syncRevenueCatIdentity(purchases, user?.id);

    if (user != null) {
      AnalyticsService.identify(
        user.id,
        isPro: state.value?.isPro ?? false,
      );
    }

    // Listen to RC CustomerInfo updates (background renewals, cancellations).
    void onRCUpdate(CustomerInfo info) => _handleRCUpdate(info);
    purchases.addCustomerInfoUpdateListener(onRCUpdate);
    ref.onDispose(() {
      purchases.removeCustomerInfoUpdateListener(onRCUpdate);
      // Release the RC identity on provider disposal so the next app session
      // starts clean. We intentionally do NOT gate on `user == null` here:
      // that captured the build-time value, not the current one.
      if (_rcIdentityUserId != null) {
        purchases.logOut();
        _rcIdentityUserId = null;
      }
    });

    return _loadInitialState();
  }

  /// Logs in/out of RevenueCat as the signed-in Supabase user changes.
  /// Called from [build] every time `currentUserProvider` emits; the
  /// [_rcIdentityUserId] field makes the transitions idempotent so we only
  /// hit the RC SDK when the identity actually changed.
  void _syncRevenueCatIdentity(PurchasesGateway purchases, String? newUserId) {
    if (_rcIdentityUserId == newUserId) return;
    if (_rcIdentityUserId != null && newUserId != _rcIdentityUserId) {
      purchases.logOut();
    }
    if (newUserId != null) {
      purchases.logIn(newUserId);
    }
    _rcIdentityUserId = newUserId;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initiates the native purchase flow via RevenueCat for [package].
  Future<void> purchase(Package package) async {
    _setLoading(true);
    _purchaseInFlight = true;
    try {
      final result = await ref
          .read(subscriptionRepositoryProvider)
          .purchaseProPlan(package);
      await _applyRCResult(result, isRestore: false);
    } on RCPurchaseCancelledException {
      final current = state.value ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isLoading: false, clearError: true));
      AnalyticsService.track(AnalyticsService.purchaseCancelled);
    } on RCPurchaseException catch (e) {
      _setError(SubscriptionErrorCode.purchaseFailed);
      AnalyticsService.track(AnalyticsService.purchaseError, {
        'error': e.message,
      });
    } finally {
      _purchaseInFlight = false;
    }
  }

  /// Restores previous purchases via RevenueCat.
  Future<void> restorePurchases() async {
    _setLoading(true);
    _purchaseInFlight = true;
    try {
      final result =
          await ref.read(subscriptionRepositoryProvider).restoreProPlan();
      await _applyRCResult(result, isRestore: true);
    } on RCPurchaseException catch (e) {
      _setError(SubscriptionErrorCode.restoreFailed);
      AnalyticsService.track(AnalyticsService.purchaseError, {
        'error': e.message,
        'flow': 'restore',
      });
    } finally {
      _purchaseInFlight = false;
    }
  }

  /// Redeems a promo code with client-side rate limiting.
  Future<void> redeemPromoCode(String code) async {
    if (_promoCooldownUntil != null &&
        clock.now().isBefore(_promoCooldownUntil!)) {
      final remaining =
          _promoCooldownUntil!.difference(clock.now()).inSeconds;
      throw PromoCooldownException(remaining);
    }

    final repo = ref.read(subscriptionRepositoryProvider);

    try {
      final result = await repo.redeemPromoCode(code);

      _promoFailedAttempts = 0;
      _promoCooldownUntil = null;

      if (result.isSubscription) {
        // The server-side RPC already wrote the subscriptions row with the
        // stacked expiry. We just read back the authoritative value — the
        // client never decides the final expires_at.
        final expiresAt = result.expiresAt ??
            clock.now().add(Duration(days: result.durationDays));

        await _persistCache(expiresAt: expiresAt, source: 'promo_code');

        state = AsyncData(
          SubscriptionState(expiresAt: expiresAt, source: 'promo_code'),
        );

        AnalyticsService.track(AnalyticsService.promoCodeRedeemed, {
          'type': 'subscription',
          'duration_days': result.durationDays,
        });
      } else {
        final current = state.value ?? const SubscriptionState();
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
        _promoCooldownUntil = clock.now().add(_kPromoCooldown);
        _promoFailedAttempts = 0;
      }
      rethrow;
    }
  }

  /// Activates the one-time free trial ([kFreeTrialDays] days).
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
    } catch (e, st) {
      await SentryService.captureException(e, stackTrace: st);
      _setError(SubscriptionErrorCode.trialFailed);
    }
  }

  /// Forces a re-check against Supabase + RevenueCat, ignoring the cache TTL.
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
      cacheStale = clock.now().difference(checkedAt) > _kCacheTtl;
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
  /// Uses the later of the two expiries for local display; the
  /// revenuecat-webhook is the authoritative Supabase writer.
  Future<SubscriptionState> _fetchRemote() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final remote = await repo.fetchRemoteSubscription();
    final trialUsed = await repo.checkTrialUsed();

    DateTime? expiresAt = remote.expiresAt;
    String? source = remote.source;

    // If RC has an active entitlement with a later expiry, use it locally.
    // We no longer write to Supabase from the client — the webhook handles that.
    final rcStatus = await repo.getCurrentRCStatus();
    if (rcStatus != null && rcStatus.isPro && rcStatus.expiresAt != null) {
      final rcExpiry = rcStatus.expiresAt!;
      if (expiresAt == null || rcExpiry.isAfter(expiresAt)) {
        expiresAt = rcExpiry;
        source = rcStatus.source;
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
    // An explicit purchase/restore flow is running — skip to avoid racing
    // with the bonus-days logic in _applyRCResult.
    if (_purchaseInFlight) return;

    // No Supabase session (e.g. listener fires mid-logout). Bail out.
    if (ref.read(currentUserProvider) == null) return;

    final result = RevenueCatAdapter.fromCustomerInfo(info);
    // Not PRO or no expiry — let the next cache-TTL check handle it.
    if (!result.isPro || result.expiresAt == null) return;

    final expiresAt = result.expiresAt!;
    final source = result.source;

    // Update local state from RC. The revenuecat-webhook will have already
    // written (or will write) the authoritative Supabase row.
    await _persistCache(expiresAt: expiresAt, source: source);

    state = AsyncData(
      SubscriptionState(
        expiresAt: expiresAt,
        source: source,
        trialUsed: state.value?.trialUsed ?? false,
      ),
    );
  }

  /// Applies a successful purchase/restore result: updates cache and state
  /// from RC data immediately, then polls Supabase in the background for the
  /// webhook confirmation.
  ///
  /// The client no longer writes to Supabase directly — the revenuecat-webhook
  /// Edge Function is the authoritative writer. See migration
  /// 20260528000001_lock_apply_rc_entitlement.sql.
  Future<void> _applyRCResult(
    RCPurchaseResult result, {
    required bool isRestore,
  }) async {
    if (!result.isPro) {
      // Restore found nothing — show a neutral state.
      final current = state.value ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isLoading: false, clearError: true));
      return;
    }

    // Apply bonus days from a pending discount promo code, if any.
    // BUG FIX: the previous implementation only applied bonus days when the
    // store did NOT return an expiry (the `??` fallback branch), meaning real
    // store purchases — which always return an expiry — silently dropped the
    // discount the user redeemed. The calculator now adds bonus days on top
    // of the store expiry in all cases.
    final current = state.value ?? const SubscriptionState();
    final expiresAt = SubscriptionExpiryCalculator.effectiveExpiry(
      storeExpiry: result.expiresAt,
      bonusDays: current.discountBonusDays,
      fallbackPeriodDays: kSubscriptionDays,
    );

    // Update state immediately from RC data (optimistic). This lets the user
    // see PRO features right away without waiting for the webhook.
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

    // Poll Supabase in the background until the revenuecat-webhook confirms
    // the purchase (typically arrives within a few seconds).
    _pollForWebhookConfirmation(purchasedAt: clock.now());
  }

  /// Polls Supabase every 5 seconds (up to 10 attempts = 50s) waiting for the
  /// revenuecat-webhook to write the authoritative subscription row.
  /// Silently updates state + cache when confirmation arrives.
  ///
  /// Guarded by [_generation] + a [ref.keepAlive] token so a rebuild (e.g. the
  /// user logging out and back in during the 50s window) cancels this loop
  /// instead of writing state/cache for a stale session.
  void _pollForWebhookConfirmation({required DateTime purchasedAt}) {
    final generation = _generation;
    final keepAlive = ref.keepAlive();
    Future(() async {
      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(seconds: 5));
          if (_generation != generation) return;
          try {
            final remote = await repo.fetchRemoteSubscription();
            if (_generation != generation) return;
            if (remote.expiresAt != null &&
                remote.expiresAt!.isAfter(purchasedAt)) {
              await _persistCache(
                  expiresAt: remote.expiresAt, source: remote.source);
              state = AsyncData(
                SubscriptionState(
                  expiresAt: remote.expiresAt,
                  source: remote.source,
                  trialUsed: state.value?.trialUsed ?? false,
                ),
              );
              return;
            }
          } catch (_) {
            // Silently retry — RC optimistic state is already in state.
          }
        }
      } finally {
        keepAlive.close();
      }
    });
  }

  // SECURITY: The subscription cache (including expiresAt) is stored in
  // flutter_secure_storage (Android EncryptedSharedPreferences / iOS Keychain).
  // On a rooted/jailbroken device the stored values could be tampered with to
  // extend a subscription locally. This is mitigated by the cache TTL
  // ([_kCacheTtl]) that forces a server re-check, but a user in airplane mode
  // could exploit the stale cache. Consider adding a server-signed expiry
  // token if this becomes a significant abuse vector.
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
        _kCacheCheckedAtKey, clock.now().toUtc().toIso8601String());
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
    final current = state.value ?? const SubscriptionState();
    state = AsyncData(current.copyWith(isLoading: loading, clearError: true));
  }

  void _setError(SubscriptionErrorCode code) {
    final current = state.value ?? const SubscriptionState();
    state =
        AsyncData(current.copyWith(isLoading: false, errorCode: code));
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
    subscriptionProvider.select((s) => s.value?.isPro ?? false),
  );
});

/// Loads the current RevenueCat offering with real store prices.
/// Auto-disposed: fetched fresh each time the paywall opens.
final offeringsProvider = FutureProvider.autoDispose<Offering?>((ref) async {
  final offerings = await ref.read(purchasesGatewayProvider).getOfferings();
  return offerings.current;
});
