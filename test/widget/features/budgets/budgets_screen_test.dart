import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

class _FakeBudgets extends BudgetsNotifier {
  _FakeBudgets(this._items);
  final List<BudgetModel> _items;

  @override
  Future<List<BudgetModel>> build() async => _items;
}

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

Widget _wrap({
  required List<BudgetProgress> progresses,
  bool isPro = true,
}) {
  SharedPreferences.setMockInitialValues({});
  final budgets = progresses.map((p) => p.budget).toList();
  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(isPro),
      budgetsProvider.overrideWith(() => _FakeBudgets(budgets)),
      budgetProgressProvider.overrideWith((ref) async => progresses),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const BudgetsScreen(),
    ),
  );
}

void main() {
  testWidgets('shows the empty state without budgets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(progresses: const []));
    await tester.pumpAndSettle();

    expect(find.text('Sin presupuestos'), findsOneWidget);
  });

  testWidgets('renders one tile per budget with the localized category',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(progresses: [
      BudgetProgress(budget: _budget(category: 'Comida'), spent: 30),
      BudgetProgress(
        budget: _budget(id: 'b2', category: 'Transporte', amount: 50),
        spent: 60,
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('FREE user with 1 budget gets the upgrade dialog on add',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      progresses: [BudgetProgress(budget: _budget(), spent: 0)],
      isPro: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('El plan gratuito permite 1 presupuesto'),
      findsOneWidget,
    );
  });

  testWidgets('PRO user gets the form sheet on add', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(progresses: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo presupuesto'), findsOneWidget);
    expect(find.text('Límite mensual'), findsOneWidget);
  });
}
