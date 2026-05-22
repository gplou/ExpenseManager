import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/category_selector_row.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: child),
    );

void main() {
  group('CategorySelectorRow', () {
    testWidgets('shows the placeholder prompt when nothing is selected',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CategorySelectorRow(
          selectedCategory: null,
          type: TransactionType.expense,
          accentColor: Colors.red,
          accentLight: Colors.red.shade100,
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Generic folder emoji when no category is picked
      expect(find.text('📂'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('shows category emoji and localized name when selected',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CategorySelectorRow(
          selectedCategory: 'Comida',
          type: TransactionType.expense,
          accentColor: Colors.red,
          accentLight: Colors.red.shade100,
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('🍕'), findsOneWidget);
      // Spanish localisation of Comida is "Comida"
      expect(find.text('Comida'), findsOneWidget);
    });

    testWidgets('shows custom emoji when selected category is custom',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CategorySelectorRow(
          selectedCategory: 'Cripto',
          type: TransactionType.income,
          accentColor: Colors.green,
          accentLight: Colors.green.shade100,
          onTap: () {},
          customCategories: const [
            TransactionCategory(
              name: 'Cripto',
              icon: Icons.label_outlined,
              emojiOverride: '💎',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('💎'), findsOneWidget);
      expect(find.text('Cripto'), findsOneWidget);
    });

    testWidgets('falls back to icon for a custom category without emoji',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CategorySelectorRow(
          selectedCategory: 'Custom',
          type: TransactionType.expense,
          accentColor: Colors.red,
          accentLight: Colors.red.shade100,
          onTap: () {},
          customCategories: const [
            TransactionCategory(
              name: 'Custom',
              icon: Icons.attach_money,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });

    testWidgets('tap invokes onTap callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        CategorySelectorRow(
          selectedCategory: null,
          type: TransactionType.expense,
          accentColor: Colors.red,
          accentLight: Colors.red.shade100,
          onTap: () => taps++,
        ),
      ));
      await tester.tap(find.byType(CategorySelectorRow));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
