// Flujo E2E de presupuestos: crear → verificar → límite FREE → borrar.
//
// El usuario E2E es FREE, así que ejercita LocalBudgetsRepository (SQLite)
// y la puerta kFreeBudgetLimit (1 presupuesto → el segundo intento muestra
// el diálogo de upgrade a PRO).
//
//   fvm flutter test integration_test/budgets_flow_test.dart \
//     --dart-define-from-file=dart_defines.json \
//     --dart-define-from-file=dart_defines_e2e.json \
//     -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:expense_manager/core/constants/test_keys.dart';
import 'package:expense_manager/features/budgets/presentation/widgets/budget_progress_tile.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';

import 'helpers/e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'crea un presupuesto, choca con el límite FREE y lo borra',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await bootApp(tester);
      await ensureLoggedIn(tester);

      final category = TransactionCategories.expense.first.name;
      final categoryLabel =
          TransactionCategories.localizedName(category, l10nEn);

      // ── Ir a presupuestos desde la sección del dashboard ────────────────
      await waitOrScrollTo(tester, find.byKey(TestKeys.budgetsSectionLink));
      await tester.tap(find.byKey(TestKeys.budgetsSectionLink));
      await settle(tester);

      // Pantalla de presupuestos vacía (el estado local se limpia al boot).
      await waitFor(tester, find.text(l10nEn.budgetNoBudgets));

      // ── Crear ───────────────────────────────────────────────────────────
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      // Dropdown de categoría: los items muestran "emoji  nombre".
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      final itemLabel =
          '${TransactionCategories.emojiFor(category)}  $categoryLabel';
      await tester.tap(find.text(itemLabel).last);
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await settle(tester);

      // El tile del presupuesto aparece en la lista.
      await waitFor(tester, find.byType(BudgetProgressTile));

      // ── Límite FREE: el segundo presupuesto pide upgrade ────────────────
      await tester.tap(find.byType(FloatingActionButton));
      await waitFor(tester, find.text(l10nEn.errorFreePlanLimit));
      expect(find.text(l10nEn.budgetUpgradeCta), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l10nEn.cancel));
      await settle(tester);

      // ── Borrar ──────────────────────────────────────────────────────────
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, l10nEn.delete));
      await settle(tester);

      await waitForGone(tester, find.byType(BudgetProgressTile));
      await waitFor(tester, find.text(l10nEn.budgetNoBudgets));
      expect(tester.takeException(), isNull);
    },
  );
}
