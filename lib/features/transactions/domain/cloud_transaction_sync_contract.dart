import 'transaction_model.dart';

/// Contrato para operaciones de sincronización con la nube que requieren un
/// ID explícito (upsert idempotente). Lo implementa [TransactionsRepository]
/// y cualquier fake/stub de tests.
///
/// Mantener esta interfaz separada de [TransactionsRepositoryContract] sigue DIP:
/// las clases que sólo necesitan hacer sync (OfflineAwareTransactionsRepository,
/// OfflineSyncService) dependen de la abstracción, no del repositorio concreto.
abstract class CloudTransactionSyncContract {
  /// Inserta o actualiza una transacción usando su ID como clave de conflicto.
  /// Idempotente: si la transacción ya existe en la nube, la reemplaza.
  Future<void> upsertTransaction(TransactionModel transaction);

  Future<void> deleteTransaction(String id);
}
