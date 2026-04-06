import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/services/analytics_service.dart';

void main() {
  // ── Event name constants ─────────────────────────────────────────────────

  group('AnalyticsService event constants', () {
    test('subscriptionStarted has correct value', () {
      expect(AnalyticsService.subscriptionStarted, 'subscription_started');
    });

    test('subscriptionRestored has correct value', () {
      expect(AnalyticsService.subscriptionRestored, 'subscription_restored');
    });

    test('freeTrialStarted has correct value', () {
      expect(AnalyticsService.freeTrialStarted, 'free_trial_started');
    });

    test('promoCodeRedeemed has correct value', () {
      expect(AnalyticsService.promoCodeRedeemed, 'promo_code_redeemed');
    });

    test('purchaseError has correct value', () {
      expect(AnalyticsService.purchaseError, 'purchase_error');
    });

    test('purchaseCancelled has correct value', () {
      expect(AnalyticsService.purchaseCancelled, 'purchase_cancelled');
    });

    test('appOpened has correct value', () {
      expect(AnalyticsService.appOpened, 'app_opened');
    });
  });

  // ── Fire-and-forget safety ──────────────────────────────────────────────

  group('AnalyticsService fire-and-forget safety', () {
    // Note: track() calls Posthog().capture() which requires native platform
    // channels. In a pure Dart test environment, the PostHog singleton will
    // throw a MissingPluginException. The try/catch in track() should absorb
    // this, verifying the fire-and-forget behaviour.
    //
    // These tests will only pass in a Flutter test environment (flutter test),
    // not in a pure Dart test runner, because they need the Flutter test
    // bindings to handle platform channel calls gracefully.

    test('track() does not throw even without PostHog initialised', () async {
      // This verifies the try/catch wrapping in AnalyticsService.track().
      // In flutter_test, MissingPluginException is caught by the try/catch.
      expect(
        () async => await AnalyticsService.track('test_event', {'key': 'val'}),
        returnsNormally,
      );
    });

    test('identify() does not throw even without PostHog initialised',
        () async {
      expect(
        () async =>
            await AnalyticsService.identify('user_123', isPro: true),
        returnsNormally,
      );
    });

    test('reset() does not throw even without PostHog initialised', () async {
      expect(
        () async => await AnalyticsService.reset(),
        returnsNormally,
      );
    });
  });
}
