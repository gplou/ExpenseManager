import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/recent_categories_strip.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(body: child),
      ),
    );

Widget _stripFor(
  TransactionType type, {
  String? selected,
  ValueChanged<String>? onSelect,
}) =>
    RecentCategoriesStrip(
      type: type,
      selected: selected,
      onSelect: onSelect ?? (_) {},
      accentColor: Colors.red,
      accentLight: Colors.red.shade100,
    );

void main() {
  group('RecentCategoriesStrip', () {
    testWidgets('renders nothing when fewer than 2 recent categories',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense),
        overrides: [
          recentCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox).evaluate().first.size, equals(Size.zero));
    });

    testWidgets('renders all chips when >=2 recent categories', (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense),
        overrides: [
          recentCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida', 'Transporte', 'Ocio']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Ocio'), findsOneWidget);
    });

    testWidgets('tap on a chip invokes onSelect with its name',
        (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.expense, onSelect: (s) => selected = s),
        overrides: [
          recentCategoriesProvider(TransactionType.expense)
              .overrideWith((_) async => ['Comida', 'Transporte']),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      expect(selected, 'Transporte');
    });

    testWidgets('renders income chips when type is income', (tester) async {
      await tester.pumpWidget(_wrap(
        _stripFor(TransactionType.income),
        overrides: [
          recentCategoriesProvider(TransactionType.income)
              .overrideWith((_) async => ['Salario', 'Freelance']),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
    });
  });
}
