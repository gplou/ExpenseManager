@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Golden coverage for the Nocturne restyle. Baselines were generated on
/// macOS with the bundled Inter font — see test/README.md for why these are
/// excluded from the default `flutter test` run in CI.

class _FakeBudgets extends BudgetsNotifier {
  _FakeBudgets(this._items);
  final List<BudgetModel> _items;

  @override
  Future<List<BudgetModel>> build() async => _items;
}

BudgetModel _budget({
  required String id,
  required String category,
  required double amount,
}) =>
    BudgetModel(
      id: id,
      userId: 'u1',
      category: category,
      amount: amount,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  final progresses = [
    BudgetProgress(budget: _budget(id: 'b1', category: 'Comida', amount: 300), spent: 180),
    BudgetProgress(budget: _budget(id: 'b2', category: 'Transporte', amount: 150), spent: 160),
    BudgetProgress(budget: _budget(id: 'b3', category: 'Ocio', amount: 100), spent: 20),
  ];

  Future<void> pumpBudgets(WidgetTester tester, ThemeData theme) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isProProvider.overrideWithValue(true),
          budgetsProvider.overrideWith(
            () => _FakeBudgets(progresses.map((p) => p.budget).toList()),
          ),
          budgetProgressProvider.overrideWith((ref) async => progresses),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: const BudgetsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Budgets — light', (tester) async {
    await pumpBudgets(tester, AppTheme.lightTheme);
    await expectLater(
      find.byType(BudgetsScreen),
      matchesGoldenFile('goldens/budgets_light.png'),
    );
  });

  testWidgets('Budgets — dark', (tester) async {
    await pumpBudgets(tester, AppTheme.darkTheme);
    await expectLater(
      find.byType(BudgetsScreen),
      matchesGoldenFile('goldens/budgets_dark.png'),
    );
  });
}
