import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/dashboard/widgets/budgets_section.dart';

import '../../../helpers/pump_app.dart';

BudgetModel _budget({
  String id = 'b1',
  String category = 'Comida',
  double amount = 100,
}) =>
    BudgetModel(
      id: id,
      userId: 'u1',
      category: category,
      amount: amount,
      createdAt: DateTime(2026, 6, 1),
    );

Future<void> _pumpSection(
  WidgetTester tester,
  List<BudgetProgress> progresses,
) {
  SharedPreferences.setMockInitialValues({});
  return pumpWithProviders(
    tester,
    const BudgetsSection(
      cSymbol: '€',
      numFmtStyle: NumberFormatStyle.dotDecimal,
    ),
    overrides: [
      budgetProgressProvider.overrideWith((ref) async => progresses),
    ],
  );
}

void main() {
  testWidgets('without budgets shows the create CTA', (tester) async {
    await _pumpSection(tester, const []);
    await tester.pumpAndSettle();

    expect(
      find.text('Crea tu primer presupuesto por categoría'),
      findsOneWidget,
    );
  });

  testWidgets('with budgets shows header, manage link and progress bars',
      (tester) async {
    await _pumpSection(tester, [
      BudgetProgress(budget: _budget(), spent: 40),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('PRESUPUESTOS'), findsOneWidget);
    expect(find.text('Gestionar'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
  });

  testWidgets('crossing 80% fires the snackbar alert once', (tester) async {
    await _pumpSection(tester, [
      BudgetProgress(budget: _budget(amount: 100), spent: 85),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Has superado el 80% del presupuesto de Comida'),
      findsOneWidget,
    );
  });

  testWidgets('reaching 100% fires the limit snackbar', (tester) async {
    await _pumpSection(tester, [
      BudgetProgress(budget: _budget(amount: 100), spent: 120),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Has alcanzado el presupuesto de Comida'),
      findsOneWidget,
    );
  });
}
