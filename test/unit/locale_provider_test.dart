import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('supportedLocales', () {
    test('has exactly 4 locales', () {
      expect(supportedLocales.length, 4);
    });

    test('contains es, en, fr, de', () {
      final codes = supportedLocales.map((l) => l.code).toList();
      expect(codes, containsAll(['es', 'en', 'fr', 'de']));
    });

    test('Spanish is the first locale', () {
      expect(supportedLocales.first.code, 'es');
    });

    test('each locale has non-empty flag and name', () {
      for (final l in supportedLocales) {
        expect(l.flag, isNotEmpty, reason: 'flag empty for ${l.code}');
        expect(l.name, isNotEmpty, reason: 'name empty for ${l.code}');
      }
    });

    test('all locale codes are unique', () {
      final codes = supportedLocales.map((l) => l.code).toSet();
      expect(codes.length, supportedLocales.length);
    });
  });

  group('LocaleNotifier', () {
    test('defaults to Spanish when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = await container.read(localeProvider.future);
      expect(locale.languageCode, 'es');
    });

    test('loads saved locale "en" from prefs', () async {
      SharedPreferences.setMockInitialValues({'locale_code': 'en'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = await container.read(localeProvider.future);
      expect(locale.languageCode, 'en');
    });

    test('loads saved locale "fr" from prefs', () async {
      SharedPreferences.setMockInitialValues({'locale_code': 'fr'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = await container.read(localeProvider.future);
      expect(locale.languageCode, 'fr');
    });

    test('loads saved locale "de" from prefs', () async {
      SharedPreferences.setMockInitialValues({'locale_code': 'de'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = await container.read(localeProvider.future);
      expect(locale.languageCode, 'de');
    });

    test('setLocale updates state immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.future);
      await container.read(localeProvider.notifier).setLocale(const Locale('en'));

      final locale = container.read(localeProvider).value;
      expect(locale?.languageCode, 'en');
    });

    test('setLocale persists code to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.future);
      await container.read(localeProvider.notifier).setLocale(const Locale('de'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale_code'), 'de');
    });

    test('setLocale can change from es to fr', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.future);
      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));

      final locale = container.read(localeProvider).value;
      expect(locale?.languageCode, 'fr');
    });

    test('initial state is loading then resolves', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider); // trigger
      expect(container.read(localeProvider).isLoading, isTrue);

      await container.read(localeProvider.future);
      expect(container.read(localeProvider).isLoading, isFalse);
      expect(container.read(localeProvider).hasValue, isTrue);
    });
  });
}
