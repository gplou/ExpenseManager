import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/services/home_widget_gateway.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

/// Claves leídas por los widgets nativos (QuadWidgetProvider.kt /
/// ExpenseManagerWidget.swift). Strings YA formateados desde Dart: el lado
/// nativo no formatea divisa ni números.
const kWidgetMonthSpentKey = 'month_spent';
const kWidgetBalanceKey = 'balance';

/// Publica en el home widget el gasto y el balance del MES ACTUAL (Plan 3 —
/// A6). Watcheado desde MyApp; se re-ejecuta tras cada CRUD/sync (vía
/// `allTransactionsProvider`) y al cambiar divisa o formato numérico.
///
/// Nunca lanza: un fallo del widget no debe afectar a la app.
final homeWidgetDataSyncProvider = FutureProvider<void>((ref) async {
  final gateway = ref.watch(homeWidgetGatewayProvider);
  try {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      // Logout: limpia el widget para no mostrar datos del usuario anterior.
      await gateway.saveWidgetData(kWidgetMonthSpentKey, null);
      await gateway.saveWidgetData(kWidgetBalanceKey, null);
      await gateway.updateWidget();
      return;
    }

    // Señal de refresco: cualquier CRUD/sync invalida allTransactionsProvider.
    await ref.watch(allTransactionsProvider.future);

    // Mes actual, independiente del periodo seleccionado en el dashboard
    // (lectura local barata: mismo criterio que budgetProgressProvider).
    final now = clock.now();
    final monthTransactions =
        await ref.read(transactionsRepositoryProvider).getTransactions(
              from: DateTime(now.year, now.month, 1),
              to: DateTime(now.year, now.month, now.day),
            );
    double income = 0;
    double expense = 0;
    for (final t in monthTransactions) {
      if (t.type.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    final currencyCode = await ref.watch(currencyProvider.future);
    final numFmt = await ref.watch(numberFormatProvider.future);
    final symbol = currencySymbol(currencyCode);
    final balance = income - expense;

    await gateway.saveWidgetData(
      kWidgetMonthSpentKey,
      '$symbol${formatAmount(expense, numFmt)}',
    );
    await gateway.saveWidgetData(
      kWidgetBalanceKey,
      '${balance < 0 ? '-' : ''}$symbol${formatAmount(balance.abs(), numFmt)}',
    );
    await gateway.updateWidget();
  } catch (e) {
    AppLogger.log('[HomeWidget] data sync failed: $e');
  }
});
