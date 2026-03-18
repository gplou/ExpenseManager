import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_app/core/providers/voice_enabled_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VoiceEnabledNotifier', () {
    test('defaults to false when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final enabled = await container.read(voiceEnabledProvider.future);
      expect(enabled, isFalse);
    });

    test('loads true when prefs has true', () async {
      SharedPreferences.setMockInitialValues({'voice_enabled': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final enabled = await container.read(voiceEnabledProvider.future);
      expect(enabled, isTrue);
    });

    test('loads false when prefs has false', () async {
      SharedPreferences.setMockInitialValues({'voice_enabled': false});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final enabled = await container.read(voiceEnabledProvider.future);
      expect(enabled, isFalse);
    });

    test('toggle switches from false to true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(voiceEnabledProvider.future);
      await container.read(voiceEnabledProvider.notifier).toggle();

      expect(container.read(voiceEnabledProvider).value, isTrue);
    });

    test('toggle switches from true to false', () async {
      SharedPreferences.setMockInitialValues({'voice_enabled': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(voiceEnabledProvider.future);
      await container.read(voiceEnabledProvider.notifier).toggle();

      expect(container.read(voiceEnabledProvider).value, isFalse);
    });

    test('toggle twice returns to original value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(voiceEnabledProvider.future);
      final original = container.read(voiceEnabledProvider).value;

      await container.read(voiceEnabledProvider.notifier).toggle();
      await container.read(voiceEnabledProvider.notifier).toggle();

      expect(container.read(voiceEnabledProvider).value, original);
    });

    test('toggle persists new value to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(voiceEnabledProvider.future);
      await container.read(voiceEnabledProvider.notifier).toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('voice_enabled'), isTrue);
    });
  });
}
