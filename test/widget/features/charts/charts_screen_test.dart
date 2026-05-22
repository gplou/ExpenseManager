import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/charts/presentation/providers/chart_providers.dart';
import 'package:expense_manager/features/charts/presentation/screens/charts_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap({required List<Override> overrides}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      // Hide the ad banner so the test never touches real ad SDKs.
      isProProvider.overrideWithValue(true),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const ChartsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders the appbar title and empty state for no data',
      (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        chartDistributionProvider
            .overrideWith((_) async => <String, double>{}),
        chartFilteredTotalProvider.overrideWith((_) async => 0.0),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gráficos'), findsOneWidget);
    expect(find.text('Sin datos en este período'), findsOneWidget);
  });

  testWidgets('shows the pie chart + legend with the provided distribution',
      (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        chartDistributionProvider.overrideWith(
          (_) async => {'Comida': 80.0, 'Transporte': 20.0},
        ),
        chartFilteredTotalProvider.overrideWith((_) async => 100.0),
      ],
    ));
    await tester.pumpAndSettle();

    // Legend rows render their category name + percentage
    expect(find.text('Comida'), findsAtLeastNWidgets(1));
    expect(find.text('Transporte'), findsAtLeastNWidgets(1));
    expect(find.text('80.0%'), findsOneWidget);
    expect(find.text('20.0%'), findsOneWidget);
  });

  testWidgets('tapping the bar-chart toggle switches the rendered chart',
      (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        chartDistributionProvider.overrideWith(
          (_) async => {'Comida': 80.0, 'Transporte': 20.0},
        ),
        chartFilteredTotalProvider.overrideWith((_) async => 100.0),
      ],
    ));
    await tester.pumpAndSettle();

    // Initial chart is the pie (default mode).
    expect(find.byKey(const ValueKey('pie')), findsOneWidget);
    expect(find.byKey(const ValueKey('bar')), findsNothing);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('pie')), findsNothing);
  });

  testWidgets('income/expense toggle flips the chartTypeFilterProvider',
      (tester) async {
    final container = ProviderContainer(overrides: [
      isProProvider.overrideWithValue(true),
      chartDistributionProvider.overrideWith(
        (_) async => {'Salario': 1000.0},
      ),
      chartFilteredTotalProvider.overrideWith((_) async => 1000.0),
    ]);
    addTearDown(container.dispose);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const ChartsScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Default is expense
    expect(container.read(chartTypeFilterProvider), TransactionType.expense);

    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();

    expect(container.read(chartTypeFilterProvider), TransactionType.income);
  });

  testWidgets('total amount renders the filtered total', (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        chartDistributionProvider.overrideWith(
          (_) async => {'Comida': 80.0, 'Transporte': 20.0},
        ),
        chartFilteredTotalProvider.overrideWith((_) async => 100.0),
      ],
    ));
    await tester.pumpAndSettle();

    // €100.00 — default currency EUR, dotDecimal format
    expect(find.textContaining('100'), findsAtLeastNWidgets(1));
  });
}
