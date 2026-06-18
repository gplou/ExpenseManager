import 'budget_model.dart';

/// Contrato del repositorio de presupuestos.
///
/// Implementaciones: [LocalBudgetsRepository] (SQLite, usuarios FREE),
/// [SupabaseBudgetsRepository] (cloud) y [MirroredBudgetsRepository]
/// (cloud-first con espejo local, usuarios PRO). CRUD de baja frecuencia:
/// sin cola de sync offline en v1 — si la operación cloud falla, falla la
/// acción y el usuario reintenta.
abstract class BudgetsRepositoryContract {
  Future<List<BudgetModel>> getBudgets();

  /// [budget.id] vacío → el repo asigna uno (uuid local o gen_random_uuid).
  Future<BudgetModel> createBudget(BudgetModel budget);

  Future<BudgetModel> updateBudget(BudgetModel budget);

  Future<void> deleteBudget(String id);
}
