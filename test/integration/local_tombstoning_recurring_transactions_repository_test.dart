/// Tests for [LocalTombstoningRecurringTransactionsRepository] — the FREE-tier
/// recurring repo that writes to SQLite and records a delete tombstone in the
/// sync queue so the next FREE→PRO migration removes the same rows from Supabase.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_tombstoning_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/pending_operation.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

RecurringTransactionModel _rec({required String id, double amount = 30}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: TransactionType.expense,
      category: 'Suscripción',
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: DateTime(2024, 5, 1),
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  sqfliteFfiInit();

  late LocalRecurringTransactionsRepository local;
  late SyncQueueRepository queue;
  late LocalTombstoningRecurringTransactionsRepository repo;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);

    local = LocalRecurringTransactionsRepository(userId: 'user-1');
    queue = SyncQueueRepository(userId: 'user-1');
    repo = LocalTombstoningRecurringTransactionsRepository(
      local: local,
      queue: queue,
    );
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  test('delete removes the row locally AND records a recurring tombstone',
      () async {
    await local.insertAll([_rec(id: 'rec-1')]);

    await repo.deleteRecurring('rec-1');

    expect(await local.getAllForUser(), isEmpty);
    expect(await queue.pendingRecurringDeleteEntityIds(), contains('rec-1'));
  });

  test('the tombstone is a deleteRecurring op carrying the entity id', () async {
    await local.insertAll([_rec(id: 'rec-9')]);

    await repo.deleteRecurring('rec-9');

    final pending = await queue.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.opType, SyncOpType.deleteRecurring);
    expect(pending.first.entityId, 'rec-9');
  });

  test('the recurring tombstone is NOT counted as a transaction tombstone',
      () async {
    await local.insertAll([_rec(id: 'rec-3')]);

    await repo.deleteRecurring('rec-3');

    // pendingDeleteEntityIds is for transactions only — must not leak recurring.
    expect(await queue.pendingDeleteEntityIds(), isEmpty);
  });

  test('create does not record a tombstone', () async {
    await repo.createRecurring(
      amount: 12,
      type: TransactionType.expense,
      category: 'Suscripción',
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: DateTime(2024, 6, 1),
    );

    expect(await queue.pendingRecurringDeleteEntityIds(), isEmpty);
    expect(await local.getAllForUser(), hasLength(1));
  });

  test('reads delegate to the local store', () async {
    await local.insertAll([_rec(id: 'rec-a'), _rec(id: 'rec-b')]);

    final all = await repo.getAllForUser();

    expect(all.map((r) => r.id), containsAll(['rec-a', 'rec-b']));
  });
}
