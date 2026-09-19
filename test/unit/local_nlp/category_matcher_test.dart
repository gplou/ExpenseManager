import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/local_nlp/category_matcher.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

void main() {
  group('CategoryMatcher', () {
    test('matches an expense keyword', () {
      expect(
        CategoryMatcher.match('pagué el alquiler', TransactionType.expense),
        'Vivienda',
      );
    });

    test('matches an income keyword', () {
      expect(
        CategoryMatcher.match('dividendo de mis acciones', TransactionType.income),
        'Inversión',
      );
    });

    test('is case-insensitive', () {
      expect(
        CategoryMatcher.match('CENA EN EL RESTAURANTE', TransactionType.expense),
        'Comida',
      );
    });

    test('falls back to Otros when nothing matches', () {
      expect(
        CategoryMatcher.match('algo sin categoría clara', TransactionType.expense),
        'Otros',
      );
    });

    test('never matches an income-only category for an expense', () {
      // "regalo" (gift) only has keywords under the income category
      // "Regalo" — buying a gift is an expense and must not leak it.
      expect(
        CategoryMatcher.match('compré un regalo', TransactionType.expense),
        isNot('Regalo'),
      );
    });

    test('never matches an expense-only category for an income', () {
      expect(
        CategoryMatcher.match('cena en el restaurante', TransactionType.income),
        isNot('Comida'),
      );
    });

    // Regression: naive substring matching classified almost every Spanish
    // expense sentence as Transporte, because 'gas' (a Transporte keyword,
    // for English "gas"/fuel) is a substring of 'gasté'/'gasto'/'gastos'.
    test('does not match "gas" inside "gasté" (Transporte false positive)',
        () {
      expect(
        CategoryMatcher.match('gasté 30 en el dentista', TransactionType.expense),
        'Salud',
      );
    });

    // Regression: 'ropa' (Ropa keyword) is a substring of 'Europa'.
    test('does not match "ropa" inside "Europa"', () {
      expect(
        CategoryMatcher.match('pagué 200 en un viaje a Europa', TransactionType.expense),
        isNot('Ropa'),
      );
    });
  });
}
