import 'package:clock/clock.dart';

import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'local_transactions_repository.dart';
import 'pending_operation.dart';
import 'sync_queue_repository.dart';

/// Repository for FREE users: writes go only to SQLite, but **deletions are
/// recorded as explicit tombstones** in the sync queue.
///
/// Why: when a FREE user later upgrades to PRO, the migration must remove from
/// Supabase the rows that were deleted while FREE (they may still exist there
/// from a prior PRO period). Inferring those deletions from the local snapshot
/// is unsafe — `migrateToCloud` also runs on a PRO cold start with a partial or
/// empty local view, so "absent locally" can never be treated as "delete from
/// cloud" (doing so once wiped a user's entire cloud history). Recording the
/// deleted id explicitly lets the migration replay only the rows the user
/// actually deleted, never more.
///
/// The tombstones sit in `pending_operations` and are NOT drained while FREE
/// ([OfflineSyncService] is gated behind PRO); they are applied and cleared by
/// the FREE→PRO migration ([TransactionSyncService.migrateToCloud]).
class LocalTombstoningTransactionsRepository
    implements TransactionsRepositoryContract {
  LocalTombstoningTransactionsRepository({
    required LocalTransactionsRepository local,
    required SyncQueueRepository queue,
  })  : _local = local,
        _queue = queue;

  final LocalTransactionsRepository _local;
  final SyncQueueRepository _queue;

  // ── Reads / writes that don't need a tombstone delegate straight to local ──

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) =>
      _local.getTransactions(from: from, to: to);

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) =>
      _local.getSummary(from: from, to: to);

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) =>
      _local.createTransaction(transaction);

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) =>
      _local.updateTransaction(transaction);

  @override
  Future<void> upsertTransaction(TransactionModel transaction) =>
      _local.upsertTransaction(transaction);

  // ── Delete: remove locally AND record a tombstone for the next upgrade ──────

  @override
  Future<void> deleteTransaction(String id) async {
    await _local.deleteTransaction(id);
    await _queue.enqueue(PendingOperation(
      id: '${id}_delete',
      userId: _local.userId,
      opType: SyncOpType.delete,
      entityId: id,
      createdAt: clock.now(),
    ));
  }
}
