import 'package:clock/clock.dart';

import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'local_recurring_transactions_repository.dart';
import 'pending_operation.dart';
import 'sync_queue_repository.dart';

/// Recurring-transactions repository for FREE users: writes go only to SQLite,
/// but **deletions are recorded as explicit tombstones** in the sync queue
/// ([SyncOpType.deleteRecurring]) so the next FREE→PRO migration removes the
/// same rows from Supabase.
///
/// Same rationale as [LocalTombstoningTransactionsRepository] for regular
/// transactions: inferring deletions from the local snapshot is unsafe, so the
/// deleted id is recorded explicitly. Recurring transactions have no offline
/// sync queue (PRO writes straight to Supabase), so [OfflineSyncService] skips
/// these tombstones; only [TransactionSyncService.migrateToCloud] consumes them.
class LocalTombstoningRecurringTransactionsRepository
    implements RecurringTransactionsRepositoryContract {
  LocalTombstoningRecurringTransactionsRepository({
    required LocalRecurringTransactionsRepository local,
    required SyncQueueRepository queue,
  })  : _local = local,
        _queue = queue;

  final LocalRecurringTransactionsRepository _local;
  final SyncQueueRepository _queue;

  // ── Reads / writes that don't need a tombstone delegate to local ───────────

  @override
  Future<List<RecurringTransactionModel>> getDueRecurring() =>
      _local.getDueRecurring();

  @override
  Future<List<RecurringTransactionModel>> getAllForUser() =>
      _local.getAllForUser();

  @override
  Future<RecurringTransactionModel?> getById(String id) => _local.getById(id);

  @override
  Future<String> createRecurring({
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) =>
      _local.createRecurring(
        amount: amount,
        type: type,
        category: category,
        subcategory: subcategory,
        description: description,
        recurrenceType: recurrenceType,
        nextOccurrence: nextOccurrence,
      );

  @override
  Future<void> updateRecurring({
    required String id,
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) =>
      _local.updateRecurring(
        id: id,
        amount: amount,
        type: type,
        category: category,
        subcategory: subcategory,
        description: description,
        recurrenceType: recurrenceType,
        nextOccurrence: nextOccurrence,
      );

  @override
  Future<void> updateNextOccurrence(String id, DateTime next) =>
      _local.updateNextOccurrence(id, next);

  @override
  Future<void> upsertRecurring(RecurringTransactionModel model) =>
      _local.upsertRecurring(model);

  // ── Delete: remove locally AND record a tombstone for the next upgrade ──────

  @override
  Future<void> deleteRecurring(String id) async {
    await _local.deleteRecurring(id);
    await _queue.enqueue(PendingOperation(
      id: '${id}_deleteRecurring',
      userId: _local.userId,
      opType: SyncOpType.deleteRecurring,
      entityId: id,
      createdAt: clock.now(),
    ));
  }
}
