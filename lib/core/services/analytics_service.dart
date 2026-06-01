import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Thin wrapper around PostHog. All methods are fire-and-forget safe:
/// any PostHog error is caught and logged, never surfaced to the user.
class AnalyticsService {
  AnalyticsService._();

  // ── Event name constants ───────────────────────────────────────────────────

  static const String subscriptionStarted = 'subscription_started';
  static const String subscriptionRestored = 'subscription_restored';
  static const String freeTrialStarted = 'free_trial_started';
  static const String promoCodeRedeemed = 'promo_code_redeemed';
  static const String purchaseError = 'purchase_error';
  static const String purchaseCancelled = 'purchase_cancelled';
  static const String appOpened = 'app_opened';

  static const String transactionCreated = 'transaction_created';
  static const String transactionDeleted = 'transaction_deleted';
  static const String periodChanged = 'period_changed';
  static const String categoryFilterApplied = 'category_filter_applied';
  static const String voiceUsed = 'voice_used';
  static const String photoUsed = 'photo_used';
  static const String exportExcel = 'export_excel';
  static const String onboardingCompleted = 'onboarding_completed';

  // ── Identity ───────────────────────────────────────────────────────────────

  /// Call after login. Sets `is_pro` as a live property so it is always
  /// up-to-date in PostHog person profiles. Fire-and-forget: returns `void`
  /// so callers don't need to await or wrap in `unawaited`.
  static void identify(
    String userId, {
    bool isPro = false,
  }) {
    unawaited(() async {
      try {
        await Posthog().identify(
          userId: userId,
          userProperties: {'is_pro': isPro},
        );
      } catch (e) {
        debugPrint('[Analytics] identify error: $e');
      }
    }());
  }

  /// Call after logout to disassociate subsequent events from the user.
  static void reset() {
    unawaited(() async {
      try {
        await Posthog().reset();
      } catch (e) {
        debugPrint('[Analytics] reset error: $e');
      }
    }());
  }

  // ── Event tracking ─────────────────────────────────────────────────────────

  /// Track any named event with optional properties. Fire-and-forget.
  static void track(
    String event, [
    Map<String, Object>? properties,
  ]) {
    unawaited(() async {
      try {
        await Posthog().capture(
          eventName: event,
          properties: properties,
        );
      } catch (e) {
        debugPrint('[Analytics] track($event) error: $e');
      }
    }());
  }
}
