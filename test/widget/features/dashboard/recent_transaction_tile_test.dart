import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/features/dashboard/widgets/recent_transaction_tile.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: child),
    ),
  );
}

TransactionModel _tx({
  String id = 'tx-1',
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
  double amount = 25.0,
  String? subcategory,
  String? description,
  DateTime? date,
}) =>
    TransactionModel(
      id: id,
      userId: 'u',
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      description: description,
      date: date ?? DateTime.now(),
      createdAt: DateTime.now(),
    );

void main() {
  group('RecentTransactionTile', () {
    testWidgets('expense renders amount with leading "-" sign',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RecentTransactionTile(transaction: _tx(amount: 25, type: TransactionType.expense)),
      ));
      await tester.pumpAndSettle();

      // Default currency=EUR (€) + dotDecimal style → "-€25.00"
      expect(find.textContaining('-'), findsWidgets);
      expect(find.textContaining('25'), findsWidgets);
    });

    testWidgets('income renders amount with leading "+" sign',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RecentTransactionTile(transaction: _tx(amount: 100, type: TransactionType.income, category: 'Salario')),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('+'), findsWidgets);
      expect(find.textContaining('100'), findsWidgets);
    });

    testWidgets('shows the subcategory when present', (tester) async {
      await tester.pumpWidget(_wrap(
        RecentTransactionTile(transaction: _tx(subcategory: 'Restaurante')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Restaurante'), findsOneWidget);
    });

    testWidgets(
        'falls back to description when subcategory is null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RecentTransactionTile(transaction: _tx(description: 'Cena con amigos')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cena con amigos'), findsOneWidget);
    });

    testWidgets('uses custom category emoji when configured',
        (tester) async {
      final customMap = <TransactionType, List<TransactionCategory>>{
        TransactionType.expense: const [
          TransactionCategory(
            name: 'Cripto',
            icon: Icons.label_outlined,
            emojiOverride: '💎',
          ),
        ],
        TransactionType.income: const [],
      };

      await tester.pumpWidget(_wrap(
        RecentTransactionTile(
          transaction: _tx(category: 'Cripto', type: TransactionType.expense),
        ),
        overrides: [
          customCategoriesSyncProvider.overrideWithValue(customMap),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('💎'), findsOneWidget);
    });

    testWidgets('respects USD currency override', (tester) async {
      await tester.pumpWidget(_wrap(
        RecentTransactionTile(transaction: _tx(amount: 10)),
        overrides: [
          currencyProvider.overrideWith(_StubCurrencyNotifier.new),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining(r'$'), findsWidgets);
    });

    testWidgets('comma decimal style renders amounts with commas',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RecentTransactionTile(transaction: _tx(amount: 1234.5)),
        overrides: [
          numberFormatProvider.overrideWith(_StubCommaFormatNotifier.new),
        ],
      ));
      await tester.pumpAndSettle();

      // dot-decimal default would be "1234.50"; commaDecimal swaps to comma.
      expect(find.textContaining(','), findsWidgets);
    });
  });
}

class _StubCurrencyNotifier extends CurrencyNotifier {
  @override
  Future<String> build() async => 'USD';
}

class _StubCommaFormatNotifier extends NumberFormatNotifier {
  @override
  Future<NumberFormatStyle> build() async => NumberFormatStyle.commaDecimal;
}
