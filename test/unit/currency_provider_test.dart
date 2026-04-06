import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';

void main() {
  group('currencySymbol', () {
    test('returns € for EUR', () {
      expect(currencySymbol('EUR'), '€');
    });

    test('returns \$ for USD', () {
      expect(currencySymbol('USD'), '\$');
    });

    test('returns £ for GBP', () {
      expect(currencySymbol('GBP'), '£');
    });

    test('returns default (EUR) for unknown code', () {
      expect(currencySymbol('UNKNOWN'), '€');
    });
  });

  group('supportedCurrencies', () {
    test('contains at least 10 currencies', () {
      expect(supportedCurrencies.length, greaterThanOrEqualTo(10));
    });

    test('EUR is the first currency', () {
      expect(supportedCurrencies.first.code, 'EUR');
    });

    test('all currencies have non-empty fields', () {
      for (final c in supportedCurrencies) {
        expect(c.code, isNotEmpty);
        expect(c.symbol, isNotEmpty);
        expect(c.name, isNotEmpty);
        expect(c.flag, isNotEmpty);
      }
    });
  });
}
