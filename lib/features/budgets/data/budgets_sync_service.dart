import 'package:expense_manager/features/budgets/data/local_budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';

/// Migra los presupuestos entre SQLite local y Supabase al cambiar de plan,
/// en paralelo a `TransactionSyncService`.
///
/// Los presupuestos no tienen cola de sync offline (CRUD de baja frecuencia),
/// así que un usuario que creó presupuestos siendo FREE los tenía solo en
/// local; al pasar a PRO la repo de presupuestos lee del cloud y el espejo
/// local se reemplaza, perdiéndolos. Esta migración sube los presupuestos
/// locales a la nube en FREE→PRO (y los baja en PRO→FREE) para que vivan en el
/// mismo store que las transacciones que los respaldan.
///
/// Invariante de seguridad de datos: el store origen se limpia **solo después**
/// de que todas las escrituras al destino tengan éxito. Las escrituras son
/// idempotentes, así que reejecutar tras un fallo parcial no duplica.
class BudgetsSyncService {
  const BudgetsSyncService({required this.local, required this.cloud});

  final LocalBudgetsRepository local;
  final CloudBudgetsRepo cloud;

  /// FREE → PRO: sube los presupuestos locales a la nube (aditivo, resolviendo
  /// conflictos por `(user_id, category)`), luego limpia el local. El espejo se
  /// rehidrata desde el cloud en la primera lectura de `MirroredBudgetsRepository`.
  Future<void> migrateToCloud() async {
    final budgets = await local.getAllForUser();
    if (budgets.isEmpty) return;
    for (final b in budgets) {
      await cloud.upsertBudget(b);
    }
    await local.clearAllForUser();
  }

  /// PRO → FREE: baja los presupuestos de la nube al local. NO borra la nube
  /// (mismo criterio que `TransactionSyncService.migrateToLocal`: la nube queda
  /// como respaldo; al volver a PRO el upsert aditivo reconcilia).
  Future<void> migrateToLocal() async {
    final budgets = await cloud.getAllForUser();
    await local.insertAll(budgets);
  }
}
