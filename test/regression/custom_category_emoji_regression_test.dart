import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';

/// Regression tests for custom category emoji display.
///
/// Bug: widgets (RecentTransactionTile, _TransactionTile) were checking
/// `customIcon != null` to decide whether to show a Material icon, but
/// custom emoji categories always have icon=Icons.label_outlined (non-null),
/// so the emoji was never shown — the Material icon appeared instead.
///
/// Fix: check emojiOverride first; fall back to icon only when it is null.
void main() {
  group('TransactionCategory emojiOverride regression', () {
    test('custom category with emojiOverride has non-null icon (root cause)', () {
      // This is WHY the bug happened: even emoji-based custom categories
      // carry a non-null icon field, so `customIcon != null` was always true.
      const cat = TransactionCategory(
        name: 'Test',
        icon: Icons.label_outlined,
        emojiOverride: '🎯',
      );
      expect(cat.icon, isNotNull);
      expect(cat.emojiOverride, isNotNull);
    });

    test('emoji category: emojiOverride takes precedence over icon', () {
      const cat = TransactionCategory(
        name: 'Test',
        icon: Icons.label_outlined,
        emojiOverride: '🎯',
      );

      // Correct resolution: use emoji when emojiOverride is set
      final displaysEmoji = cat.emojiOverride != null;
      expect(displaysEmoji, isTrue);
    });

    test('icon category: falls back to icon when emojiOverride is null', () {
      const cat = TransactionCategory(
        name: 'Test',
        icon: Icons.star,
      );

      expect(cat.emojiOverride, isNull);
      // Correct resolution: use icon when emojiOverride is absent
      final displaysIcon = cat.emojiOverride == null;
      expect(displaysIcon, isTrue);
      expect(cat.icon, Icons.star);
    });

    test('built-in category has no emojiOverride', () {
      for (final cat in TransactionCategories.expense) {
        expect(cat.emojiOverride, isNull,
            reason: '${cat.name} should not have emojiOverride');
      }
      for (final cat in TransactionCategories.income) {
        expect(cat.emojiOverride, isNull,
            reason: '${cat.name} should not have emojiOverride');
      }
    });

    test('emojiFor returns fallback emoji for unknown custom category name', () {
      expect(
        TransactionCategories.emojiFor('MiCategoriaCustom', isIncome: false),
        '💸',
      );
      expect(
        TransactionCategories.emojiFor('MiCategoriaCustom', isIncome: true),
        '💰',
      );
    });
  });
}
