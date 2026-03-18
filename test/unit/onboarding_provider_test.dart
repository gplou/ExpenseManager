import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_app/features/onboarding/providers/onboarding_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingNotifier', () {
    test('defaults to false when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen = await container.read(onboardingProvider.future);
      expect(seen, isFalse);
    });

    test('loads true when prefs has true', () async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen = await container.read(onboardingProvider.future);
      expect(seen, isTrue);
    });

    test('loads false when prefs has false', () async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': false});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen = await container.read(onboardingProvider.future);
      expect(seen, isFalse);
    });

    test('markSeen sets state to true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingProvider.future);
      await container.read(onboardingProvider.notifier).markSeen();

      expect(container.read(onboardingProvider).value, isTrue);
    });

    test('markSeen persists true to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingProvider.future);
      await container.read(onboardingProvider.notifier).markSeen();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding'), isTrue);
    });

    test('markSeen is idempotent when already true', () async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingProvider.future);
      await container.read(onboardingProvider.notifier).markSeen();

      expect(container.read(onboardingProvider).value, isTrue);
    });
  });
}
