import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/recent_categories_strip.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      customCategoriesSyncProvider.overrideWith(
        (ref) => <TransactionType, List<TransactionCategory>>{
          TransactionType.income: [],
          TransactionType.expense: [],
        },
      ),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: child),
    ),
  );
}

Widget _stripFor(
  TransactionType type, {
  String? selected,
  ValueChanged<String>? onSelect,
  VoidCallback? onMore,
}) =>
    QuickCategoryStrip(
      type: type,
      selected: selected,
      onSelect: onSelect ?? (_) {},
      onMore: onMore ?? () {},
      accentColor: Colors.red,
      accentLight: Colors.red.shade100,
    );

void main() {
  group('QuickCategoryStrip', () {
    testWidgets('renders the quick categories as chips', (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense),
        overrides: [
          quickCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida', 'Transporte', 'Ocio']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Ocio'), findsOneWidget);
    });

    testWidgets('falls back to default categories when there is no history',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense),
        overrides: [
          recentCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => []),
        ],
      ));
      await tester.pumpAndSettle();

      // Built-in expense categories fill the strip for new users.
      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
    });

    testWidgets('recents come first, then defaults fill up the strip',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense),
        overrides: [
          recentCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Salud']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Salud'), findsOneWidget);
      expect(find.text('Comida'), findsOneWidget);
    });

    testWidgets('tap on a chip invokes onSelect with its name',
        (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense, onSelect: (s) => selected = s),
        overrides: [
          quickCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida', 'Transporte']),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      expect(selected, 'Transporte');
    });

    testWidgets('the "more" chip invokes onMore', (tester) async {
      var moreTapped = false;
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense, onMore: () => moreTapped = true),
        overrides: [
          quickCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida']),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(moreTapped, isTrue);
    });

    testWidgets('selected category is prepended when missing from the list',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense, selected: 'Gasolina'),
        overrides: [
          quickCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Gasolina'), findsOneWidget);
    });

    testWidgets('renders income chips when type is income', (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.income),
        overrides: [
          quickCategoriesProvider(TransactionType.income)
              .overrideWith((_) async => ['Salario', 'Freelance']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
    });
  });
}
