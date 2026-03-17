import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_app/core/providers/currency_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CurrencyNotifier', () {
    test('defaults to EUR when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final code = await container.read(currencyProvider.future);
      expect(code, 'EUR');
    });

    test('loads saved currency "USD" from prefs', () async {
      SharedPreferences.setMockInitialValues({'currency_code': 'USD'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final code = await container.read(currencyProvider.future);
      expect(code, 'USD');
    });

    test('loads saved currency "GBP" from prefs', () async {
      SharedPreferences.setMockInitialValues({'currency_code': 'GBP'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final code = await container.read(currencyProvider.future);
      expect(code, 'GBP');
    });

    test('setCurrency updates state immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(currencyProvider.future);
      await container.read(currencyProvider.notifier).setCurrency('JPY');

      final code = container.read(currencyProvider).value;
      expect(code, 'JPY');
    });

    test('setCurrency persists code to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(currencyProvider.future);
      await container.read(currencyProvider.notifier).setCurrency('BRL');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('currency_code'), 'BRL');
    });

    test('setCurrency reflects correct symbol via currencySymbol', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(currencyProvider.future);
      await container.read(currencyProvider.notifier).setCurrency('GBP');

      final code = container.read(currencyProvider).value!;
      expect(currencySymbol(code), '£');
    });

    test('setCurrency can change multiple times', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(currencyProvider.future);
      await container.read(currencyProvider.notifier).setCurrency('USD');
      await container.read(currencyProvider.notifier).setCurrency('MXN');

      final code = container.read(currencyProvider).value;
      expect(code, 'MXN');
    });

    test('initial state is loading then resolves', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(currencyProvider); // trigger
      expect(container.read(currencyProvider).isLoading, isTrue);

      await container.read(currencyProvider.future);
      expect(container.read(currencyProvider).isLoading, isFalse);
      expect(container.read(currencyProvider).hasValue, isTrue);
    });
  });
}
