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

  // ── Identity ───────────────────────────────────────────────────────────────

  /// Call after login. Sets `is_pro` as a live property so it is always
  /// up-to-date in PostHog person profiles.
  static Future<void> identify(
    String userId, {
    bool isPro = false,
  }) async {
    try {
      await Posthog().identify(
        userId: userId,
        userProperties: {'is_pro': isPro},
      );
    } catch (e) {
      debugPrint('[Analytics] identify error: $e');
    }
  }

  /// Call after logout to disassociate subsequent events from the user.
  static Future<void> reset() async {
    try {
      await Posthog().reset();
    } catch (e) {
      debugPrint('[Analytics] reset error: $e');
    }
  }

  // ── Event tracking ─────────────────────────────────────────────────────────

  /// Track any named event with optional properties.
  static Future<void> track(
    String event, [
    Map<String, Object>? properties,
  ]) async {
    try {
      await Posthog().capture(
        eventName: event,
        properties: properties,
      );
    } catch (e) {
      debugPrint('[Analytics] track($event) error: $e');
    }
  }
}
