import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'local_recurring_transactions_repository.dart';
import 'local_transactions_repository.dart';

/// Migrates transaction data bidirectionally between local SQLite and Supabase.
///
/// Data-safety invariant: the source store is cleared **only after** all writes
/// to the target succeed. If the process is killed mid-migration the source
/// still holds all data and the migration will re-run on the next subscription
/// state change. Writes are idempotent so re-running produces no duplicates.
class TransactionSyncService {
  const TransactionSyncService({
    required this.localTx,
    required this.cloudTx,
    required this.localRecurring,
    required this.cloudRecurring,
  });

  final LocalTransactionsRepository localTx;
  final TransactionsRepositoryContract cloudTx;
  final LocalRecurringTransactionsRepository localRecurring;
  final RecurringTransactionsRepositoryContract cloudRecurring;

  /// FREE → PRO: copy all local data to Supabase, then clear local.
  /// Recurring transactions are migrated first to preserve FK references.
  ///
  /// IMPORTANT: the upsert step is an *additive* merge — it must NEVER delete
  /// cloud rows just because they are absent locally. `migrateToCloud` also runs
  /// on a PRO user's cold start when local has data (see sync_provider), where
  /// local is frequently a partial/empty view of the cloud; inferring deletions
  /// from local absence there wipes cloud data.
  ///
  /// Deletions made during the FREE period are propagated *explicitly* via
  /// [deletedTransactionIds] / [deletedRecurringIds] (delete tombstones recorded
  /// by the FREE-tier tombstoning repositories). Only those ids — and only when
  /// they are not present in the current local set — are removed from the cloud,
  /// so a partial/empty local snapshot can at most drop the handful of rows the
  /// user actually deleted, never the whole history.
  Future<void> migrateToCloud({
    List<String> deletedTransactionIds = const [],
    List<String> deletedRecurringIds = const [],
  }) async {
    // 1. Recurring transactions first (FK dependency).
    // upsertRecurring preserves the local UUID so FK references in regular
    // transactions remain valid after migration.
    final recurring = await localRecurring.getAllForUser();
    final localRecurringIds = recurring.map((r) => r.id).toSet();
    for (final r in recurring) {
      await cloudRecurring.upsertRecurring(r);
    }

    // 2. Regular transactions.
    // upsertTransaction preserves the local UUID (avoids new Supabase-generated
    // IDs that would break any existing recurring_transaction_id FK links).
    final transactions = await localTx.getAllForUser();
    final localTxIds = transactions.map((t) => t.id).toSet();
    for (final t in transactions) {
      await cloudTx.upsertTransaction(t);
    }

    // 3. Replay FREE-period delete tombstones against the cloud. Skip any id
    // that is present locally (defensive against a deleted-then-recreated id):
    // the upsert above is authoritative for rows that still exist. Transactions
    // are deleted before recurring so the FK-nullification inside
    // deleteRecurring runs once the referencing transactions are already gone.
    for (final id in deletedTransactionIds) {
      if (!localTxIds.contains(id)) {
        await cloudTx.deleteTransaction(id);
      }
    }
    for (final id in deletedRecurringIds) {
      if (!localRecurringIds.contains(id)) {
        await cloudRecurring.deleteRecurring(id);
      }
    }

    // 4. Clear local only after all cloud writes (upserts + tombstone deletes)
    // have succeeded.
    await localTx.clearAllForUser();
    await localRecurring.clearAllForUser();
  }

  /// PRO (fresh install / new device): download all cloud data into the local
  /// cache WITHOUT deleting anything from Supabase.
  ///
  /// Idempotent — uses [insertAll] which calls [ConflictAlgorithm.replace], so
  /// re-running after a partial failure is safe and produces no duplicates.
  Future<void> hydrateLocalFromCloud() async {
    // Recurring first (FK dependency)
    final allRecurring = await cloudRecurring.getAllForUser();
    final allTransactions = await cloudTx.getTransactions(
      from: DateTime(2000, 1, 1),
      to: DateTime(2099, 12, 31),
    );
    await localRecurring.insertAll(allRecurring);
    await localTx.insertAll(allTransactions);
  }

  /// PRO → FREE: copy all Supabase data down into the local cache.
  ///
  /// IMPORTANT: this NO LONGER deletes anything from the cloud. Borrar la nube
  /// aquí era destructivo y sin red de seguridad: si el usuario alternaba de
  /// plan (o dos migraciones se solapaban) se perdía todo el histórico. Dejar
  /// la nube intacta la convierte en un respaldo de solo-lectura mientras el
  /// usuario es FREE; al volver a PRO, [migrateToCloud] es aditivo (upsert por
  /// id) y reconcilia sin duplicar. Los borrados que el usuario haga siendo
  /// FREE se propagan luego vía las lápidas de la cola, no por ausencia.
  ///
  /// Idempotente: [insertAll] usa [ConflictAlgorithm.replace].
  Future<void> migrateToLocal() async {
    final allRecurring = await cloudRecurring.getAllForUser();
    final allTransactions = await cloudTx.getTransactions(
      from: DateTime(2000, 1, 1),
      to: DateTime(2099, 12, 31),
    );

    // Recurring first (FK dependency).
    await localRecurring.insertAll(allRecurring);
    await localTx.insertAll(allTransactions);
  }
}
