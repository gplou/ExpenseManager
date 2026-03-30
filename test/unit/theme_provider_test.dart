import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_app/core/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier', () {
    test('defaults to light mode when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final theme = await container.read(themeModeProvider.future);
      expect(theme, ThemeMode.light);
    });

    test('loads dark mode when prefs has "dark"', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final theme = await container.read(themeModeProvider.future);
      expect(theme, ThemeMode.dark);
    });

    test('loads light mode when prefs has "light"', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final theme = await container.read(themeModeProvider.future);
      expect(theme, ThemeMode.light);
    });

    test('unknown prefs value falls back to light', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final theme = await container.read(themeModeProvider.future);
      expect(theme, ThemeMode.light);
    });

    test('toggle switches from light to dark', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      await container.read(themeModeProvider.notifier).toggle();

      final theme = container.read(themeModeProvider).value;
      expect(theme, ThemeMode.dark);
    });

    test('toggle switches from dark to light', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      await container.read(themeModeProvider.notifier).toggle();

      final theme = container.read(themeModeProvider).value;
      expect(theme, ThemeMode.light);
    });

    test('toggle twice returns to original mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      final original = container.read(themeModeProvider).value;

      await container.read(themeModeProvider.notifier).toggle();
      await container.read(themeModeProvider.notifier).toggle();

      final restored = container.read(themeModeProvider).value;
      expect(restored, original);
    });

    test('toggle persists new value to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      await container.read(themeModeProvider.notifier).toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('toggle to light persists "light" to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      await container.read(themeModeProvider.notifier).toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });
}
