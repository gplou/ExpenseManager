import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/domain/transaction_categories.dart';
import 'package:productivity_app/features/transactions/domain/transaction_model.dart';

void main() {
  group('TransactionCategories', () {
    test('income categories list is not empty', () {
      expect(TransactionCategories.income, isNotEmpty);
    });

    test('expense categories list is not empty', () {
      expect(TransactionCategories.expense, isNotEmpty);
    });

    test('forType returns income categories for income type', () {
      expect(
        TransactionCategories.forType(TransactionType.income),
        TransactionCategories.income,
      );
    });

    test('forType returns expense categories for expense type', () {
      expect(
        TransactionCategories.forType(TransactionType.expense),
        TransactionCategories.expense,
      );
    });

    test('iconFor returns correct icon for known category', () {
      final icon = TransactionCategories.iconFor('Comida', TransactionType.expense);
      expect(icon, Icons.restaurant_outlined);
    });

    test('iconFor returns default icon for unknown category', () {
      final icon = TransactionCategories.iconFor('Unknown', TransactionType.expense);
      expect(icon, Icons.label_outlined);
    });

    test('iconFor finds icon in extra categories', () {
      final extra = [
        const TransactionCategory(name: 'CustomCat', icon: Icons.star),
      ];
      final icon = TransactionCategories.iconFor(
        'CustomCat',
        TransactionType.expense,
        extra: extra,
      );
      expect(icon, Icons.star);
    });

    test('all categories have non-empty names', () {
      for (final cat in TransactionCategories.income) {
        expect(cat.name, isNotEmpty);
      }
      for (final cat in TransactionCategories.expense) {
        expect(cat.name, isNotEmpty);
      }
    });

    test('pickableIcons list is not empty', () {
      expect(TransactionCategories.pickableIcons, isNotEmpty);
    });

    test('income has "Otros" category', () {
      expect(TransactionCategories.income.any((c) => c.name == 'Otros'), isTrue);
    });

    test('expense has "Otros" category', () {
      expect(TransactionCategories.expense.any((c) => c.name == 'Otros'), isTrue);
    });
  });
}
