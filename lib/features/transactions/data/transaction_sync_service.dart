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

  /// FREE → PRO: make Supabase mirror the local store exactly, then clear local.
  ///
  /// While FREE the device-local store is the single source of truth — every
  /// write (including deletions) only ever touched SQLite, never Supabase. So
  /// the migration both uploads local rows AND removes any stale cloud rows that
  /// no longer exist locally. Without that reconcile step, transactions deleted
  /// during the FREE period — but still sitting in Supabase from a prior PRO
  /// period (or a downgrade that never ran [migrateToLocal]) — would reappear
  /// after re-subscribing.
  ///
  /// Recurring transactions are migrated first to preserve FK references.
  Future<void> migrateToCloud() async {
    // 1. Recurring transactions first (FK dependency).
    // upsertRecurring preserves the local UUID so FK references in regular
    // transactions remain valid after migration.
    final recurring = await localRecurring.getAllForUser();
    for (final r in recurring) {
      await cloudRecurring.upsertRecurring(r);
    }

    // 2. Regular transactions.
    // upsertTransaction preserves the local UUID (avoids new Supabase-generated
    // IDs that would break any existing recurring_transaction_id FK links).
    final transactions = await localTx.getAllForUser();
    for (final t in transactions) {
      await cloudTx.upsertTransaction(t);
    }

    // 3. Reconcile deletions: drop any cloud row absent from local so the
    // cloud mirrors local exactly. Delete transactions before recurring so no
    // cloud transaction still references a recurring row when it is removed.
    final localTxIds = transactions.map((t) => t.id).toSet();
    final cloudTransactions = await cloudTx.getTransactions(
      from: DateTime(2000, 1, 1),
      to: DateTime(2099, 12, 31),
    );
    for (final t in cloudTransactions) {
      if (!localTxIds.contains(t.id)) {
        await cloudTx.deleteTransaction(t.id);
      }
    }

    final localRecurringIds = recurring.map((r) => r.id).toSet();
    final cloudRecurring2 = await cloudRecurring.getAllForUser();
    for (final r in cloudRecurring2) {
      if (!localRecurringIds.contains(r.id)) {
        await cloudRecurring.deleteRecurring(r.id);
      }
    }

    // 4. Clear local only after all cloud writes (upserts + deletes) succeeded.
    // If any step above throws, local stays intact and the migration re-runs;
    // every operation is idempotent so re-running produces no duplicates.
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

  /// PRO → FREE: fetch all Supabase data and save locally, then delete from cloud.
  /// Recurring transactions are migrated first to preserve FK references.
  Future<void> migrateToLocal() async {
    // 1. Fetch all recurring from cloud
    final allRecurring = await cloudRecurring.getAllForUser();

    // 2. Fetch all transactions from cloud (wide window covers full history)
    final allTransactions = await cloudTx.getTransactions(
      from: DateTime(2000, 1, 1),
      to: DateTime(2099, 12, 31),
    );

    // 3. Write to local first — never touch cloud until local is safe
    await localRecurring.insertAll(allRecurring);
    await localTx.insertAll(allTransactions);

    // 4. Delete from cloud only after local writes have succeeded.
    // Transactions are deleted first; by the time we delete recurring rows,
    // there are no longer any cloud transactions referencing them, so the
    // FK-nullification step in deleteRecurring is harmless (affects 0 rows).
    for (final t in allTransactions) {
      await cloudTx.deleteTransaction(t.id);
    }
    for (final r in allRecurring) {
      await cloudRecurring.deleteRecurring(r.id);
    }
  }
}
