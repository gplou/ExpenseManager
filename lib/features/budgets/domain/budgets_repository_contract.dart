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

/// Subconjunto de operaciones cloud que necesita `BudgetsSyncService` para la
/// migración FREE↔PRO. Lo implementa `SupabaseBudgetsRepository`; los tests
/// pasan un fake en memoria sin tocar Supabase.
abstract class CloudBudgetsRepo {
  /// Sube un presupuesto de forma aditiva (conflicto por `(user_id, category)`),
  /// preservando el id local.
  Future<BudgetModel> upsertBudget(BudgetModel budget);

  /// Todos los presupuestos del usuario en la nube.
  Future<List<BudgetModel>> getAllForUser();

  Future<void> deleteBudget(String id);
}
