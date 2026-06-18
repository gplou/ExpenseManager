import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/data/budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

// ── Budgets (CRUD) ───────────────────────────────────────────────────────────

/// Máximo de presupuestos en el plan FREE. PRO: ilimitados.
const kFreeBudgetLimit = 1;

class BudgetsNotifier extends AsyncNotifier<List<BudgetModel>> {
  @override
  Future<List<BudgetModel>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    final repo = ref.watch(budgetsRepositoryProvider);
    return repo.getBudgets();
  }

  /// Crea un presupuesto con la divisa global vigente.
  ///
  /// Lanza [FreeLimitFailure] si un usuario FREE ya tiene [kFreeBudgetLimit]
  /// presupuestos (la UI ofrece el CTA a /pro) y [ValidationFailure] si la
  /// categoría ya tiene presupuesto (defensa extra: el form filtra esas
  /// categorías).
  Future<void> create({
    required String category,
    required double amount,
  }) async {
    final current = state.value ?? const <BudgetModel>[];
    final isPro = ref.read(isProProvider);
    if (!isPro && current.length >= kFreeBudgetLimit) {
      throw const FreeLimitFailure('FREE plan allows $kFreeBudgetLimit budget');
    }
    if (current.any((b) => b.category == category)) {
      throw const ValidationFailure('Budget for this category already exists');
    }
    final currency = await ref.read(currencyProvider.future);
    final repo = ref.read(budgetsRepositoryProvider);
    final created = await repo.createBudget(BudgetModel(
      id: '',
      userId: '',
      category: category,
      amount: amount,
      currency: currency,
      createdAt: clock.now(),
    ));
    state = AsyncData(_sorted([...current, created]));
    AnalyticsService.track(AnalyticsService.budgetCreated, {
      'category': category,
    });
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final repo = ref.read(budgetsRepositoryProvider);
    final updated = await repo.updateBudget(budget);
    final current = state.value ?? const <BudgetModel>[];
    state = AsyncData(_sorted([
      for (final b in current)
        if (b.id == updated.id) updated else b,
    ]));
    AnalyticsService.track(AnalyticsService.budgetEdited, {
      'category': updated.category,
    });
  }

  Future<void> deleteBudget(String id) async {
    final repo = ref.read(budgetsRepositoryProvider);
    await repo.deleteBudget(id);
    final current = state.value ?? const <BudgetModel>[];
    state = AsyncData([
      for (final b in current)
        if (b.id != id) b,
    ]);
    AnalyticsService.track(AnalyticsService.budgetDeleted);
  }

  List<BudgetModel> _sorted(List<BudgetModel> budgets) =>
      budgets..sort((a, b) => a.category.compareTo(b.category));
}

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<BudgetModel>>(
  BudgetsNotifier.new,
);

// ── Progress (derived) ───────────────────────────────────────────────────────

class BudgetProgress {
  const BudgetProgress({required this.budget, required this.spent});

  final BudgetModel budget;

  /// Gasto del mes actual en la categoría del presupuesto.
  final double spent;

  /// 1.0 = límite alcanzado. Puede superar 1.0.
  double get ratio => budget.amount <= 0 ? 0 : spent / budget.amount;
}

/// Progreso de cada presupuesto sobre el gasto del MES ACTUAL, independiente
/// del periodo seleccionado en el dashboard (por eso no filtra la lista de
/// `allTransactionsProvider`, que cubre el rango visible: hace su propia
/// query del mes — lectura local barata tanto en FREE como en PRO).
///
/// Watchea `allTransactionsProvider` solo como señal de refresco: cualquier
/// CRUD de transacciones lo invalida y este provider se recalcula.
final budgetProgressProvider =
    FutureProvider.autoDispose<List<BudgetProgress>>((ref) async {
  final budgets = await ref.watch(budgetsProvider.future);
  if (budgets.isEmpty) return const [];

  await ref.watch(allTransactionsProvider.future);

  final now = clock.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month, now.day);
  final repo = ref.read(transactionsRepositoryProvider);
  final monthTransactions = await repo.getTransactions(from: from, to: to);

  final spentByCategory = <String, double>{};
  for (final t in monthTransactions) {
    if (t.type.isExpense) {
      spentByCategory[t.category] = (spentByCategory[t.category] ?? 0) + t.amount;
    }
  }
  return [
    for (final b in budgets)
      BudgetProgress(budget: b, spent: spentByCategory[b.category] ?? 0),
  ];
});

// ── Alertas 80% / 100% ───────────────────────────────────────────────────────

/// Devuelve los cruces de umbral (80 o 100) aún no notificados este mes y los
/// marca como notificados en SharedPreferences, para avisar una sola vez por
/// presupuesto, umbral y periodo. Si A5 (notificaciones locales) se implementa,
/// este helper es el punto donde elevar el snackbar a notificación.
class BudgetAlerts {
  BudgetAlerts._();

  static Future<List<(BudgetProgress, int)>> consumeUnnotified(
    List<BudgetProgress> progresses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final now = clock.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final crossings = <(BudgetProgress, int)>[];
    for (final p in progresses) {
      // Solo el umbral más alto cruzado; los inferiores quedan absorbidos.
      for (final threshold in const [100, 80]) {
        if (p.ratio * 100 >= threshold) {
          final key = 'budget_alert_${p.budget.id}_${period}_$threshold';
          if (prefs.getBool(key) != true) {
            await prefs.setBool(key, true);
            crossings.add((p, threshold));
            if (threshold == 100) {
              AnalyticsService.track(AnalyticsService.budgetLimitHit, {
                'category': p.budget.category,
              });
            }
          }
          break;
        }
      }
    }
    return crossings;
  }
}
