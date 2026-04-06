import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── formatAmount ────────────────────────────────────────────────────────────

  group('formatAmount – dotDecimal', () {
    test('formats integer as X,XXX.XX', () {
      expect(formatAmount(1234.5, NumberFormatStyle.dotDecimal), '1,234.50');
    });

    test('formats small number without thousands separator', () {
      expect(formatAmount(9.99, NumberFormatStyle.dotDecimal), '9.99');
    });

    test('formats large number with multiple separators', () {
      expect(
          formatAmount(1234567.89, NumberFormatStyle.dotDecimal), '1,234,567.89');
    });

    test('formats negative value with leading minus', () {
      expect(formatAmount(-500.0, NumberFormatStyle.dotDecimal), '-500.00');
    });

    test('formats zero', () {
      expect(formatAmount(0, NumberFormatStyle.dotDecimal), '0.00');
    });

    test('respects custom decimals=0', () {
      expect(
          formatAmount(1234.0, NumberFormatStyle.dotDecimal, decimals: 0), '1,234');
    });
  });

  group('formatAmount – commaDecimal', () {
    test('formats integer as X.XXX,XX', () {
      expect(
          formatAmount(1234.5, NumberFormatStyle.commaDecimal), '1.234,50');
    });

    test('formats small number without thousands separator', () {
      expect(formatAmount(9.99, NumberFormatStyle.commaDecimal), '9,99');
    });

    test('formats large number with multiple separators', () {
      expect(
          formatAmount(1234567.89, NumberFormatStyle.commaDecimal),
          '1.234.567,89');
    });

    test('formats negative value with leading minus', () {
      expect(formatAmount(-500.0, NumberFormatStyle.commaDecimal), '-500,00');
    });
  });

  // ── NumberFormatNotifier ────────────────────────────────────────────────────

  group('NumberFormatNotifier', () {
    test('defaults to dotDecimal when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final style = await container.read(numberFormatProvider.future);
      expect(style, NumberFormatStyle.dotDecimal);
    });

    test('loads commaDecimal when prefs has "commaDecimal"', () async {
      SharedPreferences.setMockInitialValues(
          {'number_format_style': 'commaDecimal'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final style = await container.read(numberFormatProvider.future);
      expect(style, NumberFormatStyle.commaDecimal);
    });

    test('loads dotDecimal when prefs has "dotDecimal"', () async {
      SharedPreferences.setMockInitialValues(
          {'number_format_style': 'dotDecimal'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final style = await container.read(numberFormatProvider.future);
      expect(style, NumberFormatStyle.dotDecimal);
    });

    test('unknown prefs value falls back to dotDecimal', () async {
      SharedPreferences.setMockInitialValues({'number_format_style': 'other'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final style = await container.read(numberFormatProvider.future);
      expect(style, NumberFormatStyle.dotDecimal);
    });

    test('setStyle updates state and persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(numberFormatProvider.future);
      await container
          .read(numberFormatProvider.notifier)
          .setStyle(NumberFormatStyle.commaDecimal);

      expect(
        container.read(numberFormatProvider).value,
        NumberFormatStyle.commaDecimal,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('number_format_style'), 'commaDecimal');
    });

    test('setStyle back to dotDecimal persists correctly', () async {
      SharedPreferences.setMockInitialValues(
          {'number_format_style': 'commaDecimal'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(numberFormatProvider.future);
      await container
          .read(numberFormatProvider.notifier)
          .setStyle(NumberFormatStyle.dotDecimal);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('number_format_style'), 'dotDecimal');
    });
  });
}
